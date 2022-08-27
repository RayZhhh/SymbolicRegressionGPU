#include "program.cuh"
namespace cusr {
    namespace program {

        Program crossover_mutation(Program &parent, Program &donor) {
            Program ret;
            auto donor_index = rand_subtree_index_roulette(donor.prefix, true);
            auto parent_index = rand_subtree_index_roulette(parent.prefix, true);

            int length =
                    parent.length - parent_index.second + parent_index.first + donor_index.second - donor_index.first;
            ret.prefix.resize(length);
            if (parent_index.first > 0) {
                std::copy(parent.prefix.begin(), parent.prefix.begin() + parent_index.first, ret.prefix.begin());
            }
            std::copy(donor.prefix.begin() + donor_index.first, donor.prefix.begin() + donor_index.second,
                      ret.prefix.begin() + parent_index.first);
            int tmp_start_pos = length - ((int) parent.prefix.size() - parent_index.second);
            std::copy(parent.prefix.begin() + parent_index.second, parent.prefix.end(),
                      ret.prefix.begin() + tmp_start_pos);
            ret.length = length;
            ret.depth = get_depth_of_prefix(ret.prefix);
            return ret;
        }

        Program
        point_mutation(Program &program, vector<Function> &function_set, pair<float, float> &range, int variable_num) {
            Program ret;
            ret.prefix.assign(program.prefix.begin(), program.prefix.end());
            int pos = gen_rand_int(0, program.length - 1);

            if (ret.prefix[pos].node_type == NodeType::BFUNC) {
                auto pre_func = ret.prefix[pos].function;
                rand_function(ret.prefix[pos], function_set);
                while (ret.prefix[pos].function == pre_func || ret.prefix[pos].node_type == NodeType::UFUNC) {
                    rand_function(ret.prefix[pos], function_set);
                }
            } else if (ret.prefix[pos].node_type == NodeType::UFUNC) {
                auto pre_func = ret.prefix[pos].function;
                rand_function(ret.prefix[pos], function_set);
                while (ret.prefix[pos].function == pre_func || ret.prefix[pos].node_type == NodeType::BFUNC) {
                    rand_function(ret.prefix[pos], function_set);
                }
            } else if (ret.prefix[pos].node_type == NodeType::VAR) {
                int pre_var = ret.prefix[pos].variable;
                rand_terminal(ret.prefix[pos], range, variable_num);
                while (ret.prefix[pos].node_type == NodeType::VAR && ret.prefix[pos].variable == pre_var) {
                    rand_terminal(ret.prefix[pos], range, variable_num);
                }
            } else {
                float pre_const = ret.prefix[pos].constant;
                rand_terminal(ret.prefix[pos], range, variable_num);
                while (ret.prefix[pos].node_type == NodeType::CONST && ret.prefix[pos].constant == pre_const) {
                    rand_terminal(ret.prefix[pos], range, variable_num);
                }
            }

            ret.length = program.length;
            ret.depth = program.depth;
            return ret;
        }

        Program hoist_mutation(Program &program) {
            if (program.prefix.size() <= 6) {
                return program;
            }

            auto subtree_index_1 = rand_subtree_index_roulette(program.prefix, false);
            prefix_t tmp(program.prefix.begin() + subtree_index_1.first,
                         program.prefix.begin() + subtree_index_1.second);

            auto subtree_index_2 = rand_subtree_index_roulette(tmp, true);

            while (subtree_index_2.first == 0) {
                subtree_index_2 = rand_subtree_index_roulette(tmp, true);
            }

            Program ret;

            if (subtree_index_1.first > 0) {
                ret.prefix.assign(program.prefix.begin(), program.prefix.begin() + subtree_index_1.first);
            }
            for (int i = subtree_index_2.first; i < subtree_index_2.second; i++) {
                ret.prefix.emplace_back(tmp[i]);
            }

            if (subtree_index_1.second < program.prefix.size()) {
                for (int i = subtree_index_1.second; i < program.prefix.size(); i++) {
                    ret.prefix.emplace_back(program.prefix[i]);
                }
            }

            ret.length = ret.prefix.size();
            ret.depth = get_depth_of_prefix(ret.prefix);
            return ret;
        }

        Program subtree_mutation(Program &program, int depth_of_rand_tree,
                                 pair<float, float> &range, vector<Function> &func_set, int variable_num) {
            prefix_t rand_prefix;
            if (gen_rand_float(0, 1) < 0.5) {
                get_init_prefix(rand_prefix, gen_full_init_tree(depth_of_rand_tree, range, func_set, variable_num));
            } else {
                get_init_prefix(rand_prefix, gen_growth_init_tree(depth_of_rand_tree, range, func_set, variable_num));
            }

            Program temp;
            temp.prefix = rand_prefix;
            return crossover_mutation(program, temp);
        }

        void
        calculate_fitness_cpu(Program *program, const vector<vector<float>> &dataset,
                              const vector<float> &real_value, int data_size,
                              metric_t metric_type) {
            float total_fitness = 0;
            auto *stack = new float[program->depth + 1];

            for (int row = 0; row < data_size; row++) {
                int top = 0;
                for (int i = program->length - 1; i >= 0; i--) {
                    auto &node = program->prefix[i];
                    if (node.node_type == NodeType::CONST) {
                        stack[top++] = node.constant;
                    } else if (node.node_type == NodeType::VAR) {
                        stack[top++] = dataset[row][node.variable];
                    } else if (node.node_type == NodeType::UFUNC) {
                        float var1 = stack[--top];
                        if (node.function == Function::SIN) {
                            stack[top++] = std::sin(var1);
                        } else if (node.function == Function::COS) {
                            stack[top++] = std::cos(var1);
                        } else if (node.function == Function::TAN) {
                            stack[top++] = std::tan(var1);
                        } else if (node.function == Function::LOG) {
                            if (var1 <= 0) {
                                stack[top++] = -1.0f;
                            } else {
                                stack[top++] = std::log(var1);
                            }
                        } else if (node.function == Function::INV) {
                            if (var1 == 0) {
                                var1 = DELTA;
                            }
                            stack[top++] = 1.0f / var1;
                        }
                    } else {
                        float var1 = stack[--top];
                        float var2 = stack[--top];
                        if (node.function == Function::ADD) {
                            stack[top++] = var1 + var2;
                        } else if (node.function == Function::SUB) {
                            stack[top++] = var1 - var2;
                        } else if (node.function == Function::MUL) {
                            stack[top++] = var1 * var2;
                        } else if (node.function == Function::DIV) {
                            if (var2 == 0) {
                                var2 = DELTA;
                            }
                            stack[top++] = var1 / var2;
                        } else if (node.function == Function::MAX) {
                            stack[top++] = var1 >= var2 ? var1 : var2;
                        } else if (node.function == Function::MIN) {
                            stack[top++] = var1 <= var2 ? var1 : var2;
                        }
                    }
                }

                float metric = stack[top - 1] - real_value[row];
                if (metric_type == metric_t::mean_square_error || metric_type == metric_t::root_mean_square_error) {
                    total_fitness += metric * metric;
                } else {
                    total_fitness += metric > 0 ? metric : -metric;
                }
            }

            delete[] stack;

            if (metric_type == root_mean_square_error) {
                program->fitness = std::sqrt(total_fitness / (float) data_size);
            } else {
                program->fitness = total_fitness / (float) data_size;
            }
        }

        int tournament_selection_cpu(vector<Program> &population, int tournament_size, float parsimony_coefficient) {
            int size = population.size();
            int best_index = gen_rand_int(0, size - 1);

            for (int i = 0; i < tournament_size - 1; i++) {
                int rand_index = gen_rand_int(0, size - 1);
                if (population[rand_index].fitness + population[rand_index].length * parsimony_coefficient
                    < population[best_index].fitness + population[best_index].length * parsimony_coefficient) {
                    best_index = rand_index;
                }
            }

            return best_index;
        }

        Program *
        gen_full_init_program(int depth, pair<float, float> &range, vector<Function> &func_set, int variable_num) {
            auto *program = new Program();
            get_init_prefix(program->prefix, gen_full_init_tree(depth, range, func_set, variable_num));
            program->length = program->prefix.size();
            program->depth = get_depth_of_prefix(program->prefix);
            return program;
        }

        Program *
        gen_growth_init_program(int depth, pair<float, float> &range, vector<Function> &func_set, int variable_num) {
            auto *program = new Program();

            while (true) {
                get_init_prefix(program->prefix, gen_growth_init_tree(depth, range, func_set, variable_num));
                program->length = program->prefix.size();
                program->depth = get_depth_of_prefix(program->prefix);
                if (program->length != 1) {
                    break;
                } else {
                    delete program;
                    program = new Program();
                }
            }

            return program;
        }

        Program point_replace_mutation(Program &program, vector<Function> &function_set, pair<float, float> &range,
                                       int variable_num) {
            Program ret;
            ret.prefix.assign(program.prefix.begin(), program.prefix.end());

            for (int pos = 0; pos < program.length; pos++) {
                if (ret.prefix[pos].node_type == NodeType::BFUNC) {
                    auto pre_func = ret.prefix[pos].function;
                    rand_function(ret.prefix[pos], function_set);
                    while (ret.prefix[pos].function == pre_func || ret.prefix[pos].node_type == NodeType::UFUNC) {
                        rand_function(ret.prefix[pos], function_set);
                    }
                } else if (ret.prefix[pos].node_type == NodeType::UFUNC) {
                    auto pre_func = ret.prefix[pos].function;
                    rand_function(ret.prefix[pos], function_set);
                    while (ret.prefix[pos].function == pre_func || ret.prefix[pos].node_type == NodeType::BFUNC) {
                        rand_function(ret.prefix[pos], function_set);
                    }
                } else if (ret.prefix[pos].node_type == NodeType::VAR) {
                    int pre_var = ret.prefix[pos].variable;
                    rand_terminal(ret.prefix[pos], range, variable_num);
                    // make sure that the variable is different
                    while (ret.prefix[pos].node_type == NodeType::VAR && ret.prefix[pos].variable == pre_var) {
                        rand_terminal(ret.prefix[pos], range, variable_num);
                    }
                } else {
                    float pre_const = ret.prefix[pos].constant;
                    rand_terminal(ret.prefix[pos], range, variable_num);
                    // make sure that constant is different
                    while (ret.prefix[pos].node_type == NodeType::CONST && ret.prefix[pos].constant == pre_const) {
                        rand_terminal(ret.prefix[pos], range, variable_num);
                    }
                }
            }

            ret.length = program.length;
            ret.depth = program.depth;
            return ret;
        }
    }
}