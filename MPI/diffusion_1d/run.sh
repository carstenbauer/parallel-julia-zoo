echo -e "Blocking communication"
mpiexecjl --project -n 10 julia diffusion_1d_naive.jl

echo -e "\n\nNon-blocking communication (overlapping with computation)"
mpiexecjl --project -n 10 julia diffusion_1d_hidecomm.jl
