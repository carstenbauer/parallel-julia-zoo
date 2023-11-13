# nested parallelism, non-uniform outer + ~uniform inner
using Base.Threads
using BenchmarkTools
using ChunkSplitters

# for good measure and stable results
using ThreadPinning
pinthreads(:cores)

using InteractiveUtils
versioninfo()

function pi_serial(N)
    M = 0
    for _ in 1:N
        if rand()^2 + rand()^2 < 1.0
            M += 1
        end
    end
    return 4 * M / N
end

function pi_parallel_spawn(N; ntasks=nthreads())
    chnks = chunks(1:N, ntasks)
    t = map(chnks) do (idcs, _)
        @spawn pi_serial(length(idcs))
    end
    return sum(fetch.(t)) / ntasks
end

function pi_parallel_threads(N; ntasks=nthreads())
    chnks = chunks(1:N, ntasks)
    pis = Vector{Float64}(undef, ntasks)
    @threads :dynamic for (idcs, j) in chnks
        pis[j] = pi_serial(length(idcs))
    end
    return sum(pis) / ntasks
end

# N = 500_000_000
# pi_serial(N)
# pi_parallel_threads(N)
# pi_parallel_spawn(N)

# @btime pi_serial($N) samples = 5 evals = 3; # 1.652 s (0 allocations: 0 bytes)
# @btime pi_parallel_threads($N) samples = 5 evals = 3; # 211.254 ms (42 allocations: 4.48 KiB)
# @btime pi_parallel_spawn($N) samples = 5 evals = 3; # 225.451 ms (59 allocations: 4.66 KiB)

function pis_spawn_serial(Ns)
    t = map(Ns) do N
        @spawn pi_serial(N)
    end
    return fetch.(t)
end

function pis_threads_serial(Ns)
    pis = Vector{Float64}(undef, length(Ns))
    @threads :dynamic for i in eachindex(Ns)
        @inbounds pis[i] = pi_serial(Ns[i])
    end
    return pis
end

function pis_spawn_spawn(Ns; ntasks=nthreads())
    t = map(Ns) do N
        @spawn pi_parallel_spawn(N; ntasks)
    end
    return fetch.(t)
end

function pis_threads_threads(Ns)
    pis = Vector{Float64}(undef, length(Ns))
    @threads :dynamic for i in eachindex(Ns)
        @inbounds pis[i] = pi_parallel_threads(Ns[i])
    end
    return pis
end

logspace(start, stop, length) = exp2.(range(log2(start), log2(stop); length=length))
Ns = logspace(1_000, 100_000_000, 10 * nthreads())

# pis_spawn_serial(Ns)
# pis_threads_serial(Ns)
# pis_threads_threads(Ns)
# pis_spawn_spawn(Ns)

# @btime pis_threads_serial($Ns) samples = 5 evals = 3; # 2.010 s (426 allocations: 31.70 KiB)
# @btime pis_spawn_serial($Ns) samples = 5 evals = 3; # 538.791 ms (489 allocations: 41.70 KiB)
# @btime pis_threads_threads($Ns) samples = 5 evals = 3; # 315.893 ms (3402 allocations: 383.70 KiB)
# @btime pis_spawn_spawn($Ns) samples = 5 evals = 3; # 322.636 ms (5129 allocations: 414.20 KiB)
# @btime pis_spawn_spawn($Ns; ntasks=10 * nthreads()) samples = 5 evals = 3; # 312.069 ms (39689 allocations: 3.40 MiB)

# Benchmark
funcs = (pis_threads_serial, pis_spawn_serial, pis_threads_threads, pis_spawn_spawn)
names = ("threads+serial", "spawn+serial", "threads+threads", "spawn+spawn")

println("\n benchmark")
for (func, n) in zip(funcs, names)
    println("\t $n")
    @btime $func($Ns) samples = 5 evals = 3
end
flush(stdout)
