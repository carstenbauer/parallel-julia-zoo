using ChunkSplitters
using Base.Threads
using BenchmarkTools
# # for good measure and stable results
# using ThreadPinning
# pinthreads(:cores)

versioninfo()

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
x = rand(100_000_000 * nthreads())

# f = identity
mapreduction_serial(identity, +, x) ≈ mapreduce(identity, +, x)
mapreduction_spawn(identity, +, x) ≈ mapreduce(identity, +, x)
mapreduction_atthreads_static(identity, +, x) ≈ mapreduce(identity, +, x)
mapreduction_atthreads_dynamic(identity, +, x) ≈ mapreduce(identity, +, x)

@btime mapreduction_serial($identity, $+, $x) samples = 5 evals = 3;
@btime mapreduction_spawn($identity, $+, $x) samples = 5 evals = 3;
@btime mapreduction_atthreads_static($identity, $+, $x) samples = 5 evals = 3;
@btime mapreduction_atthreads_dynamic($identity, $+, $x) samples = 5 evals = 3;

# f = sin
mapreduction_serial(sin, +, x) ≈ mapreduce(sin, +, x)
mapreduction_spawn(sin, +, x) ≈ mapreduce(sin, +, x)
mapreduction_atthreads_static(sin, +, x) ≈ mapreduce(sin, +, x)
mapreduction_atthreads_dynamic(sin, +, x) ≈ mapreduce(sin, +, x)

@btime mapreduction_serial($sin, $+, $x) samples = 5 evals = 3;
@btime mapreduction_spawn($sin, $+, $x) samples = 5 evals = 3;
@btime mapreduction_atthreads_static($sin, $+, $x) samples = 5 evals = 3;
@btime mapreduction_atthreads_dynamic($sin, $+, $x) samples = 5 evals = 3;
