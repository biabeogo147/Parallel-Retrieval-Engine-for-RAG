#!/bin/sh

set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
bash "$script_dir/common.sh"

if [ "$(uname -s)" != "Linux" ]; then
    echo "Run this script inside the Ubuntu WSL environment." >&2
    exit 1
fi

sudo apt update
sudo apt install -y \
    build-essential \
    cmake \
    ninja-build \
    pkg-config \
    openmpi-bin \
    libopenmpi-dev \
    gdb \
    valgrind \
    python3 \
    python3-pip \
    python3-venv

for tool in mpicxx mpirun cmake ninja; do
    require_command "$tool"
done

mpicxx --version
mpirun --version
cmake --version
ninja --version
