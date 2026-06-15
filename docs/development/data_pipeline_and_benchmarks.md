# Data Pipeline And Benchmarks

This file merges the former `benchmark_data.md` and `dataset_pipeline.md` without shortening their content.

For command-first execution steps, stage-by-stage benchmark script usage, and copy-paste WSL flows, start with `../usage/benchmark-workflows.md`. This guide remains the contract and policy reference for dataset and benchmark behavior.

## Included Documents

- `benchmark_data.md`
- `dataset_pipeline.md`

---

# Benchmark Data Strategy

## Guiding Principle

The project needs two different data categories:

1. Controlled vector benchmarks for exact speedup and correctness.
2. Real-text corpora for realism, demos, and future preprocessing experiments.

These should not be mixed into a single benchmark story.

## Storage Assumption

The host machine stores datasets under:

```text
E:\data
```

Inside WSL2, the same location is available at:

```text
/mnt/e/data
```

## Final Dataset Choices

### 1. Primary Benchmark Dataset: Synthetic Normalized Vectors

Use a local generator to create:

- `memory_vectors.bin`
- `query_vectors.bin`

Why this is the primary benchmark:

1. `N`, `D`, and `Q` are fully controllable.
2. Correctness is easy to isolate from text preprocessing noise.
3. Speedup and load-balance measurements stay focused on the retrieval kernel.
4. It lets us tune runtime to the target 2-3 minute window.

### 2. Large Real-Text Workload: MS MARCO v1.1

Observed local dataset facts:

- path: `E:\data\ms_marco\v1.1`
- queries in train split: `82,326`
- total flattened passages in train split: `676,193`
- average passages per query: `8.21`

Recommended role:

- Use this as a large workload corpus after the basic pipeline is stable.
- Flatten each passage into one memory record.
- Use query text as the query side.

Important note:

MS MARCO v1.1 is not the cleanest global-memory benchmark because its passage lists are query-associated. It is excellent for workload size, but not ideal as the single source of semantic correctness claims.

### 3. Vietnamese Demo Corpus: UIT-ViQuAD2.0

Observed local dataset facts:

- path: `E:\data\UIT-ViQuAD2.0\data`
- train rows: `28,454`
- unique train contexts: `4,101`
- validation rows: `3,814`
- train impossible questions: `9,216`

Recommended role:

1. Use unique `context` strings as memory items.
2. Use `question` as query text.
3. Filter `is_impossible = false` for positive retrieval demos.
4. Keep impossible questions as optional negative-case tests.

Why it is valuable:

1. Vietnamese language support matches the project's likely demo audience.
2. The corpus is small enough to preprocess quickly.
3. The impossible-question field gives a clean negative-test extension.

### 4. Clean English QA Corpus: SQuAD

Observed local dataset facts:

- path: `E:\data\squad\plain_text`
- train rows: `87,599`
- unique train contexts: `18,891`
- validation rows: `10,570`

Recommended role:

1. Use unique `context` strings as memory items.
2. Use `question` as query text.
3. Use this as a clean English reference corpus for demos or smoke tests.

Why it is not the primary benchmark:

It is cleaner than MS MARCO, but much smaller than the synthetic target sizes required for parallel speedup evaluation.

### 5. Deferred Domain Corpus: Vietnamese Legal QA

Observed local dataset facts:

- path: `E:\data\vietnamese-legal-qa\data`
- documents: `9,715`
- near-unique article texts: `9,582`
- generated QA pairs: `29,145`
- average article length: about `2,279` characters

Recommended role:

- Keep this for a later domain-specific demo.
- Do not use it in the first benchmark wave because it introduces chunking decisions too early.

## Dataset Selection Summary

| Dataset | Use now | Role |
| --- | --- | --- |
| Synthetic generator | Yes | Main correctness, runtime, granularity, and speedup benchmark |
| MS MARCO v1.1 | Yes, after core pipeline works | Large real-text workload benchmark |
| UIT-ViQuAD2.0 | Yes | Main Vietnamese demo corpus |
| SQuAD | Yes | Clean English demo and smoke corpus |
| Vietnamese Legal QA | Later | Domain-specific extension |
| MS MARCO v2.1 | Later | Scale-up experiment after v1 is stable |

## Conversion Rules for Real-Text Corpora

### General Rule

The retriever always consumes vectors, not raw text. Text datasets therefore need a preprocessing layer that outputs:

1. `memory_vectors.bin`
2. `query_vectors.bin`
3. `metadata.tsv`

### SQuAD and UIT-ViQuAD2.0

- `memory_id` = stable integer assigned to each unique context
- `memory_text` = context text
- `query_id` = stable integer assigned to each question
- `query_text` = question text

### MS MARCO v1.1

- `memory_id` = stable integer assigned to each flattened passage row
- `memory_text` = passage text
- `query_id` = source query id
- `query_text` = source query

For Phase 0 through Phase 4, deduplication is not required. Simplicity matters more than corpus purity.

## Initial Benchmark Matrix

### Synthetic Runs

- `D = 384`
- `k = 10`
- `Q = 100` for runtime tuning
- `Q = 500` remains an extended manual profile rather than the default automated Phase 7 run
- `N in {100k, 200k, 500k, 1M, 2M}`
- `5M` is a stretch goal

### Real-Text Runs

- UIT-ViQuAD2.0: use all unique contexts for demo and qualitative retrieval
- SQuAD: use all unique contexts for smoke and cross-language sanity checks
- MS MARCO v1.1: start with subsets, then scale toward the full flattened train passages

## What Counts as Ground Truth

For this project:

1. Retrieval correctness means sequential and parallel outputs match on the same vector inputs.
2. It does not require proving that a text dataset's annotated answer is the globally best semantic neighbor.

That distinction keeps the report honest and technically clean.

## Current Automation Profile

The current Phase 7 automation layer locks these defaults unless the caller overrides them with environment variables:

- `D = 384`
- `Q = 100`
- `k = 10`
- `epsilon = 1e-5`
- `N candidates = {100k, 200k, 500k, 1M, 2M}`

The automated `run_all_experiments.sh` flow intentionally uses `Q = 100` instead of `Q = 500` so the runtime-selection and speedup pipeline stays inside a practical WSL development window.


---

# Dataset Pipeline

## Scope

Phase 2 adds the synthetic vector pipeline only. It does not convert real-text corpora yet.

The goals of this stage are:

- deterministic synthetic vector generation
- a stable binary dataset contract
- shard-aware loading for future MPI retrieval work
- a small inspection tool for debugging and verification

## Binary Header Contract

Binary datasets use this fixed little-endian header:

```text
magic[8]    = "PMRAGV1"
version     = uint32 = 1
flags       = uint32
num_vectors = uint64
dimension   = uint32
reserved0   = uint32
```

Payload layout:

```text
float32[num_vectors][dimension]
```

The payload is always dense row-major `float32`.

### Flags

- bit `0`: vectors are L2-normalized
- bit `1`: payload is row-major

Phase 2 generators always set both flags, so the expected header flag value is `3`.

## Core Interfaces

Shared dataset IO lives in `retriever_core` through `BinaryDataset`.

Available interfaces:

- `BinaryDatasetHeader`
- `BinaryDatasetContents`
- `BinaryDatasetShard`
- `ShardBounds`
- `BinaryDataset::write(...)`
- `BinaryDataset::read_header(...)`
- `BinaryDataset::read_all(...)`
- `BinaryDataset::read_shard(...)`
- `BinaryDataset::compute_shard_bounds(...)`

Validation currently rejects:

- invalid magic
- invalid version
- zero dimension
- truncated payloads
- file sizes inconsistent with header metadata

## Generator Commands

Memory-vector generator:

```bash
./build/debug/generate_vectors --N 100000 --D 384 --output data/memory_vectors.bin
```

Query-vector generator:

```bash
./build/debug/generate_queries --Q 100 --D 384 --output data/query_vectors.bin
```

Optional seed override:

```bash
--seed <uint64>
```

Default seed:

```text
12345
```

## Deterministic Generation Behavior

Phase 2 uses a deterministic normal sampler built from raw `mt19937_64` output plus a Box-Muller transform. This avoids leaving the exact sample stream up to `std::normal_distribution` implementation details.

Each generated vector is then L2-normalized before being written to disk as `float32`.

Practical implications:

- same tool + same seed + same arguments => byte-identical output
- different seed => different payload
- Phase 3 can assume vectors are already normalized

## Phase 3 and Phase 4 Retrieval Preconditions

The current exact sequential and blocking MPI retrievers consume these binary files directly with no extra preprocessing stage in between. They require:

- memory and query datasets to have the same `dimension`
- the normalized flag to be present on both datasets
- the row-major flag to be present on both datasets
- `topk >= 1`
- `topk <= num_vectors` for the memory dataset

If any of those conditions fail, the retriever exits non-zero with a clear `Error: ...` message instead of silently continuing.

## Row-Index ID Convention

Phase 3 defines identifiers directly from row position because the binary vector files do not store explicit IDs:

- `query_id` = zero-based row index in `query_vectors.bin`
- `memory_id` = zero-based row index in `memory_vectors.bin`

This is now the canonical ID contract for sequential output, parallel output, and the current `verify_results` correctness-comparison tool.

## Phase 3 Sequential Output

Exact sequential retrieval writes one CSV row per returned candidate using this fixed schema:

```text
query_id,rank_position,memory_id,score
```

Rules:

- `rank_position` is one-based inside each query's local top-k list
- scores are written with `std::fixed` and `std::setprecision(8)`
- ordering is deterministic:
  - higher score first
  - if scores tie, lower `memory_id` first

Typical WSL command:

```bash
./build/debug/sequential_retriever \
  --vectors data/memory_vectors.bin \
  --queries data/query_vectors.bin \
  --topk 10 \
  --output results/sequential_topk.csv
```

## Phase 4 Parallel Output

Blocking MPI retrieval writes the same top-k CSV schema as the sequential path:

```text
query_id,rank_position,memory_id,score
```

The ordering contract stays identical:

- higher score first
- lower `memory_id` first on ties

Typical WSL command:

```bash
mpirun -np 4 ./build/debug/parallel_retriever \
  --vectors data/memory_vectors.bin \
  --queries data/query_vectors.bin \
  --topk 10 \
  --output results/parallel_topk.csv \
  --metrics results/parallel_metrics.csv
```

Phase 4 also locks the per-rank metrics CSV schema to:

```text
rank,local_N,compute_time,communication_time,active_time,global_total_time,idle_time
```

Definitions:

- `local_N` = number of memory rows assigned to that rank by the shard formula
- `compute_time` = total local-search time for that rank; rank `0` also includes global merge time
- `communication_time` = total time spent in query broadcasts and fixed-size candidate gathers
- `active_time = compute_time + communication_time`
- `global_total_time` = maximum retrieval-loop wall time across ranks for that invocation
- `idle_time = global_total_time - active_time`

## Phase 5 Correctness Output

Phase 5 adds a dedicated comparison tool that checks whether sequential and parallel retrieval produced the same ranked IDs and sufficiently close scores on the same vector inputs.

Command shape:

```bash
./build/debug/verify_results \
  --sequential results/sequential_topk.csv \
  --parallel results/parallel_topk.csv \
  --epsilon 1e-5 \
  --output results/correctness.csv
```

The correctness CSV schema is now fixed to:

```text
query_id,k,matched,matched_ids,max_score_diff,status
```

Definitions:

- `query_id` = zero-based query row index
- `k` = expected number of ranked rows for that query in each input CSV
- `matched` = `true` when the query passes the correctness check, otherwise `false`
- `matched_ids` = number of positions where sequential and parallel have the same `memory_id` at the same `rank_position`
- `max_score_diff` = maximum absolute score difference across aligned ranks in that query
- `status` = `PASS` when `matched_ids == k` and `max_score_diff <= epsilon`, otherwise `FAIL`

Validation rules enforced by the tool:

- both input headers must exactly equal `query_id,rank_position,memory_id,score`
- each query must contain contiguous `rank_position` values from `1..k`
- duplicate `(query_id, rank_position)` pairs are rejected
- the `query_id` set must match across both inputs
- `k` must be consistent across queries and across both files

Exit semantics:

- `0` = all queries pass
- `1` = comparison completed and at least one query failed
- `2` = invalid CLI arguments, malformed CSV input, or runtime error

## Phase 6 Run-Summary Metrics Output

Phase 6 extends both retriever binaries with an optional benchmark-summary CSV path:

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

The run-summary CSV schema is fixed to:

```text
N,D,Q,k,P,compute_time,communication_time,total_time
```

Definitions:

- `N` = number of memory vectors in the retrieval run
- `D` = vector dimension
- `Q` = number of query vectors in the retrieval run
- `k` = requested top-k
- `P` = process count used for that invocation
- `compute_time` = pure retrieval-kernel time
- `communication_time` = time spent in MPI communication; sequential rows always write `0`
- `total_time` = benchmark timing window used for later speedup calculations

Sequential summary semantics:

- `P = 1`
- `communication_time = 0`
- `compute_time` and `total_time` both measure the exact local-search window, excluding dataset load and CSV writing

Parallel summary semantics:

- `compute_time = max(compute_time)` across rank rows
- `communication_time = max(communication_time)` across rank rows
- `total_time = global_total_time`
- the summary intentionally reuses the same benchmark window as Phase 4 per-rank metrics, excluding dataset load and CSV writing

These one-row summary files are the canonical inputs for Phase 7 aggregation and speedup calculations.

## Phase 7 Experiment Automation

Phase 7 turns the synthetic benchmark workflow into a reproducible WSL-first script layer.

### Shared environment and helper layer

The benchmark scripts share `scripts/benchmark_common.sh`, which is responsible for:

- checking required commands
- detecting physical core count
- generating a default `BENCH_P_LIST`
- creating benchmark scratch and output folders
- handling root-safe `mpirun` invocation for temporary WSL setups
- generating or reusing synthetic query and memory datasets

The main environment variables are:

- `BENCH_D`
- `BENCH_Q`
- `BENCH_TOPK`
- `BENCH_EPSILON`
- `BENCH_N_CANDIDATES`
- `BENCH_P_SELECTED`
- `BENCH_P_LIST`
- `BENCH_BUILD_DIR`
- `BENCH_RESULTS_DIR`
- `BENCH_SCRATCH_DIR`

Default values:

```text
BENCH_D=384
BENCH_Q=100
BENCH_TOPK=10
BENCH_EPSILON=1e-5
BENCH_N_CANDIDATES="100000 200000 500000 1000000 2000000"
BENCH_P_LIST="1 2 4 8 ... X 2X"
```

Here `X` means the detected physical core count inside WSL. The scripts keep `BENCH_P_SELECTED` separate from `BENCH_P_LIST` so correctness and granularity can use one canonical process count even when the speedup sweep uses multiple `P` values.

### Runtime-by-N selection stage

Command:

```bash
bash ./scripts/run_select_N.sh
```

Outputs:

- `results/runtime_by_N.csv`
- `results/benchmark_selection.env`

The `runtime_by_N.csv` schema is the same `RunMetricsRow` schema:

```text
N,D,Q,k,P,compute_time,communication_time,total_time
```

Selection rule:

- choose the smallest `N` whose `total_time` is within `[120, 180]` seconds
- if no row falls in that range, choose the row with minimum `abs(total_time - 150)`

The manifest `benchmark_selection.env` stores:

- `N_SELECTED`
- `N_SPEEDUP`
- `P_SELECTED`
- `D`
- `Q`
- `K`
- `EPSILON`

`N_SPEEDUP` is fixed to `2 * N_SELECTED`.

### Correctness stage

Command:

```bash
bash ./scripts/run_correctness.sh
```

Outputs:

- `results/sequential_topk.csv`
- `results/parallel_topk.csv`
- `results/correctness.csv`

This stage loads `benchmark_selection.env`, runs the canonical sequential and parallel retrieval commands, then calls `verify_results`. The script fails immediately if `verify_results` does not return exit code `0`.

### Granularity stage

Command:

```bash
bash ./scripts/run_granularity.sh
```

Outputs:

- `results/granularity.csv`
- `results/granularity_summary.txt`

`granularity.csv` is just the per-rank metrics CSV from one canonical parallel run, promoted into the benchmark artifact set. The summary text reports whether the relative idle-time gap stays within the current `25%` balancing rule.

### Speedup stage

Command:

```bash
bash ./scripts/run_speedup.sh
```

Outputs:

- `results/speedup.csv`

Schema:

```text
N,D,Q,k,P,compute_time,communication_time,total_time,compute_speedup,total_speedup,compute_efficiency,total_efficiency
```

Rules:

- the `P = 1` baseline row comes from `sequential_retriever --run-metrics`
- parallel rows come from `parallel_retriever --run-metrics`
- rows are sorted by `P`
- `compute_speedup = seq.compute_time / row.compute_time`
- `total_speedup = seq.total_time / row.total_time`
- efficiency values are speedup divided by `P`

### All-in-one automation and figures

Command:

```bash
bash ./scripts/run_all_experiments.sh
```

This orchestration script runs:

1. `run_select_N.sh`
2. `run_correctness.sh`
3. `run_granularity.sh`
4. `run_speedup.sh`
5. `plot_results.py`

The plotting layer uses a repo-local `.venv/` plus `matplotlib` and runs headless through backend `Agg`.

Generated figures:

- `results/figures/runtime_by_N.png`
- `results/figures/granularity.png`
- `results/figures/speedup_runtime.png`
- `results/figures/speedup_curves.png`

## Inspection Tool

Inspect a dataset header without mutating it:

```bash
./build/debug/inspect_dataset --input data/memory_vectors.bin
```

Expected output includes:

```text
magic = PMRAGV1
version = 1
flags = 3
num_vectors = 100000
dimension = 384
```

## Shard Semantics

Shard assignment is defined once in the dataset layer so later MPI code does not have to re-decide it.

For `N` vectors and `P` ranks:

```text
base = N / P
rem  = N % P

count(rank) = base + 1, if rank < rem
count(rank) = base,     otherwise

start(rank) = rank * base + min(rank, rem)
```

`BinaryDataset::read_shard(...)` returns:

- validated header
- `ShardBounds { start_index, count }`
- one contiguous local `float32` slice for that rank

Phase 3 uses row-major full reads through `BinaryDataset::read_all(...)`.
Phase 4 uses `BinaryDataset::read_shard(...)` for the memory database and `BinaryDataset::read_all(...)` on rank `0` for queries.
The shard contract remains important because the current MPI path already depends on this exact decomposition and later benchmark phases should not invent a second shard policy.

## WSL Usage Notes

Use the repo-local `data/` directory for synthetic outputs produced by this phase.

Use `/mnt/e/data` as the canonical root for larger external corpora and converted benchmark datasets added in later phases.

Typical WSL flow:

```bash
cd ~/work/Parallel-Retrieval-Engine-for-RAG
./scripts/configure_debug.sh
cmake --build build/debug
ctest --test-dir build/debug --output-on-failure
./build/debug/generate_vectors --N 100000 --D 384 --output data/memory_vectors.bin
./build/debug/generate_queries --Q 100 --D 384 --output data/query_vectors.bin
./build/debug/inspect_dataset --input data/memory_vectors.bin
./build/debug/sequential_retriever --vectors data/memory_vectors.bin --queries data/query_vectors.bin --topk 10 --output results/sequential_topk.csv --run-metrics results/sequential_run_metrics.csv
mpirun -np 4 ./build/debug/parallel_retriever --vectors data/memory_vectors.bin --queries data/query_vectors.bin --topk 10 --output results/parallel_topk.csv --metrics results/parallel_metrics.csv --run-metrics results/parallel_run_metrics.csv
./build/debug/verify_results --sequential results/sequential_topk.csv --parallel results/parallel_topk.csv --epsilon 1e-5 --output results/correctness.csv
bash ./scripts/run_all_experiments.sh
```

