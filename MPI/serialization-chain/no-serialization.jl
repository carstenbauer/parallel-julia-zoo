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

    # non-blocking communication
    req1 = MPI.Isend(buf, comm; dest=right)
    req2 = MPI.Irecv!(buf, comm; source=left)
    MPI.Waitall([req1, req2])

    # The order in which the ranks will reach this point isn't deterministic.
    println("Rank $rank has finished Recv!/Send.")

    # To demonstrate this further: timeline (as obtained with MPITape.jl)
    # 5: Isend -> 6          (Δt=5.78E+01)
    # 4: Isend -> 5          (Δt=5.78E+01)
    # 0: Isend -> 1          (Δt=5.78E+01)
    # 6: Isend -> 7          (Δt=5.78E+01)
    # 8: Isend -> 9          (Δt=5.79E+01)
    # 2: Isend -> 3          (Δt=5.79E+01)
    # 3: Isend -> 4          (Δt=5.79E+01)
    # 1: Isend -> 2          (Δt=5.79E+01)
    # 7: Isend -> 8          (Δt=5.79E+01)
    # 5: Irecv <- 4          (Δt=5.79E+01)
    # 4: Irecv <- 3          (Δt=5.79E+01)
    # 0: Irecv <- -1         (Δt=5.79E+01)
    # 6: Irecv <- 5          (Δt=5.79E+01)
    # 8: Irecv <- 7          (Δt=5.80E+01)
    # 2: Irecv <- 1          (Δt=5.80E+01)
    # 3: Irecv <- 2          (Δt=5.80E+01)
    # 1: Irecv <- 0          (Δt=5.80E+01)
    # 7: Irecv <- 6          (Δt=5.80E+01)
    # 5: Waitall             (Δt=5.83E+01)
    # 4: Waitall             (Δt=5.83E+01)
    # 6: Waitall             (Δt=5.83E+01)
    # 0: Waitall             (Δt=5.83E+01)
    # 8: Waitall             (Δt=5.83E+01)
    # 2: Waitall             (Δt=5.83E+01)
    # 3: Waitall             (Δt=5.83E+01)
    # 1: Waitall             (Δt=5.83E+01)
    # 7: Waitall             (Δt=5.83E+01)
    # 9: Isend -> -1         (Δt=5.95E+01)
    # 9: Irecv <- 8          (Δt=5.96E+01)
    # 9: Waitall             (Δt=5.99E+01)

    MPI.Finalize()
end

main()
