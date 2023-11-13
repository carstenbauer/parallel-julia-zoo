# non-uniform workload, each task creates local temporary storage (via allocate function)
# essentially, just a different formulation of the task_local_storage idea
# inspired by https://juliafolds.github.io/data-parallelism/tutorials/concurrency-patterns/#worker_pool
using Base.Threads
nthreads()

using LinearAlgebra
using ChunkSplitters
using BenchmarkTools
using ThreadPinning
pinthreads(:cores)
BLAS.set_num_threads(1)

function workerpool(work!::A, allocate::B, input, results; ntasks=nthreads()) where {A,B}
    chnks = chunks(input, ntasks)
    @sync for (idcs, itask) in chnks
        @spawn allocate() do storage
            work!(results, input, idcs, storage)
        end
    end
end

let N = 256
    function allocate(body)
        storage = zeros(N, N)
        body(storage)
    end

    function work!(results, input, idcs, C)
        for i in idcs
            fill!(C, 0.0)
            A, B = input[i]
            for _ in 1:i
                mul!(C, A, B)
            end
            results[i] = sum(C)
        end
    end

    matrices = [(rand(N, N), rand(N, N)) for i in 1:10*nthreads()]
    results = [0.0 for _ in eachindex(matrices)]

    @btime workerpool($work!, $allocate, $matrices, $results; ntasks=nthreads()) samples = 5 evals = 3 # 576.524 ms (65 allocations: 4.00 MiB)
    @btime workerpool($work!, $allocate, $matrices, $results; ntasks=2 * nthreads()) samples = 5 evals = 3 # 445.588 ms (122 allocations: 8.01 MiB)
    @btime workerpool($work!, $allocate, $matrices, $results; ntasks=10 * nthreads()) samples = 5 evals = 3 # 330.580 ms (571 allocations: 40.05 MiB)
end
