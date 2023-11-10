using ChunkSplitters
using Base.Threads
using BenchmarkTools
# for good measure and stable results
using ThreadPinning
pinthreads(:cores)

using InteractiveUtils
versioninfo()

function mapreduction_serial(f::F, op::G, x; nchunks=nthreads()) where {F,G}
    s = zero(eltype(x))
    # Base.mapreduce seems to manually unroll the kernel 4-fold.
    # We simply use @simd here for simplicity.
    @simd for i in eachindex(x)
        xi = @inbounds x[i]
        s = op(s, f(xi))
    end
    return s
end

function mapreduction_spawn(f::F, op::G, x; nchunks=nthreads()) where {F,G}
    t = map(chunks(x, nchunks)) do (idcs, c)
        @spawn mapreduction_serial(f, op, @view x[idcs])
    end
    return mapreduction_serial(identity, op, fetch.(t))
end

function mapreduction_atthreads_static(f::F, op::G, x; nchunks=nthreads()) where {F,G}
    rs = Vector{eltype(x)}(undef, nchunks)
    @threads :static for (idcs, c) in chunks(x, nchunks)
        @inbounds rs[c] = mapreduction_serial(f, op, @view x[idcs])
    end
    return mapreduction_serial(identity, op, rs)
end

function mapreduction_atthreads_dynamic(f::F, op::G, x; nchunks=nthreads()) where {F,G}
    rs = Vector{eltype(x)}(undef, nchunks)
    @threads :dynamic for (idcs, c) in chunks(x, nchunks)
        @inbounds rs[c] = mapreduction_serial(f, op, @view x[idcs])
    end
    return mapreduction_serial(identity, op, rs)
end

function mapreduction_atthreads_greedy(f::F, op::G, x; nchunks=nthreads()) where {F,G}
    rs = Vector{eltype(x)}(undef, nchunks)
    @threads :greedy for (idcs, c) in chunks(x, nchunks)
        @inbounds rs[c] = mapreduction_serial(f, op, @view x[idcs])
    end
    return mapreduction_serial(identity, op, rs)
end

funcs = (mapreduction_serial, mapreduction_spawn, mapreduction_atthreads_static, mapreduction_atthreads_dynamic, mapreduction_atthreads_greedy)
names = ("serial", "spawn", "threads :static", "threads :dynamic", "threads :greedy")
N = 100_000_000 * nthreads()

for nchunks in (nthreads(), 100 * nthreads())
    println("\n\n nchunks = ", nchunks)
    for f in (identity, sin)
        println("\n \t f = $f")
        x = rand(N)
        println("correctness check")
        for (func, n) in zip(funcs, names)
            println("\t\t $n")
            res = func(f, +, x; nchunks=nchunks) ≈ mapreduce(f, +, x)
            println("\t\t\t $res")
        end

        println("\n benchmark")
        for (func, n) in zip(funcs, names)
            println("\t\t $n")
            @btime $func($f, $+, $x; nchunks=$nchunks) samples = 5 evals = 3
        end
        flush(stdout)
    end
end
