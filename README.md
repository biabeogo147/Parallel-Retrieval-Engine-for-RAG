# Parallel Retrieval Engine for RAG

## Overview

This repository hosts a WSL-first C++17 and OpenMPI foundation for an exact top-k long-term memory retriever. Phase 1 focuses on maintainability: project layout, CLI contracts, MPI bootstrap, smoke-test coverage, and developer documentation.

The retrieval algorithm itself is intentionally deferred to later phases. Right now, the binaries provide:

- stable CLI parsing
- help and validation behavior
- minimal logging
- MPI process bootstrap for the parallel entrypoint

## Canonical Development Environment

- WSL2
- Ubuntu 24.04 LTS
- OpenMPI
- CMake + Ninja
- source checkout at `~/work/Parallel-Retrieval-Engine-for-RAG`
- dataset root at `/mnt/e/data`

If WSL is not installed yet on the Windows host, start with:

```powershell
wsl --install -d Ubuntu-24.04
```

After Ubuntu is available, work inside WSL from the canonical repo path.

## Repository Layout

```text
~/work/Parallel-Retrieval-Engine-for-RAG/
├── CMakeLists.txt
├── README.md
├── include/
├── src/
├── tests/
├── scripts/
├── tools/
├── data/
├── results/
├── docs/
│   ├── development/
│   └── plans/
└── build/
    ├── debug/
    └── release/
```

For a folder-by-folder explanation, see:

- `docs/development/codebase_layout.md`
- `docs/development/dev_workflow.md`

## Quickstart in WSL

Clone or move the repo into the canonical location:

```bash
mkdir -p ~/work
cd ~/work
git clone <your-remote-url> Parallel-Retrieval-Engine-for-RAG
cd Parallel-Retrieval-Engine-for-RAG
```

Install the Phase 1 toolchain inside Ubuntu:

```bash
./scripts/setup_wsl_dev_env.sh
```

Configure and build a debug tree:

```bash
./scripts/configure_debug.sh
cmake --build build/debug
ctest --test-dir build/debug --output-on-failure
```

Smoke-check the CLI entrypoints:

```bash
./build/debug/sequential_retriever --help
mpirun -np 4 ./build/debug/parallel_retriever --help
```

If your Ubuntu distro is still running as `root` during initial setup, OpenMPI blocks `mpirun` by default. In that temporary case, either finish the normal Ubuntu user setup or run:

```bash
OMPI_ALLOW_RUN_AS_ROOT=1 OMPI_ALLOW_RUN_AS_ROOT_CONFIRM=1 \
  mpirun -np 4 ./build/debug/parallel_retriever --help
```

Or run the combined Phase 1 smoke script:

```bash
./scripts/run_smoke_tests.sh
```

## Current Phase Status

Phase 1 provides:

- `retriever_core` shared internal code for config parsing and logging
- `sequential_retriever` CLI scaffold
- `parallel_retriever` MPI scaffold
- a small `CTest` test target for parser behavior
- WSL helper scripts and onboarding docs

Phase 2 and later will add:

- binary dataset generation and loading
- exact retrieval logic
- correctness checking
- runtime, granularity, and speedup experiments

## Documentation Index

- `docs/development/project_scope.md`
- `docs/development/algorithm_design.md`
- `docs/development/benchmark_data.md`
- `docs/development/environment_setup.md`
- `docs/development/dev_workflow.md`
- `docs/development/codebase_layout.md`
- `docs/development/parallel_agent_memory_retriever_plan.md`
- `docs/plans/2026-06-15-phase-0-documentation.md`
