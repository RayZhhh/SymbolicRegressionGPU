#include "prefix.cuh"

namespace cusr {
    namespace program {

        using namespace std;

        static float constant_prob = 0.2;
        static int seed_using_times = 2000;
        static int seed_count = seed_using_times;


        void set_seed_using_times(int time) {
            seed_using_times = time;
        }


        void set_constant_prob(float p_const) {
            constant_prob = p_const;
        }


        int gen_rand_int(int loBound, int upBound) {
            if (seed_count-- <= 0) {
                seed_count = seed_using_times;
                std::random_device rd;
                std::mt19937 gen(rd());
                std::uniform_int_distribution<int> dis(loBound, upBound);
                srand(dis(gen));
            }
            int bound_width = upBound - loBound + 1;
            return rand() % bound_width + loBound;
        }


        float gen_rand_float(float loBound, float upBound) {
            if (seed_count-- <= 0) {
                seed_count = seed_using_times;
                std::random_device rd;
                std::mt19937 gen(rd());
                std::uniform_int_distribution<int> dis(loBound, upBound);
                srand(dis(gen));
            }
            float rd = loBound + (float) (rand()) / (float) (RAND_MAX / (upBound - loBound));
            return rd;
        }


        int get_depth_of_prefix(prefix_t &prefix) {
            stack<int> s;
            for (int i = prefix.size() - 1; i >= 0; i--) {
                Node &node = prefix[i];
                if (node.node_type == VARIABLE || node.node_type == CONSTANT) {
                    s.push(0);
                } else if (node.node_type == BINARY_FUNCTION) {
                    int child1 = s.top();
                    s.pop();
                    int child2 = s.top();
                    s.pop();
                    int max_depth = child1 >= child2 ? child1 : child2;
                    s.push(max_depth + 1);
                } else {
                    s.top() += 1;
                }
            }
            return s.top() + 1;
        }


        int rand_roulette_pos(prefix_t &prefix, bool allow_terminal) {
            int len = prefix.size();

            auto *weights = new float[len];
            float total = 0;
            for (int i = 0; i < len; i++) {
                if (prefix[i].node_type == BINARY_FUNCTION || prefix[i].node_type == UNARY_FUNCTION) {
                    weights[i] = FUNCTION_WEIGHTS;
                    total += FUNCTION_WEIGHTS;
                } else {
                    weights[i] = TERMINAL_WEIGHTS;
                    total += TERMINAL_WEIGHTS;
                }
            }
            for (int i = 0; i < len; i++) {
                weights[i] /= total;
            }
            for (int i = 1; i < len; i++) {
                weights[i] += weights[i - 1];
            }
            float rand_float = gen_rand_float(0, 1);

            int pos = 0;
            while (true) {
                pos = 0;
                for (; pos < len; pos++) {
                    if (rand_float <= weights[pos] || pos == len - 1) {
                        break;
                    }
                }
                if (!allow_terminal && (prefix[pos].node_type == VARIABLE || prefix[pos].node_type == CONSTANT)) {
                    rand_float = gen_rand_float(0, 1);
                    continue;
                }
                break;
            }
            delete[] weights;
            return pos;
        }


        pair<int, int> rand_subtree_index_roulette(prefix_t &prefix, bool allow_terminal) {
            int pos = rand_roulette_pos(prefix, allow_terminal);

            if (prefix[pos].node_type == CONSTANT || prefix[pos].node_type == VARIABLE) {
                return {pos, pos + 1};
            }
            int op_count = 0;
            int num_count = 0;
            int end = pos;
            for (; end < prefix.size(); end++) {
                Node &node = prefix[end];
                if (node.node_type == BINARY_FUNCTION) {
                    op_count++;
                } else if (node.node_type == VARIABLE || node.node_type == CONSTANT) {
                    num_count++;
                } else // [ node.node_type == UNARY_FUNCTION ]
                {
                    continue;
                }
                if (op_count + 1 == num_count) {
                    break;
                }
            }
            return {pos, end + 1};
        }


        pair<int, int> rand_subtree_index(prefix_t &prefix, bool allow_terminal) {
            int len = prefix.size();
            int rand_pos = gen_rand_int(1, len - 1);
            if (!allow_terminal) // do not allow a terminal as a program
            {
                while (prefix[rand_pos].node_type == CONSTANT || prefix[rand_pos].node_type == VARIABLE) {
                    rand_pos = gen_rand_int(1, len - 1);
                }
            }
            if (prefix[rand_pos].node_type == CONSTANT || prefix[rand_pos].node_type == VARIABLE) {
                return {rand_pos, rand_pos + 1};
            }
            int op_count = 0;
            int num_count = 0;
            int end = rand_pos;
            for (; end < len; end++) {
                Node &node = prefix[end];
                if (node.node_type == BINARY_FUNCTION) {
                    op_count++;
                } else if (node.node_type == VARIABLE || node.node_type == CONSTANT) {
                    num_count++;
                } else // if (node.node_type == UNARY_FUNCTION)
                {
                    continue;
                }
                if (op_count + 1 == num_count) {
                    break;
                }
            }
            return {rand_pos, end + 1};
        }


        void rand_constant(Node &node, pair<float, float> &range) {
            node.node_type = CONSTANT;
            node.constant = gen_rand_float(range.first, range.second);
        }


        void rand_variable(Node &node, int variable_num) {
            node.node_type = VARIABLE;
            node.variable = gen_rand_int(0, variable_num - 1);
        }


        void rand_terminal(Node &node, pair<float, float> &range, int variable_num, float p_constant) {
            float rand_float = gen_rand_float(0, 1);
            if (rand_float <= p_constant) {
                rand_constant(node, range);
            } else {
                rand_variable(node, variable_num);
            }
        }


        void rand_terminal(Node &node, pair<float, float> &range, int variable_num) {
            rand_terminal(node, range, variable_num, constant_prob);
        }


        void rand_function(Node &node, vector<Function> &function_set) {
            int len = function_set.size();
            int rand_int = gen_rand_int(0, len - 1);
            func_t rand_func = function_set[rand_int];
            node.function = rand_func;
            if (rand_func == Function::_add || rand_func == Function::_sub ||
                rand_func == Function::_mul || rand_func == Function::_div ||
                rand_func == Function::_max || rand_func == Function::_min) {
                node.node_type = BINARY_FUNCTION;
            } else /** if (rand_func == Function::_sin || rand_func == Function::_cos || rand_func == Function::_tan ||
        rand_func == Function::_log || rand_func == Function::_inv) */
            {
                node.node_type = UNARY_FUNCTION;
            }
        }


        TreeNode *
        gen_full_init_tree(int depth, pair<float, float> &range, vector<Function> &func_set, int variable_num) {
            if (depth == 1) {
                auto *tree_node = new TreeNode();
                rand_terminal(tree_node->node, range, variable_num);
                return tree_node;
            }
            auto *tree_node = new TreeNode();
            rand_function(tree_node->node, func_set);
            if (tree_node->node.node_type == BINARY_FUNCTION) {
                tree_node->left = gen_full_init_tree(depth - 1, range, func_set, variable_num);
                tree_node->right = gen_full_init_tree(depth - 1, range, func_set, variable_num);
            } else {
                tree_node->left = gen_full_init_tree(depth - 1, range, func_set, variable_num);
            }
            return tree_node;
        }


        static bool is_first_rand = true;


#define RETURN_RATE 0.1

        TreeNode *
        gen_growth_init_tree(int depth, pair<float, float> &range, vector<Function> &func_set, int variable_num) {
            if (depth == 1) {
                auto *tree_node = new TreeNode();
                rand_terminal(tree_node->node, range, variable_num);
                return tree_node;
            }
            float rand_float = gen_rand_float(0, 1);
            if (!is_first_rand) {
                if (rand_float <= RETURN_RATE) // if return now
                {
                    auto *tree_node = new TreeNode();
                    rand_terminal(tree_node->node, range, variable_num);
                    return tree_node;
                }
            }
            is_first_rand = false;
            auto *tree_node = new TreeNode();
            rand_function(tree_node->node, func_set);
            if (tree_node->node.node_type == BINARY_FUNCTION) {
                tree_node->left = gen_growth_init_tree(depth - 1, range, func_set, variable_num);
                tree_node->right = gen_growth_init_tree(depth - 1, range, func_set, variable_num);
            } else {
                tree_node->left = gen_growth_init_tree(depth - 1, range, func_set, variable_num);
            }
            return tree_node;
        }


        void get_init_prefix(prefix_t &prefix, TreeNode *tree_node) {
            if (tree_node == nullptr) {
                return;
            }
            prefix.emplace_back(tree_node->node);
            get_init_prefix(prefix, tree_node->left);
            delete tree_node->left;
            get_init_prefix(prefix, tree_node->right);
            delete tree_node->right;
        }


        static string function_to_string(Function function) {
            if (function == Function::_add) {
                return "+";
            } else if (function == Function::_sub) {
                return "-";
            } else if (function == Function::_mul) {
                return "*";
            } else if (function == Function::_div) {
                return "/";
            } else if (function == Function::_max) {
                return "_max";
            } else if (function == Function::_min) {
                return "_min";
            } else if (function == Function::_sin) {
                return "_sin";
            } else if (function == Function::_cos) {
                return "_cos";
            } else if (function == Function::_tan) {
                return "_tan";
            } else if (function == Function::_log) {
                return "_log";
            } else if (function == Function::_inv) {
                return "_inv";
            } else return "non";
        }


        string prefix_to_infix(prefix_t &prefix) {
            stack<string> s;
            for (int i = prefix.size() - 1; i >= 0; i--) {
                Node &node = prefix[i];
                if (node.node_type == CONSTANT) {
                    s.push(std::to_string(node.constant));
                } else if (node.node_type == VARIABLE) {
                    string var = "x";
                    var.append(std::to_string(node.variable));
                    s.push(var);
                } else if (node.node_type == BINARY_FUNCTION) {
                    string tmp = "(";
                    tmp.append(s.top()).append(" ");
                    s.pop();
                    tmp.append(function_to_string(node.function));
                    tmp.append(" ").append(s.top()).append(")");
                    s.pop();
                    s.push(tmp);
                } else {
                    string tmp;
                    tmp = function_to_string(node.function);
                    if (s.top().size() == 1) {
                        tmp.append(s.top());
                    } else {
                        tmp.append("(").append(s.top()).append(")");
                    }
                    s.pop();
                    s.push(tmp);
                }
            }
            return s.top();
        }


        string prefix_to_string(prefix_t &prefix) {
            string ret;
            for (int i = 0; i < prefix.size(); i++) {
                auto node = prefix[i];
                if (node.node_type == UNARY_FUNCTION || node.node_type == BINARY_FUNCTION) {
                    ret.append(function_to_string(node.function)).append(" ");
                } else if (node.node_type == VARIABLE) {
                    ret.append("x").append(to_string(node.variable)).append(" ");
                } else {
                    ret.append(to_string(node.constant)).append(" ");
                }
            }
            return ret;
        }


        pair<int, int> get_subtree_index(prefix_t &prefix, int start_pos) {
            int len = prefix.size();
            // if the pos is a terminal, it is the subtree
            if (prefix[start_pos].node_type == CONSTANT || prefix[start_pos].node_type == VARIABLE) {
                return {start_pos, start_pos + 1};
            }
            // if the pos is not a terminal, we find the corresponding subtree
            int op_count = 0;
            int num_count = 0;
            int end = start_pos;
            for (; end < len; end++) {
                Node &node = prefix[end];
                if (node.node_type == BINARY_FUNCTION) {
                    op_count++;
                } else if (node.node_type == VARIABLE || node.node_type == CONSTANT) {
                    num_count++;
                } else // if (node.node_type == UNARY_FUNCTION)
                {
                    continue;
                }
                if (op_count + 1 == num_count) {
                    break;
                }
            }
            return {start_pos, end + 1};
        }

    }
}