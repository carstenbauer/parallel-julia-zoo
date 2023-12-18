using Distributed

@everywhere begin
    using Random

    function diffusion_1d(; n=1_000, nsteps=100_000, rcs)
        nw = nworkers()
        ws = sort!(workers())
        w = findfirst(==(myid()), ws)
        @assert !isnothing(w)

        # n regular cells (indices: 2:n+1)
        # 2 "ghost cells"/"halo cells" (indices: 1 and n+2)
        Random.seed!(42)
        f = rand(n + 2)
        f_prev = rand(n + 2)
        c = 0.001 # DΔt/h²

        # periodic boundary conditions
        left = ws[mod1(w - 1, nw)]
        right = ws[mod1(w + 1, nw)]
        chs_right = rcs[right]
        chs_left = rcs[left]
        mychs = rcs[myid()]

        function diffusion_stencil!(f, f_prev, c, i)
            f[i] = f_prev[i] + c * (f_prev[i-1] - 2 * f_prev[i] + f_prev[i+1])
        end

        for step in 1:nsteps
            if iseven(w)
                @time begin
                    put!(chs_right[1], f_prev[n+1])
                    f_prev[1] = take!(mychs[1])
                    put!(chs_left[2], f_prev[2])
                    f_prev[n+2] = take!(mychs[2])
                end
            else
                f_prev[1] = take!(mychs[1])
                put!(chs_right[1], f_prev[n+1])
                f_prev[n+2] = take!(mychs[2])
                put!(chs_left[2], f_prev[2])
            end

            # stencil computation
            for i in 2:n+1 # for each regular cell
                diffusion_stencil!(f, f_prev, c, i)
            end

            f, f_prev = f_prev, f

            if w == 1 && (step % 10_000 == 0)
                println("Step ", step)
            end
        end
        return f_prev
    end
end

function main()
    nw = nworkers()
    ws = sort!(workers())

    # each worker gets two channels for communication
    #  - "left" channel is for receiving from the left neighbor
    #  - "right" channel is for receiving from the right neighbor
    chs1 = [RemoteChannel(() -> Channel{Float64}(1), pid) for pid in ws]
    chs2 = [RemoteChannel(() -> Channel{Float64}(1), pid) for pid in ws]
    rcs = Dict(ws .=> zip(chs1, chs2))

    t = @elapsed begin
        tasks = map(1:nw) do i
            @spawnat ws[i] diffusion_1d(; rcs)
        end
        f_sum = sum(fetch, tasks)
    end
    println("total time: ", round(t; sigdigits=3), " sec")
    println("checksum: ", sum(f_sum))
end

main()
