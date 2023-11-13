# This axpy benchmark is supposed to be run on a system with multiple NUMA domains
# (e.g. a HPC cluster node) and, ideally, with nthreads() == number of numa domains.
#
# For more information, check out: https://github.com/carstenbauer/juliahep-hpctutorial
#
using ChunkSplitters
using Base.Threads
using BenchmarkTools
using LinearAlgebra

# for good measure and stable results
using ThreadPinning
pinthreads(:numa)

if nthreads() < nnuma()
    @warn("You are running this benchmark with less Julia threads than there are NUMA domains.")
end

using InteractiveUtils
versioninfo()


function axpy_serial!(y, a, x; chunks)
    @simd for i in eachindex(x, y)
        y[i] = a * x[i] + y[i]
    end
    return y
end

function axpy_spawn!(y, a, x; chunks)
    @sync for (idcs, _) in chunks
        @spawn begin
            @simd for i in idcs
                @inbounds y[i] = a * x[i] + y[i]
            end
        end
    end
    return y
end

function axpy_atthreads_static!(y, a, x; chunks)
    @threads :static for (idcs, _) in chunks
        @simd for i in idcs
            @inbounds y[i] = a * x[i] + y[i]
        end
    end
    return y
end

function axpy_atthreads_dynamic!(y, a, x; chunks)
    @threads :dynamic for (idcs, _) in chunks
        @simd for i in idcs
            @inbounds y[i] = a * x[i] + y[i]
        end
    end
    return y
end

# Benchmark
funcs = (axpy_serial!, axpy_atthreads_static!, axpy_atthreads_dynamic!, axpy_spawn!)
names = ("serial", "threads :static", "threads :dynamic", "spawn")
N = 2^30
for nchunks in (nthreads(), 1000 * nthreads())
    println("\n\n nchunks = ", nchunks)

    # input data
    cs = chunks(1:N, nchunks)
    a = 3.141
    x = Vector{Float64}(undef, N)
    y = Vector{Float64}(undef, N)
    @threads :static for (idcs, tid) in cs # NUMA first-touch
        @inbounds for i in idcs
            x[i] = rand()
            y[i] = rand()
        end
    end

    println("\n correctness check")
    for (func, n) in zip(funcs, names)
        println("\t $n")
        res = func(copy(y), a, copy(x); chunks=cs) ≈ axpy!(a, copy(x), copy(y)) # BLAS built-in
        println("\t\t $res")
    end

    println("\n benchmark")
    for (func, n) in zip(funcs, names)
        println("\t $n")
        @btime $func($y, $a, $x; chunks=$cs) samples = 5 evals = 3
    end
    flush(stdout)
end
