#include "include/cusr.h"

using namespace std;
using namespace cusr;

// we consider approximating Pagie polynomial,
// which is defined by: f(x, y) = 1 / (1 + x ^ (-4)) + 1 / (1 + y ^ (-4))
vector<vector<float>> dataset;
vector<float> real_value;


void gen_dataset() {
    cout << "gen dataset" << endl;
    for (int i = 0; i < 2048 * 2048; i++) {
        float x0 = cusr::program::gen_rand_float(-5, 5);
        float x1 = cusr::program::gen_rand_float(-5, 5);
        dataset.push_back({x0, x1});
        real_value.push_back(x0 * x0 * x0 * x0 / (x0 * x0 * x0 * x0 + 1) + x1 * x1 * x1 * x1 / (x1 * x1 * x1 * x1 + 1));
    }
    cout << "gen dataset finish" << endl;
}


int main() {
    gen_dataset();
    cusr::RegressionEngine reg;
    reg.function_set = {ADD, COS, SUB, DIV, TAN, MUL, SIN };
    reg.use_gpu = true;            // performing GPU acceleration -- much faster than CPU
    reg.max_program_depth = 10;    // better less than 20 --
                                   // or may cause overflow due to the limitation of the length of prefix (less than 2048)
    reg.population_size = 50;
    reg.generations = 50;
    reg.parsimony_coefficient = 0;            // this param prevents program from bloating  -- derived from "gplearn"
    reg.const_range = {-5, 5};      // the range of the constant of each program
    reg.init_depth = {4, 10};       // the range of init depth of the expression tree
    reg.init_method = init_t::half_and_half;   // ramped half-and-half is recommended
    reg.tournament_size = 3;                   // it only supports tournament selection
    reg.metric = metric_t::root_mean_square_error; // also support MAE error and MSE error
    reg.fit(dataset, real_value); // do training

    // after training
    cout << "execution time: " << reg.regress_time_in_sec << endl;
    cout << "best fitness  : " << reg.best_program.fitness << endl;
    // optimal program
    cout << "best program (in prefix):  " << cusr::program::prefix_to_string(reg.best_program.prefix) << endl;
    cout << "best program (in infix) :  " << cusr::program::prefix_to_infix(reg.best_program.prefix) << endl;
    return 0;
}