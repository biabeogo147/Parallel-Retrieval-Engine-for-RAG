# Developer Guide

This file merges the former `environment_setup.md`, `dev_workflow.md`, and `codebase_layout.md` without shortening their content.

## Included Documents

- `environment_setup.md`
- `dev_workflow.md`
- `codebase_layout.md`

---

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

Optional Phase 3 exact-retrieval sanity check:

```bash
./build/debug/generate_vectors --N 100000 --D 384 --output data/memory_vectors.bin
./build/debug/generate_queries --Q 100 --D 384 --output data/query_vectors.bin
./build/debug/inspect_dataset --input data/memory_vectors.bin
./build/debug/sequential_retriever \
  --vectors data/memory_vectors.bin \
  --queries data/query_vectors.bin \
  --topk 10 \
  --output results/sequential_topk.csv
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


---

# Development Workflow

## Canonical Paths

Use these paths consistently in docs, commands, and day-to-day development:

- repo root in WSL: `~/work/Parallel-Retrieval-Engine-for-RAG`
- dataset root in WSL: `/mnt/e/data`
- debug build tree: `~/work/Parallel-Retrieval-Engine-for-RAG/build/debug`
- release build tree: `~/work/Parallel-Retrieval-Engine-for-RAG/build/release`

If the repository still lives on the Windows drive, move or reclone it into the WSL filesystem before doing normal development work. Native WSL storage is the default because it avoids Windows mount latency and ownership friction.

## Bootstrap Flow

### 1. Install Ubuntu on the Windows host

Run this in PowerShell on Windows:

```powershell
wsl --install -d Ubuntu-24.04
```

If Windows asks for a restart, reboot first and finish the Ubuntu first-run setup.

Do not stop at the temporary `root` shell. Complete the Ubuntu first-run flow so the distro has a normal Linux user for daily development.

### 2. Open the Ubuntu shell and create the canonical workspace

```bash
mkdir -p ~/work
cd ~/work
git clone <your-remote-url> Parallel-Retrieval-Engine-for-RAG
cd Parallel-Retrieval-Engine-for-RAG
```

### 3. Install toolchain dependencies

```bash
./scripts/setup_wsl_dev_env.sh
```

## Day-to-Day Build Flow

Configure a debug build:

```bash
./scripts/configure_debug.sh
```

Build targets:

```bash
cmake --build build/debug
```

Run tests:

```bash
ctest --test-dir build/debug --output-on-failure
```

Run the repository smoke bundle:

```bash
./scripts/run_smoke_tests.sh
```

## CLI Smoke Commands

Sequential help:

```bash
./build/debug/sequential_retriever --help
```

Parallel help:

```bash
mpirun -np 4 ./build/debug/parallel_retriever --help
```

If you are temporarily running as `root`, use:

```bash
OMPI_ALLOW_RUN_AS_ROOT=1 OMPI_ALLOW_RUN_AS_ROOT_CONFIRM=1 \
  mpirun -np 4 ./build/debug/parallel_retriever --help
```

## Phase 2 Synthetic Dataset Flow

Generate normalized memory vectors:

```bash
./build/debug/generate_vectors --N 100000 --D 384 --output data/memory_vectors.bin
```

Generate normalized query vectors:

```bash
./build/debug/generate_queries --Q 100 --D 384 --output data/query_vectors.bin
```

Inspect a generated dataset:

```bash
./build/debug/inspect_dataset --input data/memory_vectors.bin
```

## Phase 3 Exact Sequential Retrieval Flow

Run exact top-k over binary datasets:

```bash
./build/debug/sequential_retriever \
  --vectors data/memory_vectors.bin \
  --queries data/query_vectors.bin \
  --topk 10 \
  --output results/sequential_topk.csv
```

The current CSV contract is:

- header row exactly `query_id,rank_position,memory_id,score`
- `query_id` is the zero-based query row index
- `memory_id` is the zero-based memory row index
- `rank_position` is one-based within each query
- `score` is written with fixed decimal formatting to 8 digits after the decimal point

Use the repository-local `data/` directory for synthetic outputs produced by development and smoke checks. Reserve `/mnt/e/data` for larger external benchmark corpora and converted real datasets added in later phases.

## Generated Artifacts

Generated files should stay inside these locations:

- build outputs: `build/debug` and `build/release`
- local synthetic datasets produced by the current pipeline: `data/`
- benchmark outputs produced by future phases: `results/`

Do not commit generated content from `build/`, `data/`, or `results/`.

## Documentation Maintenance Rules

When you add or move docs:

1. Keep implementation and architecture docs in `docs/development/`.
2. Keep plan artifacts in `docs/plans/`.
3. Update cross-links immediately if a doc path changes.
4. Prefer WSL paths in all developer-facing commands.


---

# Codebase Layout

## Top-Level Responsibilities

### `include/`

Public project headers for shared code used across binaries and tests.

- `Config.hpp`: CLI contract and validation result types
- `Logger.hpp`: log-level parsing and stderr logger
- `MpiSession.hpp`: minimal MPI lifecycle wrapper
- `BinaryDataset.hpp`: binary header contract, full reads, and shard-aware reads
- `TopKHeap.hpp`: deterministic in-memory top-k candidate selection
- `SequentialRetriever.hpp`: exact sequential retrieval over validated in-memory datasets

### `src/`

Implementation files and entrypoints.

- `Config.cpp`: parse and validate CLI arguments
- `Logger.cpp`: logging implementation
- `MpiSession.cpp`: MPI bootstrap and teardown
- `BinaryDataset.cpp`: binary dataset read/write and shard computation
- `TopKHeap.cpp`: heap maintenance and tie-break ordering
- `SequentialRetriever.cpp`: exact dot-product scan for one query or all queries
- `main_sequential.cpp`: sequential CLI load, search, and CSV output path
- `main_parallel.cpp`: MPI CLI stub

### `tests/`

Small executable or script-based checks used by `CTest`.

- `ConfigLoggerTest.cpp`: parser and usage-contract verification
- `BinaryDatasetTest.cpp`: binary header validation, payload validation, and shard logic
- `SequentialRetrieverTest.cpp`: retrieval ordering, top-k behavior, offset handling, and failure cases
- `tests/cmake/*.cmake`: CLI smoke, determinism, and sequential end-to-end checks

Later phases may add retrieval correctness and benchmark-result checks here.

### `scripts/`

POSIX shell helpers intended to run inside Ubuntu WSL.

- `setup_wsl_dev_env.sh`: package install and tool verification
- `configure_debug.sh`: configure the debug build tree
- `configure_release.sh`: configure the release build tree
- `run_smoke_tests.sh`: build and run the current repository smoke suite

### `tools/`

Standalone helper binaries and utilities that are not part of the main retriever entrypoints.

- `generate_vectors.cpp`: deterministic synthetic memory-vector generator
- `generate_queries.cpp`: deterministic synthetic query-vector generator
- `inspect_dataset.cpp`: read-only binary header inspection tool
- `SyntheticGeneratorCommon.hpp`: shared tool-only generator and parser helpers

### `data/`

Local generated datasets produced during development. This directory is kept in git only with a placeholder and should not contain committed large binaries.

### `results/`

Local CSVs, benchmark tables, and other generated outputs. Like `data/`, this stays mostly untracked.

### `docs/development/`

Canonical technical docs:

- project specification
- data pipeline and benchmarks
- developer guide
- source guide
- master project plan

### `docs/plans/`

Execution plans and planning artifacts tied to dated work items.

## Build Targets

The current build introduces these targets:

- `retriever_core`
- `sequential_retriever`
- `parallel_retriever`
- `config_logger_test`
- `generate_vectors`
- `generate_queries`
- `inspect_dataset`
- `binary_dataset_test`
- `sequential_retriever_test`

`retriever_core` is the shared internal layer. Later phases should prefer extending it instead of duplicating parsing or logging logic in individual binaries.

## Maintainability Rules

1. Shared logic belongs in `retriever_core`, not duplicated in each `main`.
2. New docs must use the refactored `docs/development` and `docs/plans` paths.
3. WSL-first commands should be the default in docs and scripts.
4. Tool-only helpers should stay under `tools/` unless they become shared runtime code needed by retrievers and tests.

