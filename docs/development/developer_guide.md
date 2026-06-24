# Developer Guide

This file merges the former `environment_setup.md`, `dev_workflow.md`, and `codebase_layout.md` without shortening their content.

Fresh-clone, command-first operational onboarding now lives under `docs/usage/`. Start with `../usage/README.md` if you want the shortest path from clone to working commands. This guide remains the deeper technical development reference behind those workflows.

Physical multi-node MPI cluster operations now live under `../usage/mpi-cluster/README.md`. The canonical development environment in this document remains the single-machine WSL-first setup used for coding, building, testing, and the current automation scripts.

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
bash ./scripts/setup_wsl_dev_env.sh
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
bash ./scripts/configure_debug.sh
cmake --build build/debug
```

Release build:

```bash
bash ./scripts/configure_release.sh
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
bash ./scripts/run_smoke_tests.sh
```

If you are still inside a temporary `root` login, OpenMPI blocks `mpirun` unless you explicitly allow it. For one-off verification only:

```bash
OMPI_ALLOW_RUN_AS_ROOT=1 OMPI_ALLOW_RUN_AS_ROOT_CONFIRM=1 \
  mpirun -np 4 ./build/debug/parallel_retriever --help
```

The preferred fix is to complete Ubuntu's normal user setup and work as that user afterward.

Optional Phase 4 exact-retrieval sanity check:

```bash
./build/debug/generate_vectors --N 100000 --D 384 --output data/memory_vectors.bin
./build/debug/generate_queries --Q 100 --D 384 --output data/query_vectors.bin
./build/debug/inspect_dataset --input data/memory_vectors.bin
./build/debug/sequential_retriever \
  --vectors data/memory_vectors.bin \
  --queries data/query_vectors.bin \
  --topk 10 \
  --output results/sequential_topk.csv
mpirun -np 4 ./build/debug/parallel_retriever \
  --vectors data/memory_vectors.bin \
  --queries data/query_vectors.bin \
  --topk 10 \
  --output results/parallel_topk.csv \
  --metrics results/parallel_metrics.csv
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
bash ./scripts/setup_wsl_dev_env.sh
```

## Day-to-Day Build Flow

Configure a debug build:

```bash
bash ./scripts/configure_debug.sh
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
bash ./scripts/run_smoke_tests.sh
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

## Phase 4 Blocking Parallel Retrieval Flow

Run exact top-k over sharded memory vectors with blocking MPI collectives:

```bash
mpirun -np 4 ./build/debug/parallel_retriever \
  --vectors data/memory_vectors.bin \
  --queries data/query_vectors.bin \
  --topk 10 \
  --output results/parallel_topk.csv \
  --metrics results/parallel_metrics.csv
```

The current parallel output contracts are:

- `parallel_topk.csv` uses the same schema as the sequential binary:
  - `query_id,rank_position,memory_id,score`
- `parallel_metrics.csv` uses:
  - `rank,local_N,compute_time,communication_time,active_time,global_total_time,idle_time`
- `query_id` and `memory_id` stay zero-based global row indices
- `parallel_retriever` reads the memory dataset per-rank via `BinaryDataset::read_shard(...)`
- rank `0` reads the full query payload, broadcasts one query vector at a time, gathers fixed-size local top-k buffers, merges the global top-k, and writes both CSV outputs

## Phase 5 Correctness Verification Flow

Compare sequential and parallel top-k CSV outputs with an explicit score tolerance:

```bash
./build/debug/verify_results \
  --sequential results/sequential_topk.csv \
  --parallel results/parallel_topk.csv \
  --epsilon 1e-5 \
  --output results/correctness.csv
```

The current correctness output contract is:

- `correctness.csv` uses:
  - `query_id,k,matched,matched_ids,max_score_diff,status`
- `matched` is written as `true` or `false`
- `matched_ids` counts exact `memory_id` matches at the same `rank_position`
- `max_score_diff` is the largest absolute score difference for aligned ranks in that query
- `status` is `PASS` when `matched_ids == k` and `max_score_diff <= epsilon`, otherwise `FAIL`
- `verify_results` returns:
  - `0` when all queries pass
  - `1` when comparison succeeds but at least one query fails
  - `2` for invalid CLI arguments, malformed CSV input, or runtime errors

## Phase 6 Run-Summary Metrics Flow

Both retriever binaries now support an optional one-run summary metrics output for benchmark automation:

```bash
./build/debug/sequential_retriever \
  --vectors data/memory_vectors.bin \
  --queries data/query_vectors.bin \
  --topk 10 \
  --output results/sequential_topk.csv \
  --run-metrics results/sequential_run_metrics.csv

mpirun -np 4 ./build/debug/parallel_retriever \
  --vectors data/memory_vectors.bin \
  --queries data/query_vectors.bin \
  --topk 10 \
  --output results/parallel_topk.csv \
  --metrics results/parallel_metrics.csv \
  --run-metrics results/parallel_run_metrics.csv
```

The current run-summary CSV contract is:

- `N,D,Q,k,P,compute_time,communication_time,total_time`
- sequential rows always use `P=1` and `communication_time=0`
- sequential `total_time` matches the benchmarked local-search window
- parallel `total_time` matches `global_total_time` from the per-rank metrics CSV
- these one-row CSV files are intended as script inputs, not long-lived final benchmark tables

## Phase 7 Benchmark Automation Flow

Run the full synthetic benchmark pipeline from WSL:

```bash
bash ./scripts/run_all_experiments.sh
```

The automation layer now provides:

- `scripts/run_calibrate_target.sh`
  - runs the maintained stage-1 calibration flow
  - generates `results/runtime_by_N.csv`
  - writes `results/benchmark_selection.env`
- `scripts/run_select_N.sh`
  - compatibility wrapper that delegates to `run_calibrate_target.sh`
- `scripts/run_correctness.sh`
  - generates `results/sequential_topk.csv`
  - generates `results/parallel_topk.csv`
  - generates `results/correctness.csv`
- `scripts/run_granularity.sh`
  - generates `results/granularity.csv`
  - generates `results/granularity_summary.txt`
- `scripts/run_speedup.sh`
  - generates `results/speedup.csv`
- `scripts/run_all_experiments.sh`
  - runs the four benchmark stages
  - creates `results/figures/*.png`
- `scripts/run_faiss_comparison.sh`
  - runs the Phase 8 sequential / parallel / FAISS comparison workflow
  - creates `results/faiss/*.csv`
- `scripts/analyze_benchmarks.py`
  - derives report-oriented analysis outputs from the final benchmark CSVs
  - creates `results/analysis/*` and `docs/analysis/latest-benchmark-review.md`

Default benchmark knobs are controlled by environment variables:

- `BENCH_D`
- `BENCH_Q`
- `BENCH_Q_CANDIDATES`
- `BENCH_TOPK`
- `BENCH_EPSILON`
- `BENCH_N_CANDIDATES`
- `BENCH_SPEEDUP_N_CANDIDATES`
- `BENCH_SPEEDUP_BASELINE_LIMIT`
- `BENCH_P_SELECTED`
- `BENCH_P_LIST`
- `BENCH_BUILD_DIR`
- `BENCH_STORAGE_ROOT`
- `BENCH_RESULTS_DIR`
- `BENCH_SCRATCH_DIR`
- `BENCH_FAISS_RESULTS_DIR`
- `BENCH_SQUAD_INPUT_DIR`
- `BENCH_SQUAD_OUTPUT_DIR`
- `BENCH_SQUAD_MODEL`
- `BENCH_SQUAD_QUERIES_LIMIT`

The repo-local `.venv/` is now reused for both:

- Phase 7 plotting dependencies such as `matplotlib`
- Phase 8 Python dependencies such as `faiss-cpu`, `pyarrow`, and `sentence-transformers`

If `BENCH_STORAGE_ROOT` is set, the benchmark layer derives these heavier paths from it unless they are overridden explicitly:

- `BENCH_RESULTS_DIR="$BENCH_STORAGE_ROOT/results"`
- `BENCH_SCRATCH_DIR="$BENCH_STORAGE_ROOT/scratch"`
- `BENCH_PLOT_VENV_DIR="$BENCH_STORAGE_ROOT/.venv"`
- `BENCH_SQUAD_OUTPUT_DIR="$BENCH_STORAGE_ROOT/real_corpora/squad_minilm"`

Use the repository-local `data/` directory for synthetic outputs produced by development and smoke checks. Reserve `/mnt/e/data` for larger external benchmark corpora and converted real datasets added in later phases.

The benchmark stage scripts now also self-heal older manifests. If `results/benchmark_selection.env` is missing or still uses the older reduced field set, `run_correctness.sh`, `run_granularity.sh`, `run_speedup.sh`, and `run_faiss_comparison.sh` regenerate it through `run_calibrate_target.sh` before continuing.

## Phase 8 FAISS External Baseline Flow

Phase 8 adds a separate comparison workflow on top of the existing synthetic benchmark stack. It does not replace `run_all_experiments.sh`; instead, it adds a distinct script for FAISS-based external baseline comparison.

Run the full Phase 8 comparison flow from WSL:

```bash
bash ./scripts/run_faiss_comparison.sh
```

The orchestration script now performs:

- synthetic dataset reuse or generation through the existing Phase 7 benchmark helpers
- exact sequential retrieval to produce the reference top-k CSV
- exact MPI retrieval to produce the parallel run-summary CSV used in the comparison table
- FAISS `IndexFlatIP` search over the same normalized binary vectors
- correctness verification between `sequential_retriever` and the FAISS top-k output
- one real-corpus path based on `SQuAD + sentence-transformers/all-MiniLM-L6-v2`
- final aggregation into `results/faiss/comparison.csv`

If `BENCH_SQUAD_OUTPUT_DIR` does not already contain:

- `vectors.bin`
- `queries.bin`

then `run_faiss_comparison.sh` calls `prepare_squad_minilm.py` automatically to create them from:

- `BENCH_SQUAD_INPUT_DIR`
- `BENCH_SQUAD_MODEL`
- `BENCH_SQUAD_QUERIES_LIMIT`

Typical direct real-corpus preparation command:

```bash
python3 ./scripts/prepare_squad_minilm.py \
  --input-dir /mnt/e/data/squad/plain_text \
  --output-dir .cache/real_corpora/squad_minilm \
  --model sentence-transformers/all-MiniLM-L6-v2 \
  --queries-limit 100
```

Typical direct FAISS comparison command on any already-prepared binary dataset pair:

```bash
python3 ./scripts/faiss_compare.py \
  --dataset-name synthetic \
  --vectors data/memory_vectors.bin \
  --queries data/query_vectors.bin \
  --topk 10 \
  --threads 4 \
  --output-topk results/faiss/synthetic_topk.csv \
  --output-metrics results/faiss/synthetic_run_metrics.csv
```

The Phase 8 artifact set is:

- `results/faiss/synthetic_topk.csv`
- `results/faiss/synthetic_run_metrics.csv`
- `results/faiss/synthetic_correctness.csv`
- `results/faiss/squad_topk.csv`
- `results/faiss/squad_run_metrics.csv`
- `results/faiss/squad_correctness.csv`
- `results/faiss/comparison.csv`

The real-corpus conversion cache is stored under:

- `.cache/real_corpora/squad_minilm/`

## Cluster Bundle Flows

The repository now provides two different physical-cluster operator layers:

- generic prepared-cluster rerun:
  - `scripts/cluster_n_node_common.sh`
  - `scripts/run_cluster_n_node_bundle.sh`
  - documented in `../usage/mpi-cluster/cluster-runbook.md`
- dedicated validated two-node full bundle:
  - `scripts/cluster_common.sh`
  - `scripts/run_cluster_two_node_bundle.sh`
  - `scripts/run_cluster_postprocess.sh`
  - documented in `../usage/mpi-cluster/two-node-runbook-two-nodes.md`

Use the generic N-node wrapper only after the operator has already prepared:

- the authoritative hostfile with explicit `slots=...`
- identical selected-workload and speedup-workload dataset paths on every node
- an existing `benchmark_selection.env`

It intentionally does not generate datasets, `rsync` files, SSH-orchestrate workers, or run FAISS.

Typical generic entrypoint:

```bash
cp docs/usage/mpi-cluster/examples/n_node_bundle.env.example .cache/cluster/n_node_bundle.env
nano .cache/cluster/n_node_bundle.env
bash ./scripts/run_cluster_n_node_bundle.sh \
  --config .cache/cluster/n_node_bundle.env \
  --run-tag "$(date +%F)-n-node-bundle"
```

## Dedicated Two-Node Cluster Bundle Flow

The repository now also provides one dedicated physical-cluster operator wrapper for the validated:

- `rag-head`
- `rag-worker1`

topology documented in `../usage/mpi-cluster/two-node-runbook-two-nodes.md`.

Use it only from a WSL-native head-node checkout such as:

- `~/work/Parallel-Retrieval-Engine-for-RAG`

Do not launch the real cluster bundle from a Windows-mounted repo path such as:

- `/mnt/d/DS-AI/Parallel-Retrieval-Engine-for-RAG`

because the cluster wrapper intentionally rejects `/mnt/...` head-node checkouts for real execution.

The dedicated operator surface is:

- `scripts/cluster_common.sh`
  - shared two-node cluster helpers, hostfile rewriting, worker sync helpers, WSL-specific OpenMPI launch controls, and repo-local runtime staging for external benchmark-storage roots
- `scripts/run_cluster_two_node_bundle.sh`
  - the maintained `6`-stage operator flow for:
    - cluster runtime calibration
    - selected synthetic correctness run
    - granularity summary
    - speedup sweep
    - FAISS comparisons
    - cluster postprocess
- `scripts/run_cluster_postprocess.sh`
  - figure and analysis regeneration for an existing `results/cluster/<run-tag>/` directory

Typical entrypoint:

```bash
cp docs/usage/mpi-cluster/examples/two_node_bundle.env.example .cache/cluster/two_node_bundle.env
nano .cache/cluster/two_node_bundle.env
bash ./scripts/run_cluster_two_node_bundle.sh \
  --config .cache/cluster/two_node_bundle.env \
  --run-tag "$(date +%F)-local-plus-199-full-bundle"
```

On the current Windows + WSL machine, the maintained two-node workflow now prefers:

- `BENCH_STORAGE_ROOT=/mnt/e/data/pdp_retrieve_engine`

so the large cluster bundle writes scratch datasets, benchmark CSVs, the plotting `.venv`, and the SQuAD conversion cache outside the WSL ext4 virtual disk on `C:`. The wrapper still keeps lightweight repo-local runtime paths under `.cache/cluster_runtime/` so head-node symlinks and worker-side file copies resolve under the same repo-relative MPI paths.

This is intentionally a case-specific operator wrapper. The generic `head + workers` cluster guidance remains manual and lives under `../usage/mpi-cluster/`.

## Benchmark Analysis Flow

After the synthetic benchmark workflow and the FAISS comparison workflow have both completed, run the reusable analysis layer:

```bash
python3 ./scripts/analyze_benchmarks.py \
  --results-dir results \
  --output-dir results/analysis \
  --docs-output docs/analysis/latest-benchmark-review.md
```

This analysis pass is intentionally post-run and derived-only. It does not change the raw benchmark CSV contracts. Instead, it generates:

- derived analysis CSVs under `results/analysis/`
- a machine-readable `benchmark_summary.json`
- a Markdown review in `results/analysis/final_conclusions.md`
- a report-facing copy at `docs/analysis/latest-benchmark-review.md`

Use that final Markdown file when you need a reproducible narrative summary instead of writing one-off benchmark notes by hand.

## Generated Artifacts

Generated files should stay inside these locations:

- build outputs: `build/debug` and `build/release`
- local synthetic datasets produced by the current pipeline: `data/`
- benchmark outputs produced by the current pipeline: `results/`
- derived benchmark-analysis outputs: `results/analysis/`
- benchmark scratch/cache files: `.cache/benchmarks/`
- converted Phase 8 real-corpus binaries and metadata: `.cache/real_corpora/`
- plotting and Phase 8 Python runtime dependencies: `.venv/`

Do not commit generated content from `build/`, `data/`, or `results/`.

## Documentation Maintenance Rules

When you add or move docs:

1. Keep implementation and architecture docs in `docs/development/`.
2. Keep user-facing operational how-to docs in `docs/usage/`.
3. Keep benchmark interpretation and report-facing benchmark conclusions in `docs/analysis/`.
4. Keep plan artifacts in `docs/plans/`.
5. Update cross-links immediately if a doc path changes.
6. Prefer WSL paths in all developer-facing commands.


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
- `ParallelRetriever.hpp`: global top-k merge and parallel metrics row type
- `BenchmarkMetrics.hpp`: run-summary metrics rows, speedup rows, and run-metrics CSV writing
- `CorrectnessChecker.hpp`: top-k CSV row model and sequential-vs-parallel comparison API
- `MpiUtils.hpp`: blocking MPI helpers for query broadcast, fixed-size candidate gather, and startup/metrics coordination

### `src/`

Implementation files and entrypoints.

- `Config.cpp`: parse and validate CLI arguments
- `Logger.cpp`: logging implementation
- `MpiSession.cpp`: MPI bootstrap and teardown
- `BinaryDataset.cpp`: binary dataset read/write and shard computation
- `TopKHeap.cpp`: heap maintenance and tie-break ordering
- `SequentialRetriever.cpp`: exact dot-product scan for one query or all queries
- `ParallelRetriever.cpp`: sentinel filtering and global top-k merge
- `BenchmarkMetrics.cpp`: run-summary metrics aggregation, speedup-row construction, and CSV writing
- `CorrectnessChecker.cpp`: CSV-row validation, normalization, and per-query comparison logic
- `MpiUtils.cpp`: MPI_Bcast/MPI_Gather wrappers and rank-metrics collection helpers
- `main_sequential.cpp`: sequential CLI load, search, and CSV output path
- `main_parallel.cpp`: MPI CLI load, shard-local search, gather, merge, and metrics output path

### `tests/`

Small executable or script-based checks used by `CTest`.

- `ConfigLoggerTest.cpp`: parser and usage-contract verification
- `BinaryDatasetTest.cpp`: binary header validation, payload validation, and shard logic
- `SequentialRetrieverTest.cpp`: retrieval ordering, top-k behavior, offset handling, and failure cases
- `ParallelRetrieverTest.cpp`: global merge ordering and sentinel handling
- `BenchmarkMetricsTest.cpp`: run-summary metrics aggregation and speedup-row validation
- `CorrectnessCheckerTest.cpp`: correctness comparison validation and failure cases
- `tests/cmake/*.cmake`: CLI smoke, determinism, sequential checks, blocking MPI end-to-end checks, correctness-check workflow checks, and benchmark automation smoke checks
- `tests/cmake/RunClusterPostprocessSmoke.cmake`: cluster postprocess artifact-generation smoke check
- `tests/cmake/RunClusterBundleDryRunSmoke.cmake`: cluster bundle dry-run plan smoke check

Later phases may still add broader real-text corpus checks, alternate-baseline checks, metadata-backed demo checks, and report-oriented validation here.

### `scripts/`

POSIX shell helpers intended to run inside Ubuntu WSL.

- `setup_wsl_dev_env.sh`: package install and tool verification
- `configure_debug.sh`: configure the debug build tree
- `configure_release.sh`: configure the release build tree
- `run_smoke_tests.sh`: build and run the current repository smoke suite
- `benchmark_common.sh`: shared benchmark environment/bootstrap helpers
- `run_calibrate_target.sh`: maintained calibration stage for `N`, fallback `Q`, and explicit `N_SPEEDUP`
- `run_select_N.sh`: compatibility wrapper for the calibration stage
- `run_correctness.sh`: correctness benchmark stage
- `run_granularity.sh`: granularity/load-balancing benchmark stage
- `run_speedup.sh`: speedup benchmark stage
- `run_all_experiments.sh`: one-command synthetic benchmark orchestration
- `run_faiss_comparison.sh`: Phase 8 orchestration for sequential / parallel / FAISS comparison
- `cluster_n_node_common.sh`: shared helpers for the generic post-calibration N-node cluster bundle
- `run_cluster_n_node_bundle.sh`: generic post-calibration rerun wrapper for a prepared `rag-head + N workers` topology
- `cluster_common.sh`: shared helpers for the validated two-node cluster bundle and cluster postprocess flow
- `run_cluster_two_node_bundle.sh`: dedicated full-bundle rerun wrapper for the validated `rag-head + rag-worker1` topology
- `run_cluster_postprocess.sh`: cluster-only figure and analysis regeneration wrapper
  - supports both a full cluster result directory with FAISS artifacts and a no-FAISS cluster result directory where the report should mark FAISS as skipped
- `benchmark_csv.py`: run-summary aggregation and manifest helpers
- `analyze_benchmarks.py`: post-run benchmark interpretation, derived analysis tables, and report-ready summary generation
- `phase8_common.py`: shared binary-format and CSV helpers for the Phase 8 Python scripts
- `plot_results.py`: headless benchmark figure generation
- `requirements-benchmark.txt`: plotting dependency list for the benchmark venv
- `faiss_compare.py`: FAISS exact-flat comparison tool for already-prepared binary datasets
- `prepare_squad_minilm.py`: SQuAD parquet to normalized binary-vector conversion tool
- `requirements-faiss.txt`: minimal Phase 8 FAISS comparison dependency set
- `requirements-phase8.txt`: extended Phase 8 dependency set for real-corpus conversion

### `tools/`

Standalone helper binaries and utilities that are not part of the main retriever entrypoints.

- `generate_vectors.cpp`: deterministic synthetic memory-vector generator
- `generate_queries.cpp`: deterministic synthetic query-vector generator
- `inspect_dataset.cpp`: read-only binary header inspection tool
- `verify_results.cpp`: sequential-vs-parallel correctness-checking tool
- `SyntheticGeneratorCommon.hpp`: shared tool-only generator and parser helpers

### `data/`

Local generated datasets produced during development. This directory is kept in git only with a placeholder and should not contain committed large binaries.

### `results/`

Local CSVs, benchmark tables, and other generated outputs. Like `data/`, this stays mostly untracked.

Phase 8 also adds a nested `results/faiss/` artifact set for:

- FAISS top-k CSV outputs
- FAISS run-metrics CSV outputs
- FAISS correctness CSV outputs
- the final parallel-versus-FAISS comparison table

### `docs/development/`

Canonical technical docs:

- project specification
- data pipeline and benchmarks
- developer guide
- source guide
- master project plan

### `docs/usage/`

Canonical operational usage docs:

- WSL onboarding after clone
- copy-paste retrieval workflows
- benchmark script workflows
- troubleshooting and safe generated-state cleanup

### `docs/analysis/`

Canonical benchmark-interpretation docs:

- analysis entrypoint and artifact guide
- report-section mapping
- latest generated benchmark review

### `docs/plans/`

Execution plans and planning artifacts tied to dated work items.

## Build Targets

The current build introduces these targets:

- `retriever_core`
- `sequential_retriever`
- `parallel_retriever`
- `verify_results`
- `config_logger_test`
- `benchmark_metrics_test`
- `generate_vectors`
- `generate_queries`
- `inspect_dataset`
- `binary_dataset_test`
- `sequential_retriever_test`
- `parallel_retriever_test`
- `correctness_checker_test`

`retriever_core` is the shared internal layer. Later phases should prefer extending it instead of duplicating parsing or logging logic in individual binaries.

## Maintainability Rules

1. Shared logic belongs in `retriever_core`, not duplicated in each `main`.
2. New docs must use the refactored `docs/development`, `docs/usage`, and `docs/plans` paths.
3. WSL-first commands should be the default in docs and scripts.
4. Tool-only helpers should stay under `tools/` unless they become shared runtime code needed by retrievers and tests.
