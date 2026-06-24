# Parallel Retrieval Engine for RAG

## Overview

This repository hosts a WSL-first C++17 and OpenMPI codebase for an exact top-k long-term memory retriever.

The current implementation covers:

- Phase 1 foundation work: project layout, CLI contracts, MPI bootstrap, smoke-test coverage, and developer documentation
- Phase 2 synthetic dataset work: deterministic normalized `float32` dataset generation, binary dataset loading, shard-aware reads, and a dataset inspection tool
- Phase 3 retrieval work: exact sequential top-k retrieval, deterministic tie-breaking, and canonical CSV output
- Phase 4 retrieval work: exact blocking MPI top-k retrieval, shard-local search reuse, and per-rank metrics CSV output
- Phase 5 correctness work: sequential-vs-parallel CSV comparison, canonical correctness CSV output, and verification-oriented smoke coverage
- Phase 6 benchmark-summary work: canonical one-run metrics rows for sequential and parallel retrieval
- Phase 7 automation work: WSL-first synthetic benchmark scripts, speedup/runtime aggregation, and figure generation
- Phase 8 external-baseline work: FAISS exact-flat comparison over synthetic datasets plus one real-corpus conversion path for `SQuAD + sentence-transformers/all-MiniLM-L6-v2`
- a reusable benchmark-analysis layer: derived analysis CSVs, machine-readable benchmark summaries, and report-ready Markdown conclusions

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
|   |-- usage/
|   `-- plans/
`-- build/
    |-- debug/
    `-- release/
```

For a folder-by-folder explanation, see:

- `docs/development/developer_guide.md`

For copy-paste operational docs after `git clone`, start with:

- `docs/usage/README.md`

For physical three-machine MPI cluster setup after local onboarding, continue with:

- `docs/usage/mpi-cluster/README.md`
- `docs/usage/mpi-cluster/two-node-runbook-two-nodes.md` if you want the exact validated local-WSL-head plus one-Ubuntu-worker flow

## Quickstart in WSL

Clone the repo into the canonical location:

```bash
mkdir -p ~/work
cd ~/work
git clone <your-remote-url> Parallel-Retrieval-Engine-for-RAG
cd Parallel-Retrieval-Engine-for-RAG
```

Install the development toolchain, configure a debug build, and run the repository smoke wrapper:

```bash
bash ./scripts/setup_wsl_dev_env.sh
bash ./scripts/configure_debug.sh
cmake --build build/debug
ctest --test-dir build/debug --output-on-failure
bash ./scripts/run_smoke_tests.sh
```

This is the compact onboarding path. For the full command-first workflow set, use:

- `docs/usage/getting-started-wsl.md`
- `docs/usage/retrieval-workflows.md`
- `docs/usage/results-csv-reference.md`
- `docs/usage/benchmark-workflows.md`
- `docs/usage/troubleshooting.md`

If you need a physical multi-node MPI deployment and validation workflow instead of the single-machine path above, use:

- `docs/usage/mpi-cluster/README.md`

## Current Phase Status

Implemented now:

- `retriever_core` shared internal code for config parsing, logging, binary dataset IO, correctness comparison, and benchmark summary metrics
- `TopKHeap`, `SequentialRetriever`, and `ParallelRetriever` reusable retrieval core
- `CorrectnessChecker` reusable top-k CSV comparison core
- `BenchmarkMetrics` reusable one-run metrics and speedup row helper layer
- `sequential_retriever` exact sequential search path from binary input to CSV output
- `parallel_retriever` exact blocking MPI retrieval path from sharded input to global CSV output
- `verify_results` correctness-checking path from two top-k CSV inputs to `correctness.csv`
- per-rank metrics CSV output for the parallel binary
- optional `--run-metrics` output for sequential and parallel benchmark summaries
- `generate_vectors`, `generate_queries`, and `inspect_dataset`
- benchmark automation scripts for runtime-by-N selection, correctness, granularity, speedup, and all-in-one experiment runs
- Phase 8 Python helpers for binary dataset reuse, FAISS exact-flat search, and SQuAD + MiniLM conversion
- `run_faiss_comparison.sh` orchestration for sequential, parallel, and FAISS comparison artifacts under `results/faiss/`
- `analyze_benchmarks.py` for deterministic post-run analysis under `results/analysis/` plus `docs/analysis/latest-benchmark-review.md`
- generic physical-cluster rerun wrapper for a prepared `rag-head + N workers` topology:
  - `run_cluster_n_node_bundle.sh`
- dedicated physical-cluster wrappers for the validated two-node `rag-head + rag-worker1` flow:
  - `run_cluster_two_node_bundle.sh`
  - `run_cluster_postprocess.sh`
  - `docs/analysis/latest-cluster-benchmark-review.md`
  - optional external-storage root such as `/mnt/e/data/pdp_retrieve_engine` for large cluster reruns on Windows + WSL
- `CTest` coverage for parser behavior, dataset IO, deterministic generator smoke checks, sequential retrieval checks, blocking MPI smoke checks, correctness-check workflow checks, and benchmark automation smoke runs
- `CTest` smoke coverage for FAISS comparison-table generation and reduced-profile FAISS workflow orchestration
- `CTest` smoke coverage for benchmark-analysis generation, invalid-correctness gating, and missing-input failures
- `CTest` smoke coverage for cluster bundle dry-run planning and cluster postprocess artifact generation
- WSL helper scripts and onboarding docs

Still deferred to later phases:

- broader real-text corpus conversion beyond the current `SQuAD + all-MiniLM-L6-v2` path
- metadata-backed agent/demo layers, alternate ANN-style baselines, and final report packaging

## Documentation Index

- `AGENTS.md`
- `docs/usage/README.md`
- `docs/usage/getting-started-wsl.md`
- `docs/usage/retrieval-workflows.md`
- `docs/usage/results-csv-reference.md`
- `docs/usage/benchmark-workflows.md`
- `docs/usage/troubleshooting.md`
- `docs/usage/mpi-cluster/README.md`
- `docs/usage/mpi-cluster/two-node-runbook-two-nodes.md`
- `docs/usage/mpi-cluster/node-bootstrap-wsl.md`
- `docs/usage/mpi-cluster/node-bootstrap-ubuntu.md`
- `docs/usage/mpi-cluster/node-bootstrap-macos-multipass.md`
- `docs/usage/mpi-cluster/cluster-assembly-and-validation.md`
- `docs/usage/mpi-cluster/cluster-runbook.md`
- `docs/usage/mpi-cluster/troubleshooting.md`
- `docs/analysis/README.md`
- `docs/analysis/report_mapping.md`
- `docs/analysis/latest-benchmark-review.md`
- `docs/analysis/latest-cluster-benchmark-review.md`
- `docs/development/project_specification.md`
- `docs/development/data_pipeline_and_benchmarks.md`
- `docs/development/developer_guide.md`
- `docs/development/source_guide.md`
- `docs/development/parallel_agent_memory_retriever_plan.md`
- `docs/plans/2026-06-15-phase-0-documentation.md`
- `docs/plans/2026-06-15-phase-1-foundation.md`
- `docs/plans/2026-06-15-phase-2-dataset-generator-loader.md`
- `docs/plans/2026-06-15-phase-3-sequential-exact-retrieval.md`
- `docs/plans/2026-06-15-phase-4-blocking-mpi-parallel-retrieval.md`
- `docs/plans/2026-06-15-phase-5-correctness-checker.md`
- `docs/plans/2026-06-15-phase-6-benchmark-run-metrics.md`
- `docs/plans/2026-06-15-phase-7-experiment-automation.md`
- `docs/plans/2026-06-15-phase-8-plan-reframe.md`
- `docs/plans/2026-06-16-phase-8-faiss-baseline-comparison.md`
- `docs/plans/2026-06-16-benchmark-analysis-layer.md`
- `docs/plans/2026-06-15-usage-onboarding-docs.md`
- `docs/plans/2026-06-17-mpi-cluster-setup-docs.md`
- `docs/plans/2026-06-23-cluster-benchmark-full-bundle.md`
