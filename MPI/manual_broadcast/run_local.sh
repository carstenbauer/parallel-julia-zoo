mpiexecjl --project -n 8 julia bcast_builtin.jl
mpiexecjl --project -n 8 julia bcast_tree.jl
mpiexecjl --project -n 8 julia bcast_sequential.jl