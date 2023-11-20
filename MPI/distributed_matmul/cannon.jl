using MPI
using Printf
using LinearAlgebra

function scatter_matrix_blocks(X, n, cartcomm)
    rank = MPI.Comm_rank(cartcomm)
    X_local = Matrix{Float64}(undef, n, n)

    if rank == 0
        # master sends blocks to all other ranks
        for r in 1:MPI.Comm_size(cartcomm)-1
            rx, ry = MPI.Cart_coords(cartcomm, r)
            rows = n*ry+1:n*(ry+1)
            cols = n*rx+1:n*(rx+1)
            MPI.Isend(@view(X[rows, cols]), cartcomm; dest=r, tag=0)
        end
        # master gets its own block
        X_local .= @view(X[1:n, 1:n])
    else
        # non-master ranks just receive their blocks
        MPI.Recv!(X_local, cartcomm; source=0, tag=0)
    end
    MPI.Barrier(cartcomm)
    return X_local
end

function gather_matrix_blocks(X_local, n, cartcomm)
    rank = MPI.Comm_rank(cartcomm)
    p = Int(sqrt(MPI.Comm_size(cartcomm)))
    N = n * p

    if rank == 0
        X = Matrix{Float64}(undef, N, N)
        # master receives blocks from all other ranks
        for r in 1:MPI.Comm_size(cartcomm)-1
            rx, ry = MPI.Cart_coords(cartcomm, r)
            rows = n*ry+1:n*(ry+1)
            cols = n*rx+1:n*(rx+1)
            MPI.Recv!(@view(X[rows, cols]), cartcomm; source=r)
        end
        # master copies over its own block
        X[1:n, 1:n] .= X_local
    else
        # non-master ranks just receive their blocks
        MPI.Send(X_local, cartcomm; dest=0)
        X = nothing
    end
    MPI.Barrier(cartcomm)
    return X
end

function cannon_matmul!(C_local, A_local, B_local, A_tmp, B_tmp, cartcomm)
    p = Int(sqrt(MPI.Comm_size(cartcomm)))

    # coordinates in cartesian grid
    rank = MPI.Comm_rank(cartcomm)
    rankx, ranky = MPI.Cart_coords(cartcomm, rank)

    # determine (immediate) neighboring ranks
    left, right = MPI.Cart_shift(cartcomm, 0, 1)
    up, down = MPI.Cart_shift(cartcomm, 1, 1)

    # initial shift
    left_dst, right_src = MPI.Cart_shift(cartcomm, 0, ranky)
    up_dst, down_src = MPI.Cart_shift(cartcomm, 1, rankx)

    # send + receive
    requests = MPI.MultiRequest(2)
    MPI.Irecv!(A_tmp, cartcomm, requests[1]; source=right_src, tag=0)
    MPI.Irecv!(B_tmp, cartcomm, requests[2]; source=down_src, tag=1)
    MPI.Send(A_local, cartcomm; dest=left_dst, tag=0)
    MPI.Send(B_local, cartcomm; dest=up_dst, tag=1)
    MPI.Waitall(requests)

    # exchange
    A_tmp, A_local = A_local, A_tmp
    B_tmp, B_local = B_local, B_tmp

    for step in 0:p-1
        # local matrix multiply
        mul!(C_local, A_local, B_local, 1.0, 1.0)

        # send + receive
        MPI.Irecv!(A_tmp, cartcomm, requests[1]; source=right, tag=0)
        MPI.Irecv!(B_tmp, cartcomm, requests[2]; source=down, tag=1)
        MPI.Send(A_local, cartcomm; dest=left, tag=0)
        MPI.Send(B_local, cartcomm; dest=up, tag=1)
        MPI.Waitall(requests)

        # exchange
        A_tmp, A_local = A_local, A_tmp
        B_tmp, B_local = B_local, B_tmp
    end
end

function main()
    MPI.Init()
    rank = MPI.Comm_rank(MPI.COMM_WORLD)
    nranks = MPI.Comm_size(MPI.COMM_WORLD)
    p = sqrt(nranks)
    nranks == p * p || error("Number of processors must be a square integer.")

    # generate random input matrices
    N = 1024
    if rank == 0
        A = rand(N, N) # full A
        B = rand(N, N) # full B
        C = A * B      # result (for later comparison)
    else
        A = nothing
        B = nothing
        C = nothing
    end

    # create p x p cartesian grid
    cartcomm = MPI.Cart_create(MPI.COMM_WORLD, (p, p); periodic=(true, true), reorder=true)

    # determine local matrix size
    n = Int(N ÷ p)

    # distribute input matrices
    rank == 0 && println("Distributing input matrices...")
    A_local = scatter_matrix_blocks(A, n, cartcomm)
    B_local = scatter_matrix_blocks(B, n, cartcomm)
    C_local = zeros(n, n)

    # extra receive buffers
    A_tmp = zeros(n, n)
    B_tmp = zeros(n, n)

    # run cannon algorithm + timing
    rank == 0 && println("Running Matrix-Matrix Multiplication...")
    MPI.Barrier(cartcomm)
    Δt = -MPI.Wtime()
    cannon_matmul!(C_local, A_local, B_local, A_tmp, B_tmp, cartcomm)
    MPI.Barrier(cartcomm)
    Δt += MPI.Wtime()

    # verify and print results
    C_cannon = gather_matrix_blocks(C_local, n, cartcomm)
    if rank == 0
        if !(C_cannon ≈ C)
            println("ERROR: Verification FAILED!")
            # display(C_cannon)
            # display(C)
        else
            println("Verification PASSED!")
        end

        gigaflops = (((2e-9) * N) * N) * N / Δt
        @printf("Execution time: %.3fs \n", Δt)
        @printf("GFLOPs: %.4f \n", gigaflops)
    end

    MPI.Finalize()
end

main()
