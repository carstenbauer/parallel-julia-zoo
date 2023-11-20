# based on https://gitlab.ethz.ch/hpcse-public-repos/hpcsei-fall-2022-lecture/-/blob/main/
#          tutorials/tutorial09_MPI-III/solution_code/main.cpp
using MPI
using Plots
using Printf

struct Buffers
    ffx::Vector{Float64}
    ffy::Vector{Float64}
    xsa::Vector{Float64}
    ysa::Vector{Float64}
    xsb::Vector{Float64}
    ysb::Vector{Float64}

    Buffers(n) = new(zeros(n), zeros(n), zeros(n), zeros(n), zeros(n), zeros(n))
end

"""
Computes the forces and advances the particles with time step `Δt`
"""
function step!(xs, ys, Δt; buffers::Buffers)
    n = length(xs)
    (; ffx, ffy, xsa, ysa, xsb, ysb) = buffers
    comm = MPI.COMM_WORLD
    rank = MPI.Comm_rank(comm)
    nranks = MPI.Comm_size(comm)

    # prepare buffers
    fill!(ffx, 0.0)
    fill!(ffy, 0.0)
    copy!(xsa, xs)
    copy!(ysa, ys)

    rm = (rank + nranks - 1) % nranks
    rp = (rank + 1) % nranks

    for k in 1:nranks
        reqs = MPI.MultiRequest(4)
        if k != nranks
            MPI.Irecv!(xsb, comm, reqs[1]; source=rm)
            MPI.Irecv!(ysb, comm, reqs[2]; source=rm)
            MPI.Isend(xsa, comm, reqs[3]; dest=rp)
            MPI.Isend(ysa, comm, reqs[4]; dest=rp)
        end

        for i in eachindex(xs)
            for j in eachindex(xs)
                dx = xs[i] - xsa[j]
                dy = ys[i] - ysa[j]
                r = (dx^2 + dy^2 + 1e-20)^(-1.5)
                ffx[i] += dx * r
                ffy[i] += dy * r
            end
        end

        if k != nranks
            MPI.Waitall(reqs)
            xsa, xsb = xsb, xsa
            ysa, ysb = ysb, ysa
        end
    end

    # advance particles
    for i in eachindex(xs)
        xs[i] += Δt * ffx[i]
        ys[i] += Δt * ffy[i]
    end
    return nothing
end

# Prints the mean and variance of the radial distance over all particles.
function print_stats(xs, ys)
    rank = MPI.Comm_rank(MPI.COMM_WORLD)
    mean = 0.0
    var = 0.0
    n = length(xs)
    for i in eachindex(xs)
        r = sqrt(xs[i]^2 + ys[i]^2)
        mean += r
        var += r^2
    end
    n = MPI.Reduce(n, MPI.SUM, MPI.COMM_WORLD)
    mean = MPI.Reduce(mean, MPI.SUM, MPI.COMM_WORLD)
    var = MPI.Reduce(var, MPI.SUM, MPI.COMM_WORLD)

    # Print on root only
    if rank == 0
        mean /= n
        var /= n
        var = var - mean^2
        @printf("mean=%-12.5g var=%.5g\n", mean, var)
    end
end

function gather_all_positions(xs, ys)
    n = length(xs)
    comm = MPI.COMM_WORLD
    rank = MPI.Comm_rank(comm)
    nranks = MPI.Comm_size(comm)

    if rank == 0
        na = nranks * n
        xsa = zeros(na)
        ysa = zeros(na)
        MPI.Gather!(xs, xsa, comm)
        MPI.Gather!(ys, ysa, comm)
        return xsa, ysa
    else
        MPI.Gather!(xs, nothing, comm)
        MPI.Gather!(ys, nothing, comm)
        return nothing, nothing
    end
end

function save_plot(xs_init, ys_init, xs_final, ys_final, filename)
    opts = (ms=4, marker=:circle, xlims=(-2, 2), ylims=(-2, 2), frame=:box, grid=false)
    p = scatter(xs_init, ys_init; label="initial", color="#785ef0", opts...)
    scatter!(p, xs_final, ys_final; label="final", color="#dc267f", opts...)
    savefig(p, filename)
    return
end

function main()
    MPI.Init()

    rank = MPI.Comm_rank(MPI.COMM_WORLD)
    nranks = MPI.Comm_size(MPI.COMM_WORLD)

    N = 60                 # total number of particles
    NL = Int(N ÷ nranks)   # particles per rank
    Δt = 0.1 / N           # time step

    @assert(N % nranks == 0)

    # Seed particles on a unit circle.
    xs = Float64[]
    ys = Float64[]
    for i in (rank*NL):((rank+1)*NL-1)
        a = i / N * 2.0 * π
        push!(xs, cos(a))
        push!(ys, sin(a))
    end

    buf = Buffers(NL)
    print_stats(xs, ys)
    xs_init, ys_init = gather_all_positions(xs, ys)

    # Time steps
    for t in 1:10
        step!(xs, ys, Δt; buffers=buf)
        print_stats(xs, ys)
    end

    xs_final, ys_final = gather_all_positions(xs, ys)
    rank == 0 && save_plot(xs_init, ys_init, xs_final, ys_final, "plot.pdf")

    MPI.Finalize()
end

main()
