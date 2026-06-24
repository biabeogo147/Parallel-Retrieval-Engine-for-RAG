#!/bin/sh

set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$script_dir/common.sh"

build_dir=${1:-"$repo_root/build/debug"}
mpi_procs=${MPI_PROCS:-4}

require_command cmake
require_command ctest
require_command mpirun

cmake --build "$build_dir"
ctest --test-dir "$build_dir" --output-on-failure
"$build_dir/sequential_retriever" --help >/dev/null
"$build_dir/verify_results" --help >/dev/null

if [ "$(id -u)" -eq 0 ]; then
    OMPI_ALLOW_RUN_AS_ROOT=1 \
    OMPI_ALLOW_RUN_AS_ROOT_CONFIRM=1 \
    mpirun -np "$mpi_procs" "$build_dir/parallel_retriever" --help >/dev/null
else
    mpirun -np "$mpi_procs" "$build_dir/parallel_retriever" --help >/dev/null
fi

echo "Repository smoke tests completed."
