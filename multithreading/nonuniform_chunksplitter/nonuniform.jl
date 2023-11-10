using Base.Threads
using BenchmarkTools
using ChunkSplitters
# for good measure and stable results
using ThreadPinning
pinthreads(:cores)

using InteractiveUtils
versioninfo()

work_load = ceil.(Int, collect(10^3 * exp(-0.002 * i) for i in 1:2^11));

#using UnicodePlots
#lineplot(work_load; xlabel="task", ylabel="workload", xlim=(1,2^11))
#
#                  ┌────────────────────────────────────────┐
#            1 000 │⣇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀│
#                  │⠘⡆⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀│
#                  │⠀⢹⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀│
#                  │⠀⠀⢳⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀│
#                  │⠀⠀⠀⢧⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀│
#                  │⠀⠀⠀⠈⢧⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀│
#                  │⠀⠀⠀⠀⠈⢳⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀│
#   workload       │⠀⠀⠀⠀⠀⠀⠳⡄⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀│
#                  │⠀⠀⠀⠀⠀⠀⠀⠙⢦⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀│
#                  │⠀⠀⠀⠀⠀⠀⠀⠀⠈⠳⣄⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀│
#                  │⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⠳⣄⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀│
#                  │⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⠙⢦⣀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀│
#                  │⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⠙⠲⢤⣀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀│
#                  │⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⠉⠓⠦⠤⣄⣀⣀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀│
#                0 │⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⠉⠉⠓⠒⠒⠒⠦⠤⠤⠤⠤⠤⠤│
#                  └────────────────────────────────────────┘
#                  ⠀1⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀2 048⠀
#                  ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀task⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀

function nonuniform_serial(x, work_load; nchunks=nthreads(), chunk_type=:batch)
    s = zero(eltype(x))
    for i in eachindex(work_load)
        s += sum(j -> log(x[j])^7, 1:work_load[i])
    end
    return s
end

function nonuniform_spawn(x, work_load; nchunks=nthreads(), chunk_type=:batch)
    ts = map(chunks(work_load, nchunks, chunk_type)) do (idcs, ichunk)
        @spawn begin
            s = zero(eltype(x))
            for i in idcs
                s += sum(log(x[j])^7 for j in 1:work_load[i])
            end
            s
        end
    end
    return sum(fetch.(ts))
end

function nonuniform_atthreads_dynamic(x, work_load; nchunks=nthreads(), chunk_type=:batch)
    chunk_sums = Vector{eltype(x)}(undef, nchunks)
    @threads :dynamic for (idcs, ichunk) in chunks(work_load, nchunks, chunk_type)
        s = zero(eltype(x))
        for i in idcs
            s += sum(j -> log(x[j])^7, 1:work_load[i])
        end
        chunk_sums[ichunk] = s
    end
    return sum(chunk_sums)
end

function nonuniform_atthreads_static(x, work_load; nchunks=nthreads(), chunk_type=:batch)
    chunk_sums = Vector{eltype(x)}(undef, nchunks)
    @threads :static for (idcs, ichunk) in chunks(work_load, nchunks, chunk_type)
        s = zero(eltype(x))
        for i in idcs
            s += sum(j -> log(x[j])^7, 1:work_load[i])
        end
        chunk_sums[ichunk] = s
    end
    return sum(chunk_sums)
end

x = rand(10^9);

# Benchmark
funcs = (nonuniform_serial, nonuniform_spawn, nonuniform_atthreads_static, nonuniform_atthreads_dynamic)
names = ("serial", "spawn", "threads :static", "threads :dynamic")
nchunks = nthreads()

println("\n\n correctness check")
for (func, n) in zip(funcs, names)
    println("\t $n")
    res = func(x, work_load; nchunks=nchunks, chunk_type=:batch) ≈ nonuniform_serial(x, work_load)
    println("\t\t $res")
end

println("\n benchmark")
for (func, n) in zip(funcs, names)
    println("\t $n")
    @btime $func($x, $work_load; nchunks=$nchunks, chunk_type=:batch) samples = 5 evals = 3;
end
flush(stdout)

# More chunks than threads
println("\n\n  ---- nchunks >> nthreads")
nchunks = 100 * nthreads()
println("correctness check")
for (func, n) in zip(funcs, names)
    println("\t $n")
    res = func(x, work_load; nchunks=nchunks) ≈ nonuniform_serial(x, work_load)
    println("\t\t $res")
end

println("\n benchmark")
for (func, n) in zip(funcs, names)
    println("\t $n")
    @btime $func($x, $work_load; nchunks=$nchunks, chunk_type=:batch) samples = 5 evals = 3;
end
flush(stdout)


# :scatter chunking
println("\n\n  ---- :scatter chunking")
nchunks = nthreads()
println("correctness check")
for (func, n) in zip(funcs, names)
    println("\t $n")
    res = func(x, work_load; nchunks=nchunks, chunk_type=:scatter) ≈ nonuniform_serial(x, work_load)
    println("\t\t $res")
end

println("\n benchmark")
for (func, n) in zip(funcs, names)
    println("\t $n")
    @btime $func($x, $work_load; nchunks=$nchunks, chunk_type=:scatter) samples = 5 evals = 3;
end
flush(stdout)
