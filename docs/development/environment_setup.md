# Environment Setup

## Chosen Development Environment

The project will target:

- WSL2
- Ubuntu LTS inside WSL2
- OpenMPI
- CMake
- Ninja
- GCC or Clang through `mpicxx`

This replaces native Windows MPI as the primary path.

## Why WSL2 and OpenMPI

1. The Linux MPI toolchain is easier to install and document.
2. Most parallel-computing examples and debugging workflows assume Linux.
3. CMake plus OpenMPI is simpler than maintaining Windows-only MPI setup notes.
4. The benchmark scripts will be easier to reproduce in reports and demos.

## Recommended Layout

### Preferred

Keep the active build and run environment inside the WSL filesystem, for example:

```text
~/work/Parallel-Retrieval-Engine-for-RAG
```

### Acceptable Fallback

Use the existing Windows workspace through the mounted path:

```text
/mnt/d/DS-AI/Parallel-Retrieval-Engine-for-RAG
```

The fallback is fine for this project, but native WSL storage usually performs better for builds and heavy filesystem operations.

## Required Packages

Run inside WSL:

```bash
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
```

## Verification Commands

After installation, confirm the toolchain:

```bash
mpicxx --version
mpirun --version
cmake --version
ninja --version
```

Expected result:

1. `mpicxx` resolves successfully.
2. `mpirun` reports an OpenMPI version.
3. `cmake` and `ninja` are available on `PATH`.

## Dataset Mounts

The benchmark data already exists on the Windows host at:

```text
E:\data
```

From WSL, use:

```text
/mnt/e/data
```

Recommended dataset references for the first project wave:

- `/mnt/e/data/ms_marco`
- `/mnt/e/data/squad`
- `/mnt/e/data/UIT-ViQuAD2.0`

## Future Build Commands

These commands are not part of Phase 0 execution yet, but they define the expected build shape:

```bash
cmake -S . -B build -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_CXX_COMPILER=mpicxx

cmake --build build
```

## Expected Run Shape

Once Phase 1 is complete, the minimum acceptance check should look like:

```bash
mpirun -np 4 ./build/parallel_retriever --help
```

## IDE Guidance

If you use CLion or VS Code:

1. Point the toolchain to WSL, not native Windows.
2. Build with the WSL compiler and MPI runtime.
3. Keep launch configurations using `mpirun`.

## Phase 0 Environment Exit Criteria

The environment decision is considered locked when:

1. WSL2 is the documented primary runtime.
2. OpenMPI is the documented MPI stack.
3. `/mnt/e/data` is documented as the benchmark dataset root.
4. The team no longer plans around native Windows `mpiexec` as the default.
