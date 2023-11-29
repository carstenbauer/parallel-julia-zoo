using MPI

function main()
    MPI.Init()

    comm = MPI.COMM_WORLD
    rank = MPI.Comm_rank(comm)
    nranks = MPI.Comm_size(comm)

    # ring topology, i.e. periodic boundary conditions
    left  = mod(rank - 1, nranks)
    right = mod(rank + 1, nranks)

    N = 2^22
    buf = rand(N)

    for r in 0:nranks-1
        MPI.Barrier(comm)
        if r == rank
            println("Rank $r will start Recv!/Send soon.")
        end
    end

    # deadlock!
    MPI.Recv!(buf, comm; source=left)
    MPI.Send(buf, comm; dest=right)

    # the following will never be reached
    for r in 0:nranks-1
        MPI.Barrier(comm)
        if r == rank
            println("Rank $r has finished Recv!/Send.")
        end
    end

    MPI.Finalize()
end

main()
