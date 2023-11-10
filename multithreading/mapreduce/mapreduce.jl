using ChunkSplitters # alternative: Iterators.partition
using Base.Threads
using BenchmarkTools
using ThreadPinning
pinthreads(:cores) # for good measure and stable results

function mapreduction_serial(f::F, op::G, x) where {F,G}
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

function mapreduction_atthreads_static(f::F, op::G, x) where {F,G}
    rs = Vector{eltype(x)}(undef, nthreads())
    @threads :static for (idcs, c) in chunks(x, nthreads())
        @inbounds rs[c] = mapreduction_serial(f, op, @view x[idcs])
    end
    return mapreduction_serial(identity, op, rs)
end

function mapreduction_atthreads_dynamic(f::F, op::G, x) where {F,G}
    rs = Vector{eltype(x)}(undef, nthreads())
    @threads :dynamic for (idcs, c) in chunks(x, nthreads())
        @inbounds rs[c] = mapreduction_serial(f, op, @view x[idcs])
    end
    return mapreduction_serial(identity, op, rs)
end

# The following requires https://github.com/JuliaLang/julia/pull/52096
function mapreduction_atthreads_greedy(f::F, op::G, x) where {F,G}
    rs = Vector{eltype(x)}(undef, nthreads())
    @threads :greedy for (idcs, c) in chunks(x, nthreads())
        @inbounds rs[c] = mapreduction_serial(f, op, @view x[idcs])
    end
    return mapreduction_serial(identity, op, rs)
end

x = rand(100_000_000 * nthreads())

nthreads() # 6 on my machine

# f = identity
mapreduction_serial(identity, +, x) ≈ mapreduce(identity, +, x) # true
mapreduction_spawn(identity, +, x) ≈ mapreduce(identity, +, x) # true
mapreduction_atthreads_static(identity, +, x) ≈ mapreduce(identity, +, x) # true
mapreduction_atthreads_dynamic(identity, +, x) ≈ mapreduce(identity, +, x) # true
mapreduction_atthreads_greedy(identity, +, x) ≈ mapreduce(identity, +, x) # false

@btime mapreduction_serial($identity, $+, $x) samples = 5 evals = 3; # 144.020 ms (0 allocations: 0 bytes)
@btime mapreduction_spawn($identity, $+, $x) samples = 5 evals = 3; # 102.989 ms (48 allocations: 3.69 KiB)
@btime mapreduction_atthreads_static($identity, $+, $x) samples = 5 evals = 3; # 95.043 ms (34 allocations: 3.41 KiB)
@btime mapreduction_atthreads_dynamic($identity, $+, $x) samples = 5 evals = 3; # 87.049 ms (34 allocations: 3.41 KiB)
@btime mapreduction_atthreads_greedy($identity, $+, $x) samples = 5 evals = 3; # 64.111 μs (75 allocations: 5.48 KiB)

# f = sin
mapreduction_serial(sin, +, x) ≈ mapreduce(sin, +, x)
mapreduction_spawn(sin, +, x) ≈ mapreduce(sin, +, x)
mapreduction_atthreads_static(sin, +, x) ≈ mapreduce(sin, +, x)
mapreduction_atthreads_dynamic(sin, +, x) ≈ mapreduce(sin, +, x)
mapreduction_atthreads_greedy(sin, +, x) ≈ mapreduce(sin, +, x)

@btime mapreduction_serial($sin, $+, $x) samples = 5 evals = 3;
@btime mapreduction_spawn($sin, $+, $x) samples = 5 evals = 3;
@btime mapreduction_atthreads_static($sin, $+, $x) samples = 5 evals = 3;
@btime mapreduction_atthreads_dynamic($sin, $+, $x) samples = 5 evals = 3;
@btime mapreduction_atthreads_greedy($sin, $+, $x) samples = 5 evals = 3;
