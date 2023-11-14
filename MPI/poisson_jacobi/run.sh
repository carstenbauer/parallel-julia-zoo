echo -e "Blocking communication"
mpiexecjl --project -n 10 julia poisson.jl

echo -e "\n\nNon-blocking communication (overlapping with computation)"
mpiexecjl --project -n 10 julia poisson_hidecomm.jl
