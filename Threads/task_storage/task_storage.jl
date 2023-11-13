# non-uniform workload, each task works with own temporary storage (not local)
using Base.Threads
nthreads()

using LinearAlgebra
using ChunkSplitters
using BenchmarkTools
using ThreadPinning
pinthreads(:cores)
BLAS.set_num_threads(1)

# each task will use a `TaskStorage` object as temporary storage
struct TaskStorage
    C::Matrix{Float64}
end

function compute_taskstorage!(results, matrices; ntasks=nthreads())
    N = size(matrices[1][1], 1)
    storages = [TaskStorage(zeros(N, N)) for _ in 1:ntasks]
    chnks = chunks(matrices, ntasks)

    @sync for (idcs, itask) in chnks
        @spawn begin
            C = storages[itask].C
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

    @btime compute_taskstorage!($results, $matrices; ntasks=nthreads()) samples = 5 evals = 3 # 579.748 ms (66 allocations: 4.01 MiB)
    @btime compute_taskstorage!($results, $matrices; ntasks=2 * nthreads()) samples = 5 evals = 3 # 461.866 ms (123 allocations: 8.01 MiB)
    @btime compute_taskstorage!($results, $matrices; ntasks=10 * nthreads()) samples = 5 evals = 3 # 332.164 ms (572 allocations: 40.05 MiB)
    nothing
end
