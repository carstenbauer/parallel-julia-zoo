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

    function diffusion_stencil!(rho, rhoPrev, α, i)
        rho[i] = rhoPrev[i] + α * (rhoPrev[i-1] - 2 * rhoPrev[i] + rhoPrev[i+1])
    end

    for step in 1:nsteps
        # non-blocking communication
        reqs = MPI.MultiRequest(4)
        MPI.Irecv!(@view(rhoPrev[1]), comm, reqs[1]; source=left_rank)
        MPI.Irecv!(@view(rhoPrev[n+2]), comm, reqs[2]; source=right_rank)
        MPI.Isend(@view(rhoPrev[2]), comm, reqs[3]; dest=left_rank)
        MPI.Isend(@view(rhoPrev[n+1]), comm, reqs[4]; dest=right_rank)

        # computation
        for i in 3:n # for each "inner cell" (i.e. those that don't depend on ghost cells)
            diffusion_stencil!(rho, rhoPrev, α, i)
        end

        MPI.Waitall(reqs) # blocking

        # apply stencil for remaining boundary cells
        diffusion_stencil!(rho, rhoPrev, α, 2)
        diffusion_stencil!(rho, rhoPrev, α, n + 1)

        rho, rhoPrev = rhoPrev, rho

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
