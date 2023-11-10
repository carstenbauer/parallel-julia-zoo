# non-uniform workload example
using Base.Threads
using BenchmarkTools

# for good measure and stable results
using ThreadPinning
pinthreads(:cores)

using InteractiveUtils
versioninfo()

function fib(i)
    if i < 2
        return i
    else
        a1 = 1
        a2 = 1
        for j in 1:i-2
            a1, a2 = a2, a1 + a2
        end
        return a2
    end
end

@assert fib(1) == 1
@assert fib(3) == 2
@assert fib(5) == 5
@assert fib(7) == 13
@assert fib(10) == 55

function serial(N)
    s = zeros(Int, Threads.maxthreadid()*10)
    for j in 1:10:N
        s[(Threads.threadid()-1)*10+1] += fib(j)
    end
    return sum(s)
end

function static(N)
    s = zeros(Int, Threads.maxthreadid()*10)
    @threads :static for j in 1:10:N
        s[(Threads.threadid()-1)*10+1] += fib(j)
    end
    return sum(s)
end

function dynamic(N)
    s = zeros(Int, Threads.maxthreadid()*10)
    @threads :dynamic for j in 1:10:N
        s[(Threads.threadid()-1)*10+1] += fib(j)
    end
    return sum(s)
end

function spawn(N)
    s = zeros(Int, Threads.maxthreadid()*10)
    @sync for j in 1:10:N
        @spawn begin
            s[(Threads.threadid()-1)*10+1] += fib(j)
        end
    end
    return sum(s)
end


# Benchmark
funcs = (serial, spawn, dynamic, static)
names = ("serial", "spawn", "threads :dynamic", "threads :static")

N = 12000

println("\n\n correctness check")
for (func, n) in zip(funcs, names)
    println("\t $n")
    res = func(N) ≈ serial(N)
    println("\t\t $res")
end

println("\n benchmark")
for (func, n) in zip(funcs, names)
    println("\t $n")
    @btime $func($N) samples = 8 evals = 5
end
flush(stdout)
