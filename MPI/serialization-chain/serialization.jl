using MPI

function main()
    MPI.Init()

    comm = MPI.COMM_WORLD
    rank = MPI.Comm_rank(comm)
    nranks = MPI.Comm_size(comm)

    # chain topology, i.e. "open" boundary conditions
    left  = rank - 1
    right = rank + 1
    if left < 0
        left = MPI.PROC_NULL
    elseif right >= nranks
        right = MPI.PROC_NULL
    end

    N = 2^22
    buf = rand(N)

    for r in 0:nranks-1
        MPI.Barrier(comm)
        if r == rank
            rightstr = right == MPI.PROC_NULL ? "no one" : right
            leftstr = left == MPI.PROC_NULL ? "no one" : left
            println("Rank $r will send to $rightstr and receive from $leftstr soon.")
        end
    end

    # this communication will happen in serial
    MPI.Send(buf, comm; dest=right)
    MPI.Recv!(buf, comm; source=left)

    # Due to serialization, ranks will reach this point in a deterministic order.
    # The last rank will reach this point first, then the second to last rank, and so on.
    println("Rank $rank has finished Recv!/Send.")

    # To demonstrate this further: timeline (as obtained with MPITape.jl)
    # 7: Send -> 8           (Δt=5.54E+01)
    # 8: Send -> 9           (Δt=5.55E+01)
    # 2: Send -> 3           (Δt=5.55E+01)
    # 5: Send -> 6           (Δt=5.55E+01)
    # 1: Send -> 2           (Δt=5.55E+01)
    # 6: Send -> 7           (Δt=5.55E+01)
    # 3: Send -> 4           (Δt=5.55E+01)
    # 4: Send -> 5           (Δt=5.55E+01)
    # 0: Send -> 1           (Δt=5.55E+01)
    # 9: Send -> -1          (Δt=5.70E+01)
    # 9: Recv <- 8           (Δt=5.71E+01)
    # 8: Recv <- 7           (Δt=5.73E+01)
    # 7: Recv <- 6           (Δt=5.74E+01)
    # 6: Recv <- 5           (Δt=5.76E+01)
    # 5: Recv <- 4           (Δt=5.77E+01)
    # 4: Recv <- 3           (Δt=5.79E+01)
    # 3: Recv <- 2           (Δt=5.80E+01)
    # 2: Recv <- 1           (Δt=5.82E+01)
    # 1: Recv <- 0           (Δt=5.83E+01)
    # 0: Recv <- -1          (Δt=5.85E+01)

    MPI.Finalize()
end

main()
