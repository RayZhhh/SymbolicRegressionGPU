#include "prefix.cuh"

namespace cusr {
    namespace program {

        using namespace std;

        static float constant_prob = 0.2;

        /**
         * Each seed is initialized by the real random generator engine.
         * Update the seed after it has been used a given number of times.
         */
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
                if (node.node_type == NodeType::VAR || node.node_type == NodeType::CONST) {
                    s.push(0);
                } else if (node.node_type == NodeType::BFUNC) {
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
                if (prefix[i].node_type == NodeType::BFUNC || prefix[i].node_type == NodeType::UFUNC) {
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

            int pos;
            while (true) {
                pos = 0;
                for (; pos < len; pos++) {
                    if (rand_float <= weights[pos] || pos == len - 1) {
                        break;
                    }
                }
                if (!allow_terminal && (prefix[pos].node_type == NodeType::VAR || prefix[pos].node_type == NodeType::CONST)) {
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

            if (prefix[pos].node_type == NodeType::CONST || prefix[pos].node_type == NodeType::VAR) {
                return {pos, pos + 1};
            }
            int op_count = 0;
            int num_count = 0;
            int end = pos;
            for (; end < prefix.size(); end++) {
                Node &node = prefix[end];
                if (node.node_type == NodeType::BFUNC) {
                    op_count++;
                } else if (node.node_type == NodeType::VAR || node.node_type == NodeType::CONST) {
                    num_count++;
                } else // [ node.node_type == NodeType::UFUNC ]
                {
                    continue;
                }
                if (op_count + 1 == num_count) {
                    break;
                }
            }
            return {pos, end + 1};
        }

        void rand_constant(Node &node, pair<float, float> &range) {
            node.node_type = NodeType::CONST;
            node.constant = gen_rand_float(range.first, range.second);
        }

        void rand_variable(Node &node, int variable_num) {
            node.node_type = NodeType::VAR;
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
            if (rand_func == Function::ADD || rand_func == Function::SUB ||
                rand_func == Function::MUL || rand_func == Function::DIV ||
                rand_func == Function::MAX || rand_func == Function::MIN) {
                node.node_type = NodeType::BFUNC;
            } else /** if (rand_func == Function::SIN || rand_func == Function::COS || rand_func == Function::TAN ||
        rand_func == Function::LOG || rand_func == Function::INV) */
            {
                node.node_type = NodeType::UFUNC;
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
            if (tree_node->node.node_type == NodeType::BFUNC) {
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

            if (tree_node->node.node_type == NodeType::BFUNC) {
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
            switch (function) {
                case Function::ADD:
                    return "+";

                case Function::SUB:
                    return "-";

                case Function::MUL:
                    return "*";

                case Function::DIV:
                    return "/";

                case Function::MAX:
                    return "max";

                case Function::MIN:
                    return "min";

                case Function::SIN:
                    return "sin";

                case Function::COS:
                    return "cos";

                case Function::TAN:
                    return "tan";

                case Function::LOG:
                    return "log";

                case Function::INV:
                    return "inv";

                default:
                    return "error";
            }
        }

        string prefix_to_infix(prefix_t &prefix) {
            stack<string> s;
            for (int i = prefix.size() - 1; i >= 0; i--) {
                Node &node = prefix[i];
                if (node.node_type == NodeType::CONST) {
                    s.push(std::to_string(node.constant));
                } else if (node.node_type == NodeType::VAR) {
                    string var = "x";
                    var.append(std::to_string(node.variable));
                    s.push(var);
                } else if (node.node_type == NodeType::BFUNC) {
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
                if (node.node_type == NodeType::UFUNC || node.node_type == NodeType::BFUNC) {
                    ret.append(function_to_string(node.function)).append(" ");
                } else if (node.node_type == NodeType::VAR) {
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
            if (prefix[start_pos].node_type == NodeType::CONST || prefix[start_pos].node_type == NodeType::VAR) {
                return {start_pos, start_pos + 1};
            }

            // if the pos is not a terminal, we find the corresponding subtree
            int op_count = 0;
            int num_count = 0;
            int end = start_pos;

            for (; end < len; end++) {
                Node &node = prefix[end];

                if (node.node_type == NodeType::BFUNC) {
                    op_count++;
                } else if (node.node_type == NodeType::VAR || node.node_type == NodeType::CONST) {
                    num_count++;
                } else // if (node.node_type == NodeType::UFUNC)
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