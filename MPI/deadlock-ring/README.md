Deadlock can be detected with [MUST](https://www.i12.rwth-aachen.de/cms/Lehrstuhl-fuer-Informatik/Forschung/Forschungsschwerpunkte/Lehrstuhl-fuer-Hochleistungsrechnen/~nrbe/MUST/):

```
➜  bauerc@n2login3 deadlock-ring git:(main)
$ mustrun -n 4 run.sh
[MUST] MUST configuration ... centralized checks with fall-back application crash handling (very slow)
[MUST] Using prebuilt infrastructure at /pc2/users/b/bauerc/.cache/must/prebuilds/864f3a9f01045835e9b69e097a4
83388
[MUST] Weaver ... success
[MUST] Generating P^nMPI configuration ... success
[MUST] Infrastructure in "/pc2/users/b/bauerc/.cache/must/prebuilds/864f3a9f01045835e9b69e097a483388" is pres
ent and used.
[MUST] Search for linked P^nMPI ... not found ... using LD_PRELOAD to load P^nMPI ... success
[MUST] Executing application:
┌ Warning: MPI thread level requested = MPI.ThreadLevel(2), provided = MPI.ThreadLevel(1)
└ @ MPI /scratch/hpc-lco-usrtr/.julia_jlhpc_course/packages/MPI/hhI6i/src/environment.jl:129
┌ Warning: MPI thread level requested = MPI.ThreadLevel(2), provided = MPI.ThreadLevel(1)
└ @ MPI /scratch/hpc-lco-usrtr/.julia_jlhpc_course/packages/MPI/hhI6i/src/environment.jl:129
┌ Warning: MPI thread level requested = MPI.ThreadLevel(2), provided = MPI.ThreadLevel(1)
└ @ MPI /scratch/hpc-lco-usrtr/.julia_jlhpc_course/packages/MPI/hhI6i/src/environment.jl:129
┌ Warning: MPI thread level requested = MPI.ThreadLevel(2), provided = MPI.ThreadLevel(1)
└ @ MPI /scratch/hpc-lco-usrtr/.julia_jlhpc_course/packages/MPI/hhI6i/src/environment.jl:129
Rank 0 will start Recv!/Send soon.
Rank 1 will start Recv!/Send soon.
Rank 2 will start Recv!/Send soon.
Rank 3 will start Recv!/Send soon.
[MUST-RUNTIME] ============MUST===============
[MUST-RUNTIME] ERROR: MUST detected a deadlock, detailed information is available in the MUST output file. Yo
u should either investigate details with a debugger or abort, the operation of MUST will stop from now.
[MUST-RUNTIME] ===============================
```
