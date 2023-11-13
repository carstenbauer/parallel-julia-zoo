#!/usr/bin/env bash
#SBATCH --ntasks=32
#SBATCH --nodes=32
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=1
#SBATCH --account=pc2-mitarbeiter
#SBATCH --time=00:10:00
#SBATCH --error=sl_%j.errFile
#SBATCH --output=sl_%j.outFile
#SBATCH --job-name=Bcast
#SBATCH --partition=all
#SBATCH --exclusive

ml r
ml lang JuliaHPC

srun julia --project ../bcast_builtin.jl
srun julia --project ../bcast_tree.jl
srun julia --project ../bcast_sequential.jl