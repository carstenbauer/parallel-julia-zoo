using MPI

function diffusion_1d(; n=10_000, nsteps=100_000)
    comm = MPI.COMM_WORLD
    rank = MPI.Comm_rank(comm)
    nranks = MPI.Comm_size(comm)

    # n regular cells (indices: 2:n+1)
    # 2 "ghost cells"/"halo cells" (indices: 1 and n+2)
    rho = rand(n + 2)
    rhoPrev = rand(n + 2)
    α = 3.141

    # periodic boundary conditions
    left_rank = mod(rank - 1, nranks)
    right_rank = mod(rank + 1, nranks)

    for step in 1:nsteps
        # blocking communication
        if rank % 2 == 0
            MPI.Send(@view(rhoPrev[n+1]), comm; dest=right_rank)
            MPI.Recv!(@view(rhoPrev[1]), comm; source=left_rank)
            MPI.Send(@view(rhoPrev[2]), comm; dest=left_rank)
            MPI.Recv!(@view(rhoPrev[n+2]), comm; source=right_rank)
        else
            MPI.Recv!(@view(rhoPrev[1]), comm; source=left_rank)
            MPI.Send(@view(rhoPrev[n+1]), comm; dest=right_rank)
            MPI.Recv!(@view(rhoPrev[n+2]), comm; source=right_rank)
            MPI.Send(@view(rhoPrev[2]), comm; dest=left_rank)
        end

        # computation
        for i in 2:n+1 # for each regular cell
            rho[i] = rhoPrev[i] + α * (rhoPrev[i-1] - 2 * rhoPrev[i] + rhoPrev[i+1])
            rho, rhoPrev = rhoPrev, rho
        end

        if rank == 0 && (step % 10_000 == 0)
            println("Step ", step)
        end
    end
end

function main()
    MPI.Init()
    rank = MPI.Comm_rank(MPI.COMM_WORLD)

    Δt = -MPI.Wtime()
    diffusion_1d()
    Δt += MPI.Wtime()

    if rank == 0
        println("total time: ", round(Δt; sigdigits=3), " sec")
    end

    MPI.Finalize()
end

main()
