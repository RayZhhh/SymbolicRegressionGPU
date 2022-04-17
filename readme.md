# CUSR -- A Genetic Programming Based Symbolic Regression Framework Implemented by CUDA C/C++

## Algorithm
We speed up gp-based symbolic regression by performing parallel execution in the fitness evaluation step (which is known as the bottleneck) on the GPU. 
We optimize device-side data structures for gp-based SR. 
We implement a stack with contiguous memory address, which supports coalesced memory access. We also achieve parallel metric reduction on the GPU.

## Compile And Run
```shell
cd cusr
nvcc -o run_sr run_cusr.cu src/prefix.cu src/program.cu src/regression.cu src/fit_eval.cu
./run_sr
```

