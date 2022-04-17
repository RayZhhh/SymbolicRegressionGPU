#ifndef LUMINOCUGP_FIT_EVAL_CUH
#define LUMINOCUGP_FIT_EVAL_CUH

#include <iostream>
#include <vector>
#include "cuda_runtime.h"
#include "device_launch_parameters.h"
#include "program.cuh"
#include <thrust/device_vector.h>
#include <thrust/host_vector.h>
#include <cassert>

#define THREAD_PER_BLOCK 512
#define MAX_PREFIX_LEN 2048
#define DEPTH 18
#define ADD_SIGN 0
#define SUB_SIGN 1
#define MUL_SIGN 2
#define DIV_SIGN 3
#define TAN_SIGN 4
#define SIN_SIGN 5
#define COS_SIGN 6
#define LOG_SIGN 7
#define MAX_SIGN 8
#define MIN_SIGN 9
#define INV_SIGN 10


namespace cusr {
    namespace fit {

        using namespace program;
        using namespace std;


        struct GPUDataset {
            float *dataset;
            size_t dataset_pitch;
            float *label;
            int dataset_size;
        };


        /**
         * copy dataset from host side to device side
         * host side dataset:  x0, x1, .., xn
         *                     x0, x1, .., xn
         *                     .., .., .., ..
         *                     x0, x1, .., xn
         *
         * predicted value:    y0, y1, .., ym
         * the length of predicted value equals to the length of dataset
         * dataset will be in column-major storage in the device side to perform coalesced memory access
         * @param dsStruct
         * @param dataset
         * @param label
         */
        void copyDatasetAndLabel(GPUDataset *dsStruct, vector<vector<float>> &dataset, vector<float> &label);


        /**
         * free data structure on the device side.
         * @param dataset_struct
         */
        void freeDataSetAndLabel(GPUDataset *dataset_struct);


        /**
         * evaluate fitness for a population
         * @param dataset
         * @param blockNum
         * @param population
         * @param metric
         */
        void
        calculatePopulationFitness(GPUDataset &dataset, int blockNum, vector<Program> &population, metric_t metric);
    }
}
#endif //LUMINOCUGP_FIT_EVAL_CUH
