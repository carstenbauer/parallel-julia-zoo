Basic MPI implementation of [Cannon's algorithm](https://en.wikipedia.org/wiki/Cannon%27s_algorithm) (see also [here](https://users.cs.utah.edu/~hari/teaching/paralg/tutorial/05_Cannons.html)) for distributed matrix-matrix multiplication.

(While hopefully instructive, the given implementation is not optimized for performance and much slower than a simple BLAS call for the considered matrix size.)