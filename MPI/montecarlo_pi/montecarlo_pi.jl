using MPI

function pi_serial(N)
    M = 0
    for i in 1:N
        if rand()^2 + rand()^2 < 1.0
            M += 1
        end
    end
    return 4 * M / N
end

function main(; nbench=100)
    MPI.Init()
    comm = MPI.COMM_WORLD
    rank = MPI.Comm_rank(comm)
    nranks = MPI.Comm_size(comm)

    N = 10_000_000
    if !isempty(ARGS)
        N = parse(Int, ARGS[1])
    end
    N_local = ceil(Int, N / nranks)

    times = zeros(nbench)
    for i in 1:nbench
        MPI.Barrier(comm)
        times[i] = MPI.Wtime()
        local_pi = pi_serial(N_local)
        pi_approx = MPI.Reduce(local_pi, +, 0, comm)
        if rank == 0
            pi_approx /= nranks
        end
        MPI.Barrier(comm)
        times[i] = MPI.Wtime() - times[i]

        if rank == 0
            println("(Iteration $i) π estimate: ", pi_approx)
        end
    end

    if rank == 0
        println("Minimum Δt (ms) = ", minimum(times) * 1e3)
    end

    MPI.Finalize()
end

main()
