# non-uniform workload example
using Base.Threads
using BenchmarkTools

# for good measure and stable results
using ThreadPinning
pinthreads(:cores)

using InteractiveUtils
versioninfo()

function _compute_pixel(i, j, n; max_iter=255, c=-0.79 + 0.15 * im)
    x = -2.0 + (j - 1) * 4.0 / (n - 1)
    y = -2.0 + (i - 1) * 4.0 / (n - 1)

    z = x + y * im
    iter = max_iter
    for k in 1:max_iter
        if abs2(z) > 4.0
            iter = k - 1
            break
        end
        z = z^2 + c
    end
    return iter
end

function compute_juliaset_serial!(img)
    N, _ = size(img)
    for j in 1:N
        for i in 1:N
            @inbounds img[i, j] = _compute_pixel(i, j, N)
        end
    end
    return img
end

function compute_juliaset_threads_static!(img)
    N, _ = size(img)
    @threads :static for j in 1:N
        for i in 1:N
            @inbounds img[i, j] = _compute_pixel(i, j, N)
        end
    end
    return img
end

function compute_juliaset_threads_dynamic!(img)
    N, _ = size(img)
    @threads :dynamic for j in 1:N
        for i in 1:N
            @inbounds img[i, j] = _compute_pixel(i, j, N)
        end
    end
    return img
end

function compute_juliaset_spawn!(img)
    N, _ = size(img)
    @sync for j in 1:N
        @spawn begin
            for i in 1:N
                @inbounds img[i, j] = _compute_pixel(i, j, N)
            end
        end
    end
    return img
end


# Benchmark
funcs = (compute_juliaset_serial!, compute_juliaset_spawn!, compute_juliaset_threads_dynamic!, compute_juliaset_threads_static!)
names = ("serial", "spawn", "threads :dynamic", "threads :static")

N = 8000
img = zeros(Int, N, N)

println("\n\n correctness check")
for (func, n) in zip(funcs, names)
    println("\t $n")
    res = func(copy(img)) ≈ compute_juliaset_serial!(copy(img))
    println("\t\t $res")
end

println("\n benchmark")
for (func, n) in zip(funcs, names)
    println("\t $n")
    @btime $func($(copy(img))) samples = 5 evals = 3
end
flush(stdout)
