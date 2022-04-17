
#ifndef LUMINOCUGP_PROGRAM_CUH
#define LUMINOCUGP_PROGRAM_CUH

#include "prefix.cuh"
#include <cmath>
#include <memory>

#define DELTA 0.01f

namespace cusr {

    namespace program {

        typedef enum Metric {
            mean_absolute_error,
            mean_square_error,
            root_mean_square_error
        } metric_t;


        struct Program {
            prefix_t prefix;
            int depth{};
            int length{};
            float fitness{};
        };


        /**
         * crossover mutation
         *
         * @param parent
         * @param donor
         * @return
         */
        Program crossover_mutation(Program &parent, Program &donor);


        /**
         * mutate a node of the program correspond to its type
         * unary function --> unary function
         * binary function --> binary function
         * terminal --> terminal
         *
         * @param program
         * @param function_set
         * @param range
         * @param variable_num
         * @return
         */
        Program
        point_mutation(Program &program, vector<Function> &function_set, pair<float, float> &range, int variable_num);


        /**
         * hoist mutation
         * select subtree A from a program, subtree B from A, replace A from B
         * @param program
         * @return
         */
        Program hoist_mutation(Program &program);


        /**
         * do point replace mutation for a program
         *
         * @param program
         * @return
         */
        Program point_replace_mutation(Program &program, vector<Function> &function_set, pair<float, float> &range,
                                       int variable_num);


        /**
         * do subtree mutation for a parent tree
         * @param program
         * @param depth_of_rand_tree
         * @param range
         * @param func_set
         * @param variable_num
         * @return
         */
        Program subtree_mutation(Program &program, int depth_of_rand_tree,
                                 pair<float, float> &range, vector<Function> &func_set, int variable_num);


        /**
         * evaluation fitness for a single program on the CPU
         *
         * @param program
         * @param dataset
         * @param real_value
         * @param data_size
         * @param parsimony_coefficient
         */
        void
        calculate_fitness_cpu(Program *program, const vector<vector<float>> &dataset, const vector<float> &real_value,
                              int data_size,
                              metric_t metric);


        /**
         * tournament selection performed on the CPU
         *
         * @param population
         * @param tournament_size
         */
        int tournament_selection_cpu(vector<Program> &population, int tournament_size, float parsimony_coefficient);


        /**
         * generate a full-tree as an expression tree
         *
         * @param depth
         * @param range
         * @param func_set
         * @param variable_num
         * @return
         */
        Program *
        gen_full_init_program(int depth, pair<float, float> &range, vector<Function> &func_set, int variable_num);


        /**
         * generate a growth-tree as an expression tree
         *
         * @param depth
         * @param range
         * @param func_set
         * @param variable_num
         * @return
         */
        Program *
        gen_growth_init_program(int depth, pair<float, float> &range, vector<Function> &func_set, int variable_num);

    }
}
#endif //LUMINOCUGP_PROGRAM_CUH
