# non-uniform workload, each task holds local temporary storage
using Base.Threads
nthreads()

using LinearAlgebra
using ChunkSplitters
using BenchmarkTools
using ThreadPinning
pinthreads(:cores)
BLAS.set_num_threads(1)

# each task will hold a local instance of `TaskStorage` as temporary storage
struct TaskStorage
    C::Matrix{Float64}
end

function compute_tasklocalstorage!(results, matrices; ntasks=nthreads())
    N = size(matrices[1][1], 1)
    chnks = chunks(matrices, ntasks)

    @sync for (idcs, itask) in chnks
        @spawn begin
            local storage = TaskStorage(zeros(N, N))
            C = storage.C
            for i in idcs
                fill!(C, 0.0)
                A, B = matrices[i]
                for _ in 1:i
                    mul!(C, A, B)
                end
                results[i] = sum(C)
            end
        end
    end

    return results
end

let N = 256
    matrices = [(rand(N, N), rand(N, N)) for i in 1:10*nthreads()]
    results = [0.0 for _ in eachindex(matrices)]

    @btime compute_tasklocalstorage!($results, $matrices; ntasks=nthreads()) samples = 5 evals = 3 # 580.754 ms (65 allocations: 4.00 MiB)
    @btime compute_tasklocalstorage!($results, $matrices; ntasks=2 * nthreads()) samples = 5 evals = 3 # 457.921 ms (122 allocations: 8.01 MiB)
    @btime compute_tasklocalstorage!($results, $matrices; ntasks=10 * nthreads()) samples = 5 evals = 3 # 334.726 ms (571 allocations: 40.05 MiB)

    nothing
end


# Using the generic `Base.task_local_storage` instead of `TaskStorage`
function compute_tasklocalstorage_iddict!(results, matrices; ntasks=nthreads())
    N = size(matrices[1][1], 1)
    chnks = chunks(matrices, ntasks)

    @sync for (idcs, itask) in chnks
        @spawn begin
            Base.task_local_storage(:C, zeros(N, N))
            for i in idcs
                C = Base.task_local_storage(:C)
                fill!(C, 0.0)
                A, B = matrices[i]
                for _ in 1:i
                    mul!(C, A, B)
                end
                results[i] = sum(C)
            end
        end
    end

    return results
end

let N = 256
    matrices = [(rand(N, N), rand(N, N)) for i in 1:10*nthreads()]
    results = [0.0 for _ in eachindex(matrices)]

    @btime compute_tasklocalstorage_iddict!($results, $matrices; ntasks=nthreads()) samples = 5 evals = 3 # 564.494 ms (161 allocations: 4.01 MiB)
    @btime compute_tasklocalstorage_iddict!($results, $matrices; ntasks=2 * nthreads()) samples = 5 evals = 3 # 459.464 ms (234 allocations: 8.02 MiB)
    @btime compute_tasklocalstorage_iddict!($results, $matrices; ntasks=10 * nthreads()) samples = 5 evals = 3 # 330.662 ms (811 allocations: 40.07 MiB)

    nothing
end
