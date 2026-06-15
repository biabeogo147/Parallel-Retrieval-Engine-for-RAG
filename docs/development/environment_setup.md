# Environment Setup

## Canonical Development Environment

This repository standardizes on:

- WSL2
- Ubuntu 24.04 LTS
- OpenMPI
- CMake
- Ninja
- `mpicxx` as the C++ compiler entrypoint

This project no longer treats native Windows MPI as the primary workflow.

## Step 0: Install Ubuntu on Windows

Run this in PowerShell on the Windows host:

```powershell
wsl --install -d Ubuntu-24.04
```

If Windows requests a reboot, restart first and then complete the Ubuntu initial user setup.

Useful checks on the Windows side:

```powershell
wsl --status
wsl -l -v
```

Expected result:

1. Default WSL version is `2`.
2. `Ubuntu-24.04` appears as an installed distro.
3. The distro has completed first-run setup with a normal Linux user, not only the temporary `root` shell.

## Step 1: Use the Canonical WSL Repo Location

Preferred working tree:

```text
~/work/Parallel-Retrieval-Engine-for-RAG
```

Fallback path if you temporarily work from the Windows mount:

```text
/mnt/d/DS-AI/Parallel-Retrieval-Engine-for-RAG
```

Phase 1 docs and scripts assume the preferred WSL-native path.

## Step 2: Install the Toolchain Inside Ubuntu

From the repository root in WSL:

```bash
./scripts/setup_wsl_dev_env.sh
```

That script installs:

- `build-essential`
- `cmake`
- `ninja-build`
- `pkg-config`
- `openmpi-bin`
- `libopenmpi-dev`
- `gdb`
- `valgrind`
- `python3`
- `python3-pip`
- `python3-venv`

## Step 3: Verify the Toolchain

After setup, these commands must work inside WSL:

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

## Step 4: Configure and Build

Debug build:

```bash
./scripts/configure_debug.sh
cmake --build build/debug
```

Release build:

```bash
./scripts/configure_release.sh
cmake --build build/release
```

## Step 5: Run Repository Smoke Checks

```bash
ctest --test-dir build/debug --output-on-failure
./build/debug/sequential_retriever --help
mpirun -np 4 ./build/debug/parallel_retriever --help
```

Or run the wrapper script:

```bash
./scripts/run_smoke_tests.sh
```

If you are still inside a temporary `root` login, OpenMPI blocks `mpirun` unless you explicitly allow it. For one-off verification only:

```bash
OMPI_ALLOW_RUN_AS_ROOT=1 OMPI_ALLOW_RUN_AS_ROOT_CONFIRM=1 \
  mpirun -np 4 ./build/debug/parallel_retriever --help
```

The preferred fix is to complete Ubuntu's normal user setup and work as that user afterward.

Optional Phase 2 dataset sanity check:

```bash
./build/debug/generate_vectors --N 100000 --D 384 --output data/memory_vectors.bin
./build/debug/inspect_dataset --input data/memory_vectors.bin
```

## Dataset Mounts

The host dataset root is:

```text
E:\data
```

Inside WSL, use:

```text
/mnt/e/data
```

Development docs use these dataset paths as canonical references for external corpora:

- `/mnt/e/data/ms_marco`
- `/mnt/e/data/squad`
- `/mnt/e/data/UIT-ViQuAD2.0`

## IDE Guidance

If you use CLion or VS Code:

1. Configure the toolchain to use WSL, not the native Windows compiler.
2. Point builds at `~/work/Parallel-Retrieval-Engine-for-RAG`.
3. Use `mpicxx` and `mpirun` inside the WSL environment.
4. Keep generated artifacts under `build/debug` and `build/release`.

## Environment Exit Criteria

The environment setup is considered ready when:

1. `Ubuntu-24.04` is installed under WSL2.
2. The repo is available from the canonical WSL path.
3. OpenMPI, CMake, and Ninja are installed inside Ubuntu.
4. The configure, build, and smoke commands run in WSL.
