cmake_minimum_required(VERSION 3.21)
project(cusr CUDA)

set(CMAKE_CUDA_STANDARD 14)

add_executable(cusr src/fit_eval.cuh src/prefix.cuh src/program.cuh src/regression.cuh src/prefix.cu src/regression.cu src/fit_eval.cu src/program.cu include/cusr.h run_cusr.cu
 experi_benchmark.cu)
set_target_properties(cusr PROPERTIES
        CUDA_SEPARABLE_COMPILATION ON)
