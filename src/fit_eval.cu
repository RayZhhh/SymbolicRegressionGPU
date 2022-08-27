#include "fit_eval.cuh"

namespace cusr {
    namespace fit {

        using namespace program;
        using namespace std;

        void copyDatasetAndLabel(GPUDataset *dataset_struct, vector<vector<float>> &dataset, vector<float> &label) {
            dataset_struct->dataset_size = dataset.size();

            // format dataset into column-major
            int data_size = dataset.size();
            int variable_num = dataset[0].size();

            vector<float> device_dataset;

            for (int i = 0; i < variable_num; i++) {
                for (int j = 0; j < data_size; j++) {
                    device_dataset.emplace_back(dataset[j][i]);
                }
            }

            // copy dataset
            float *device_dataset_arr;
            size_t dataset_pitch;
            cudaMallocPitch((void **) &device_dataset_arr, &dataset_pitch, sizeof(float) * data_size, variable_num);
            cudaMemcpy2D(device_dataset_arr, dataset_pitch, thrust::raw_pointer_cast(device_dataset.data()),
                         sizeof(float) * data_size, sizeof(float) * data_size, variable_num, cudaMemcpyHostToDevice);

            dataset_struct->dataset_pitch = dataset_pitch;
            dataset_struct->dataset = device_dataset_arr;

            // copy label set
            float *device_label_arr;
            cudaMalloc((void **) &device_label_arr, sizeof(float) * data_size);
            cudaMemcpy(device_label_arr, thrust::raw_pointer_cast(label.data()), sizeof(float) * data_size,
                       cudaMemcpyHostToDevice);

            dataset_struct->label = device_label_arr;
        }

        void freeDataSetAndLabel(GPUDataset *dataset_struct) {
            cudaFree(dataset_struct->dataset);
            cudaFree(dataset_struct->label);
        }

        __constant__ float d_nodeValue[MAX_PREFIX_LEN];
        __constant__ float d_nodeType[MAX_PREFIX_LEN];

#define S_OFF THREAD_PER_BLOCK * (DEPTH + 1) * blockIdx.x + top * THREAD_PER_BLOCK + threadIdx.x

        __global__ void
        calFitnessGPU_MSE(int len, float *ds, int dsPitch, float *label, float *stack, float *result,
                          int dataset_size) {
            extern __shared__ float shared[];
            shared[threadIdx.x] = 0;

            // each thread is responsible for one datapoint
            int dataset_no = blockIdx.x * THREAD_PER_BLOCK + threadIdx.x;

            if (dataset_no < dataset_size) {
                int top = 0;

                // do stack operation according to the type of each node
                for (int i = len - 1; i >= 0; i--) {
                    int node_type = d_nodeType[i];
                    float node_value = d_nodeValue[i];

                    if (node_type == NodeType::CONST) {
                        stack[S_OFF] = node_value;
                        top++;
                    } else if (node_type == NodeType::VAR) {
                        int var_num = node_value;
                        stack[S_OFF] = ((float *) ((char *) ds + var_num * dsPitch))[dataset_no];
                        top++;
                    } else if (node_type == NodeType::UFUNC) {
                        int function = node_value;
                        top--;
                        float var1 = stack[S_OFF];
                        if (function == Function::SIN) {
                            stack[S_OFF] = std::sin(var1);
                            top++;
                        } else if (function == Function::COS) {
                            stack[S_OFF] = std::cos(var1);
                            top++;
                        } else if (function == Function::TAN) {
                            stack[S_OFF] = std::tan(var1);
                            top++;
                        } else if (function == Function::LOG) {
                            if (var1 <= 0) {
                                stack[S_OFF] = -1.0f;
                                top++;
                            } else {
                                stack[S_OFF] = std::log(var1);
                                top++;
                            }
                        } else if (function == Function::INV) {
                            if (var1 == 0) {
                                var1 = DELTA;
                            }
                            stack[S_OFF] = 1.0f / var1;
                            top++;
                        }
                    } else // if (node_type == NodeType::BFUNC)
                    {
                        int function = node_value;
                        top--;
                        float var1 = stack[S_OFF];
                        top--;
                        float var2 = stack[S_OFF];
                        if (function == Function::ADD) {
                            stack[S_OFF] = var1 + var2;
                            top++;
                        } else if (function == Function::SUB) {
                            stack[S_OFF] = var1 - var2;
                            top++;
                        } else if (function == Function::MUL) {
                            stack[S_OFF] = var1 * var2;
                            top++;
                        } else if (function == Function::DIV) {
                            if (var2 == 0) {
                                var2 = DELTA;
                            }
                            stack[S_OFF] = var1 / var2;
                            top++;
                        } else if (function == Function::MAX) {
                            stack[S_OFF] = var1 >= var2 ? var1 : var2;
                            top++;
                        } else if (function == Function::MIN) {
                            stack[S_OFF] = var1 <= var2 ? var1 : var2;
                            top++;
                        }
                    }
                }

                top--;
                float prefix_value = stack[S_OFF];
                float label_value = label[dataset_no];
                float loss = prefix_value - label_value;
                float fitness = loss * loss;
                shared[threadIdx.x] = fitness;
            }

            __syncthreads();

            // do parallel reduction
#if THREAD_PER_BLOCK >= 1024
            if (threadIdx.x < 512) { shared[threadIdx.x] += shared[threadIdx.x + 512]; }
            __syncthreads();
#endif
#if THREAD_PER_BLOCK >= 512
            if (threadIdx.x < 256) { shared[threadIdx.x] += shared[threadIdx.x + 256]; }
            __syncthreads();
#endif
            if (threadIdx.x < 128) { shared[threadIdx.x] += shared[threadIdx.x + 128]; }
            __syncthreads();
            if (threadIdx.x < 64) { shared[threadIdx.x] += shared[threadIdx.x + 64]; }
            __syncthreads();
            if (threadIdx.x < 32) { shared[threadIdx.x] += shared[threadIdx.x + 32]; }
            if (threadIdx.x < 16) { shared[threadIdx.x] += shared[threadIdx.x + 16]; }
            if (threadIdx.x < 8) { shared[threadIdx.x] += shared[threadIdx.x + 8]; }
            if (threadIdx.x < 4) { shared[threadIdx.x] += shared[threadIdx.x + 4]; }
            if (threadIdx.x < 2) { shared[threadIdx.x] += shared[threadIdx.x + 2]; }
            if (threadIdx.x < 1) {
                shared[threadIdx.x] += shared[threadIdx.x + 1];
//                result[blockIdx.x] = shared[0] / THREAD_PER_BLOCK;
                result[blockIdx.x] = shared[0];
            }
        }

        __global__ void
        calFitnessGPU_MAE(int len, float *ds, int dsPitch, float *label, float *stack, float *result,
                          int dataset_size) {
            extern __shared__ float shared[];
            shared[threadIdx.x] = 0;
            int dataset_no = blockIdx.x * THREAD_PER_BLOCK + threadIdx.x;

            if (dataset_no < dataset_size) {
                int top = 0;

                // do stack operation according to the type of the node
                for (int i = len - 1; i >= 0; i--) {
                    int node_type = d_nodeType[i];
                    float node_value = d_nodeValue[i];

                    if (node_type == NodeType::CONST) {
                        stack[S_OFF] = node_value;
                        top++;
                    } else if (node_type == NodeType::VAR) {
                        int var_num = node_value;
                        stack[S_OFF] = ((float *) ((char *) ds + var_num * dsPitch))[dataset_no];
                        top++;
                    } else if (node_type == NodeType::UFUNC) {
                        int function = node_value;
                        top--;
                        float var1 = stack[S_OFF];
                        if (function == Function::SIN) {
                            stack[S_OFF] = std::sin(var1);
                            top++;
                        } else if (function == Function::COS) {
                            stack[S_OFF] = std::cos(var1);
                            top++;
                        } else if (function == Function::TAN) {
                            stack[S_OFF] = std::tan(var1);
                            top++;
                        } else if (function == Function::LOG) {
                            if (var1 <= 0) {
                                stack[S_OFF] = -1.0f;
                                top++;
                            } else {
                                stack[S_OFF] = std::log(var1);
                                top++;
                            }
                        } else if (function == Function::INV) {
                            if (var1 == 0) {
                                var1 = DELTA;
                            }
                            stack[S_OFF] = 1.0f / var1;
                            top++;
                        }
                    } else {
                        int function = node_value;
                        top--;
                        float var1 = stack[S_OFF];
                        top--;
                        float var2 = stack[S_OFF];
                        if (function == Function::ADD) {
                            stack[S_OFF] = var1 + var2;
                            top++;
                        } else if (function == Function::SUB) {
                            stack[S_OFF] = var1 - var2;
                            top++;
                        } else if (function == Function::MUL) {
                            stack[S_OFF] = var1 * var2;
                            top++;
                        } else if (function == Function::DIV) {
                            if (var2 == 0) {
                                var2 = DELTA;
                            }
                            stack[S_OFF] = var1 / var2;
                            top++;
                        } else if (function == Function::MAX) {
                            stack[S_OFF] = var1 >= var2 ? var1 : var2;
                            top++;
                        } else if (function == Function::MIN) {
                            stack[S_OFF] = var1 <= var2 ? var1 : var2;
                            top++;
                        }
                    }
                }

                top--;
                float prefix_value = stack[S_OFF];
                float label_value = label[dataset_no];
                float loss = prefix_value - label_value;
                float fitness = loss >= 0 ? loss : -loss;
                shared[threadIdx.x] = fitness;
            }

            __syncthreads();

            // do parallel reduction
#if THREAD_PER_BLOCK >= 1024
            if (threadIdx.x < 512) { shared[threadIdx.x] += shared[threadIdx.x + 512]; }
            __syncthreads();
#endif

#if THREAD_PER_BLOCK >= 512
            if (threadIdx.x < 256) { shared[threadIdx.x] += shared[threadIdx.x + 256]; }
            __syncthreads();
#endif

            if (threadIdx.x < 128) { shared[threadIdx.x] += shared[threadIdx.x + 128]; }
            __syncthreads();
            if (threadIdx.x < 64) { shared[threadIdx.x] += shared[threadIdx.x + 64]; }
            __syncthreads();
            if (threadIdx.x < 32) { shared[threadIdx.x] += shared[threadIdx.x + 32]; }
            if (threadIdx.x < 16) { shared[threadIdx.x] += shared[threadIdx.x + 16]; }
            if (threadIdx.x < 8) { shared[threadIdx.x] += shared[threadIdx.x + 8]; }
            if (threadIdx.x < 4) { shared[threadIdx.x] += shared[threadIdx.x + 4]; }
            if (threadIdx.x < 2) { shared[threadIdx.x] += shared[threadIdx.x + 2]; }
            if (threadIdx.x < 1) {
                shared[threadIdx.x] += shared[threadIdx.x + 1];
                result[blockIdx.x] = shared[0];
            }
        }

        float *mallocStack(int blockNum) {
            float *stack;

            // allocate stack space, the size of which = sizeof(float) * THREAD_PER_BLOCK * (maxDepth + 1)
            cudaMalloc((void **) &stack, sizeof(float) * THREAD_PER_BLOCK * (DEPTH + 1) * blockNum);

            return stack;
        }

        void calSingleProgram(GPUDataset &dataset, int blockNum, Program &program,
                              float *stack, float *result, float *h_res, metric_t metric) {

            // --------- restrict the length of prefix ---------
            assert(program.length < MAX_PREFIX_LEN);
            // -------------------------------------------------

            // -------- copy to constant memory --------
            float h_nodeValue[MAX_PREFIX_LEN];
            float h_nodeType[MAX_PREFIX_LEN];

            for (int i = 0; i < program.length; i++) {
                int type = program.prefix[i].node_type;
                h_nodeType[i] = type;
                if (type == NodeType::CONST) {
                    h_nodeValue[i] = program.prefix[i].constant;
                } else if (type == NodeType::VAR) {
                    h_nodeValue[i] = program.prefix[i].variable;
                } else { // unary function or binary function
                    h_nodeValue[i] = program.prefix[i].function;
                }
            }

            cudaMemcpyToSymbol(d_nodeValue, h_nodeValue, sizeof(float) * program.length);
            cudaMemcpyToSymbol(d_nodeType, h_nodeType, sizeof(float) * program.length);

            // -------- calculation and synchronization --------
            if (metric == metric_t::mean_absolute_error) {
                calFitnessGPU_MAE<<<blockNum, THREAD_PER_BLOCK, sizeof(float) * THREAD_PER_BLOCK>>>
                        (program.length, dataset.dataset, dataset.dataset_pitch, dataset.label, stack, result,
                         dataset.dataset_size);
                cudaDeviceSynchronize();
            } else if (metric == metric_t::mean_square_error || metric == metric_t::root_mean_square_error) {
                calFitnessGPU_MSE<<<blockNum, THREAD_PER_BLOCK, sizeof(float) * THREAD_PER_BLOCK >>>
                        (program.length, dataset.dataset, dataset.dataset_pitch, dataset.label, stack, result,
                         dataset.dataset_size);
                cudaDeviceSynchronize();
            }

            // -------- reduction on the result --------
            cudaMemcpy(h_res, result, sizeof(float) * blockNum, cudaMemcpyDeviceToHost);
            float ans = 0;

            for (int i = 0; i < blockNum; i++) {
                ans += h_res[i];
            }

            if (metric == metric_t::mean_absolute_error || metric == metric_t::mean_square_error) {
                program.fitness = ans / (float) dataset.dataset_size;
            } else if (metric == metric_t::root_mean_square_error) {
                program.fitness = std::sqrt(ans / (float) dataset.dataset_size);
            }
        }

        void
        calculatePopulationFitness(GPUDataset &dataset, int blockNum, vector<Program> &population, metric_t metric) {
            // allocate space for result
            float *result;
            cudaMalloc((void **) &result, sizeof(float) * blockNum);

            // allocate stack space
            float *stack = mallocStack(blockNum);

            // save result and do CPU side reduction
            float *h_res = new float[blockNum];

            // evaluate fitness for each program in the population
            for (int i = 0; i < population.size(); i++) {
                calSingleProgram(dataset, blockNum, population[i], stack, result, h_res, metric);
            }

            // free memory space
            cudaFree(result);
            cudaFree(stack);
            delete[] h_res;
        }
    }
}