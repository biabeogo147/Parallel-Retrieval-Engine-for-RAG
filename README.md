# Parallel Retrieval Engine for RAG

## Overview

This repository hosts a WSL-first C++17 and OpenMPI codebase for an exact top-k long-term memory retriever.

The current implementation covers:

- Phase 1 foundation work: project layout, CLI contracts, MPI bootstrap, smoke-test coverage, and developer documentation
- Phase 2 synthetic dataset work: deterministic normalized `float32` dataset generation, binary dataset loading, shard-aware reads, and a dataset inspection tool

The retrieval algorithm itself is intentionally deferred to later phases.

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
|-- CMakeLists.txt
|-- README.md
|-- include/
|-- src/
|-- tests/
|-- scripts/
|-- tools/
|-- data/
|-- results/
|-- docs/
|   |-- development/
|   `-- plans/
`-- build/
    |-- debug/
    `-- release/
```

For a folder-by-folder explanation, see:

- `docs/development/developer_guide.md`

## Quickstart in WSL

Clone or move the repo into the canonical location:

```bash
mkdir -p ~/work
cd ~/work
git clone <your-remote-url> Parallel-Retrieval-Engine-for-RAG
cd Parallel-Retrieval-Engine-for-RAG
```

Install the development toolchain inside Ubuntu:

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

Generate and inspect synthetic datasets:

```bash
./build/debug/generate_vectors --N 100000 --D 384 --output data/memory_vectors.bin
./build/debug/generate_queries --Q 100 --D 384 --output data/query_vectors.bin
./build/debug/inspect_dataset --input data/memory_vectors.bin
```

If your Ubuntu distro is still running as `root` during initial setup, OpenMPI blocks `mpirun` by default. In that temporary case, either finish the normal Ubuntu user setup or run:

```bash
OMPI_ALLOW_RUN_AS_ROOT=1 OMPI_ALLOW_RUN_AS_ROOT_CONFIRM=1 \
  mpirun -np 4 ./build/debug/parallel_retriever --help
```

Or run the combined smoke script:

```bash
./scripts/run_smoke_tests.sh
```

## Current Phase Status

Implemented now:

- `retriever_core` shared internal code for config parsing, logging, and binary dataset IO
- `sequential_retriever` CLI scaffold
- `parallel_retriever` MPI scaffold
- `generate_vectors`, `generate_queries`, and `inspect_dataset`
- `CTest` coverage for parser behavior, dataset IO, and deterministic generator smoke checks
- WSL helper scripts and onboarding docs

Still deferred to later phases:

- exact retrieval logic
- correctness checking
- runtime, granularity, and speedup experiments
- real-text preprocessing and corpus conversion

## Documentation Index

- `AGENTS.md`
- `docs/development/project_specification.md`
- `docs/development/data_pipeline_and_benchmarks.md`
- `docs/development/developer_guide.md`
- `docs/development/source_guide.md`
- `docs/development/parallel_agent_memory_retriever_plan.md`
- `docs/plans/2026-06-15-phase-0-documentation.md`
- `docs/plans/2026-06-15-phase-1-foundation.md`
- `docs/plans/2026-06-15-phase-2-dataset-generator-loader.md`
