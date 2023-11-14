using MPI
using Printf

function main()
    MPI.Init()
    comm = MPI.COMM_WORLD
    rank = MPI.Comm_rank(comm)

    if rank == 0
        message = rand(2048)
        MPI.Send(message, comm; dest=1)
    elseif rank == 1
        # this rank doesn't know the message size (2048)
        status = MPI.Probe(comm, MPI.Status; source=0)
        size = MPI.Get_count(status, Float64)
        message = rand(size)
        MPI.Recv!(message, comm; source=0)
        @printf("Rank %d received %d Float64s\n", rank, size);
    end

    MPI.Finalize()
end

main()
