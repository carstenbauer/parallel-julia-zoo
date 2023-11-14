# Original C++ source:
# https://gitlab.ethz.ch/hpcse-public-repos/hpcsei-fall-2022-lecture/-/blob/main/tutorials/
# tutorial07_MPI/solution-code/poisson.cpp?ref_type=heads
using MPI

# Poisson equation: d^2u/dx^2 = f(x) in [0,L] with zero boundary conditions.
struct Poisson
    L::Float64              # domain size in x-direction
    N::Int                  # grid points in x-direction
    Δx::Float64             # grid spacing in x-direction
    u_old::Vector{Float64}  # solution vector at iteration n-1
    u::Vector{Float64}      # solution vector at iteration n
    f::Vector{Float64}      # right hand side vector f(x,y)

    comm::MPI.Comm
    rank::Int
    size::Int
    istart::Int
    iend::Int
    myN::Int
    u_left::Base.RefValue{Float64}  # RefValue because we want to send/receive it via MPI
    u_right::Base.RefValue{Float64} # RefValue because we want to send/receive it via MPI

    # constructor
    function Poisson(L, N)
        comm = MPI.COMM_WORLD
        rank = MPI.Comm_rank(comm)
        size = MPI.Comm_size(comm)

        myN = N ÷ size
        Δx = L / (N - 1)

        istart = rank * myN # starts at zero!
        iend = (rank + 1) * myN # starts at zero!

        u = Vector{Float64}(undef, myN)
        u_old = Vector{Float64}(undef, myN)
        f = Vector{Float64}(undef, myN)

        for i in istart:iend-1
            iloc = i - istart + 1
            u[iloc] = 0.0
            u_old[iloc] = 0.0
            x = i * Δx
            r2 = (x - 0.5 * L) * (x - 0.5 * L)
            f[iloc] = exp(-r2)
        end

        u_left = Ref(0.0)
        u_right = Ref(0.0)

        return new(L, N, Δx, u_old, u, f, comm, rank, size, istart, iend, myN, u_left, u_right)
    end
end

function JacobiStep(p::Poisson)
    (; N, rank, size, u, u_old, f, Δx, istart, iend, comm, myN, u_left, u_right) = p
    error = 0
    left_rank = rank - 1
    right_rank = rank + 1

    if left_rank < 0
        u_left[] = 0
        left_rank = MPI.PROC_NULL
    end
    if right_rank >= size
        u_right[] = 0
        right_rank = MPI.PROC_NULL
    end

    # non-blocking solution
    requests = MPI.MultiRequest(4)
    MPI.Irecv!(u_left, comm, requests[1]; source=left_rank)
    MPI.Irecv!(u_right, comm, requests[2]; source=right_rank)
    MPI.Isend(@view(u_old[1]), comm, requests[3]; dest=left_rank)
    MPI.Isend(@view(u_old[myN]), comm, requests[4]; dest=right_rank)

    # blocking solution
    # MPI.Sendrecv!(@view(u_old[1]), u_left, comm; dest=left_rank, source=left_rank)
    # MPI.Sendrecv!(@view(u_old[myN]), u_right, comm; dest=right_rank, source=right_rank)

    for i in istart+1:iend-2
        iloc = i - istart + 1
        u[iloc] = 0.5 * (u_old[iloc+1] + u_old[iloc-1]) - 0.5 * Δx^2 * f[iloc]
        error += abs(u[iloc] - u_old[iloc])
    end

    # non-blocking solution: we can wait for commmunication to complete here,
    # after the inner points are computed.
    # This is faster than waiting for communication (in the blocking solution)
    # and then computing all the points.
    MPI.Waitall(requests)

    if istart != 1
        i = istart
        iloc = i - istart + 1
        u[iloc] = 0.5 * (u_old[iloc+1] + u_left[]) - 0.5 * Δx * Δx * f[iloc]
        error += abs(u[iloc] - u_old[iloc])
    end
    if iend - 1 != N - 1
        i = iend - 1
        iloc = i - istart + 1
        u[iloc] = 0.5 * (u_right[] + u_old[iloc-1]) - 0.5 * Δx * Δx * f[iloc]
        error += abs(u[iloc] - u_old[iloc])
    end
    swap!(p.u_old, p.u)
    error *= Δx
    err_ref = Ref(error)
    MPI.Allreduce!(MPI.IN_PLACE, err_ref, MPI.SUM, comm)
    return err_ref[]
end

function swap!(a, b)
    @inbounds for i in eachindex(a, b)
        tmp = a[i]
        a[i] = b[i]
        b[i] = tmp
    end
    return nothing
end

function solve(p::Poisson)
    ϵ = 1e-8 # tolerance for Jacobi iterations
    for m in 1:10_000_000
        curr_err = JacobiStep(p)
        if m % 10_000 == 0 && p.rank == 0
            println("Iteration: ", m, " error: ", curr_err)
        end
        if curr_err < ϵ
            if p.rank == 0
                println("Converged at iteration ", m, " with error: ", curr_err)
            end
            break
        end
    end
end

function main()
    MPI.Init()
    # for good measure, we pin the MPI ranks
    rank = MPI.Comm_rank(MPI.COMM_WORLD)
    L = 1.0
    N = 4096

    Δt = -MPI.Wtime()
    poisson = Poisson(L, N)
    solve(poisson)
    Δt += MPI.Wtime()

    if rank == 0
        println("total time:", Δt)
    end

    MPI.Finalize()
end

main()
