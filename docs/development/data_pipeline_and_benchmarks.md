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
2. Real-text corpora for external-baseline validation, report realism, and future preprocessing experiments.

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
3. Use this as the current real-corpus baseline path for Phase 8.
4. Convert it through `sentence-transformers/all-MiniLM-L6-v2` into the same binary contract already consumed by the retrievers.

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
| MS MARCO v1.1 | Later | Large real-text workload extension after the current baseline path is stable |
| UIT-ViQuAD2.0 | Later | Vietnamese extension corpus after the current English baseline path is stable |
| SQuAD | Yes | Current real-corpus baseline for Phase 8 FAISS comparison |
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

For the current implemented Phase 8 SQuAD path:

- memory side = unique train `context` strings
- query side = validation `question` strings
- embedding model = `sentence-transformers/all-MiniLM-L6-v2`
- output files = `vectors.bin`, `queries.bin`, `metadata.tsv`
- output vectors stay normalized row-major `float32`

## Initial Benchmark Matrix

### Synthetic Runs

- `D = 384`
- `k = 10`
- `Q = 100` for runtime tuning
- `Q = 500` remains an extended manual profile rather than the default automated Phase 7 run
- `N in {100k, 200k, 500k, 1M, 2M}`
- `5M` is a stretch goal

### Real-Text Runs

- SQuAD: current implemented real-corpus comparison path for Phase 8
- UIT-ViQuAD2.0: later Vietnamese extension after the SQuAD path is stable
- MS MARCO v1.1: later large-workload extension after the SQuAD path is stable

## What Counts as Ground Truth

For this project:

1. Retrieval correctness means sequential and parallel outputs match on the same vector inputs.
2. It does not require proving that a text dataset's annotated answer is the globally best semantic neighbor.

That distinction keeps the report honest and technically clean.

## Current Automation Profile

The current Phase 7 automation layer locks these defaults unless the caller overrides them with environment variables:

- `D = 384`
- base `Q = 100` for the initial `N` sweep
- `Q candidates = {150, 200, 250, 300, 400, 500, 600}` for fallback calibration
- `k = 10`
- `epsilon = 1e-5`
- `N candidates = {4M, 6M, 8M, 10M}`
- `speedup N candidates = {2M, 3M, 4M, 5M}`
- `speedup baseline limit = 600` seconds
- `P_SELECTED = detected physical core count`

On the current benchmark machine, the detected physical-core count is `10`, so the maintained final-rerun profile uses `P_SELECTED = 10`.

The automated flow now uses a two-stage calibration policy:

1. sweep `N` first at base `Q = 100`
2. if no `N` row lands inside the `120-180` second target window, keep the largest successful `N` and escalate `Q`
3. choose `N_SPEEDUP` separately from explicit sequential probes instead of forcing `2 * N_SELECTED`

This keeps the runtime target realistic on machines where memory capacity prevents an `N`-only sweep from reaching the desired runtime band.

Phase 8 keeps its FAISS comparison workflow separate from `run_all_experiments.sh`. That separation is intentional:

- `run_all_experiments.sh` remains the canonical synthetic benchmark automation entrypoint
- `run_faiss_comparison.sh` is the separate external-baseline workflow


---

# Dataset Pipeline

## Scope

Phase 2 introduced the synthetic vector pipeline first.

The current repository still treats synthetic vectors as the primary benchmark path, but it now also includes one narrow real-corpus extension in Phase 8:

- `SQuAD + sentence-transformers/all-MiniLM-L6-v2`

No broader real-text corpus family has been promoted into the maintained workflow yet.

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

### Calibration stage

Command:

```bash
bash scripts/run_calibrate_target.sh
```

`run_select_N.sh` is still present, but it now acts only as a compatibility wrapper that delegates to `run_calibrate_target.sh`.

Outputs:

- `results/runtime_by_N.csv`
- `results/benchmark_selection.env`

The `runtime_by_N.csv` schema is the same `RunMetricsRow` schema:

```text
N,D,Q,k,P,compute_time,communication_time,total_time
```

Selection rules:

1. run the initial `N` sweep at base `Q = 100` and canonical `P_SELECTED`
2. preserve all successful `N` rows even if a later larger `N` fails or runs out of memory
3. record `N_MAX_FEASIBLE` as the largest successful `N`
4. if any `N` row falls in `[120, 180]` seconds, choose the smallest such `N` and keep `Q = 100`
5. otherwise, fix `N_SELECTED = N_MAX_FEASIBLE` and run a fallback `Q` sweep
6. in the fallback `Q` sweep, choose the smallest `Q` inside `[120, 180]`; if none qualify, choose the row closest to `150` seconds
7. after `N_SELECTED` and `Q` are fixed, choose `N_SPEEDUP` separately from explicit sequential baseline probes, subject to the current `600` second baseline limit

The manifest `benchmark_selection.env` stores:

- `N_SELECTED`
- `N_SPEEDUP`
- `P_SELECTED`
- `D`
- `Q`
- `K`
- `EPSILON`
- `CALIBRATION_MODE`
- `N_MAX_FEASIBLE`

Interpretation rules:

- `N_SELECTED` is the canonical synthetic size for correctness, granularity, the synthetic FAISS comparison, and runtime-target reporting
- `N_SPEEDUP` is the explicit synthetic size chosen only for the speedup sweep
- `CALIBRATION_MODE = N_ONLY` means the initial `N` sweep reached the target window without changing `Q`
- `CALIBRATION_MODE = N_PLUS_Q` means `N` alone was insufficient on the current hardware, so the final runtime target used `Q` escalation
- `N_MAX_FEASIBLE` is the largest successful `N` observed before the first failed or omitted larger candidate

### Correctness stage

Command:

```bash
bash scripts/run_correctness.sh
```

Outputs:

- `results/sequential_topk.csv`
- `results/parallel_topk.csv`
- `results/correctness.csv`

This stage loads `benchmark_selection.env`, runs the canonical sequential and parallel retrieval commands, then calls `verify_results`. If the manifest is missing or still uses the older incomplete schema, the script regenerates it through the calibration stage first. The script fails immediately if `verify_results` does not return exit code `0`.

### Granularity stage

Command:

```bash
bash scripts/run_granularity.sh
```

Outputs:

- `results/granularity.csv`
- `results/granularity_summary.txt`

`granularity.csv` is just the per-rank metrics CSV from one canonical parallel run, promoted into the benchmark artifact set. The summary text reports whether the relative idle-time gap stays within the current `25%` balancing rule.

### Speedup stage

Command:

```bash
bash scripts/run_speedup.sh
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
bash scripts/run_all_experiments.sh
```

This orchestration script runs:

1. `run_calibrate_target.sh`
2. `run_correctness.sh`
3. `run_granularity.sh`
4. `run_speedup.sh`
5. `plot_results.py`

`run_select_N.sh` remains available as a compatibility wrapper, but the maintained stage-1 entrypoint is now `run_calibrate_target.sh`.

The plotting layer uses a repo-local `.venv/` plus `matplotlib` and runs headless through backend `Agg`.

Generated figures:

- `results/figures/runtime_by_N.png`
- `results/figures/granularity.png`
- `results/figures/speedup_runtime.png`
- `results/figures/speedup_curves.png`

## Phase 8 FAISS External Baseline Workflow

Phase 8 adds an external baseline experiment without changing the core retriever contract.

The baseline algorithm is fixed to:

- `faiss.IndexFlatIP`
- CPU only
- normalized row-major `float32` inputs
- no ANN mode
- no index training
- no GPU path

Because the vectors are normalized, inner product is interpreted as cosine-equivalent similarity for the current benchmark story.

### Synthetic Phase 8 path

The synthetic comparison reuses the existing binary datasets directly. No second vector-file format is introduced.

Typical command:

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

The resulting top-k CSV uses the same schema as the sequential and parallel retrievers:

```text
query_id,rank_position,memory_id,score
```

The correctness policy is also reused directly:

```bash
./build/debug/verify_results \
  --sequential results/sequential_topk.csv \
  --parallel results/faiss/synthetic_topk.csv \
  --epsilon 1e-5 \
  --output results/faiss/synthetic_correctness.csv
```

### Real-corpus Phase 8 path: SQuAD + MiniLM

The current maintained real-corpus conversion path is intentionally narrow.

Input root:

```text
/mnt/e/data/squad/plain_text
```

Expected raw files:

- `train-00000-of-00001.parquet`
- `validation-00000-of-00001.parquet`

Preparation command:

```bash
python3 ./scripts/prepare_squad_minilm.py \
  --input-dir /mnt/e/data/squad/plain_text \
  --output-dir .cache/real_corpora/squad_minilm \
  --model sentence-transformers/all-MiniLM-L6-v2 \
  --queries-limit 100
```

Conversion semantics:

- memory texts = unique train `context` strings
- query texts = validation `question` strings
- vectors are generated with `normalize_embeddings=True`
- output binary files remain compatible with:
  - `sequential_retriever`
  - `parallel_retriever`
  - `faiss_compare.py`

The output directory contains:

- `vectors.bin`
- `queries.bin`
- `metadata.tsv`

`metadata.tsv` is not consumed by the current retrievers. It exists so the converted corpus still preserves a readable mapping from `memory_id` to the original context text.

### Phase 8 orchestration script

The maintained command-first orchestration entrypoint is:

```bash
bash scripts/run_faiss_comparison.sh
```

This script:

1. loads a complete `results/benchmark_selection.env` or regenerates it through the calibration stage if the file is missing or stale
2. runs sequential retrieval on the selected synthetic dataset
3. runs parallel retrieval on the selected synthetic dataset
4. runs FAISS on the same synthetic dataset
5. verifies FAISS output against the sequential reference
6. prepares or reuses the SQuAD + MiniLM binary dataset
7. repeats sequential, parallel, FAISS, and correctness checks on that real-corpus dataset
8. aggregates the final comparison table under `results/faiss/comparison.csv`

### Phase 8 run-metrics schema

FAISS run metrics are written with this fixed schema:

```text
dataset_name,N,D,Q,k,threads,build_time,compute_time,total_time
```

Definitions:

- `dataset_name` = logical dataset label such as `synthetic` or `squad_minilm`
- `N` = memory-vector count
- `D` = vector dimension
- `Q` = query-vector count
- `k` = requested top-k
- `threads` = FAISS OpenMP thread count used through `faiss.omp_set_num_threads(...)`
- `build_time` = time spent adding vectors into `IndexFlatIP`
- `compute_time` = time spent in `IndexFlatIP.search(...)`
- `total_time` = current canonical FAISS timing for comparison; Phase 8 locks this equal to `compute_time`

### Phase 8 comparison table schema

The final FAISS comparison table is:

```text
dataset_name,N,D,Q,k,parallel_workers,faiss_threads,parallel_compute_time,parallel_communication_time,parallel_total_time,faiss_build_time,faiss_compute_time,faiss_total_time,total_ratio,correctness_status,max_score_diff
```

Definitions:

- `dataset_name` = `synthetic` or `squad_minilm`
- `parallel_workers` = MPI process count used by the project retriever
- `faiss_threads` = OpenMP thread count used by FAISS
- `parallel_compute_time` = Phase 6 parallel run-summary compute time
- `parallel_communication_time` = Phase 6 parallel run-summary communication time
- `parallel_total_time` = Phase 6 parallel run-summary total time
- `faiss_build_time` = FAISS index build time
- `faiss_compute_time` = FAISS search time
- `faiss_total_time` = canonical FAISS total time, currently equal to search time
- `total_ratio = parallel_total_time / faiss_total_time`
- `correctness_status` = `PASS` only when the corresponding correctness CSV is all pass rows
- `max_score_diff` = maximum value observed across the correctness CSV for that dataset

### Fair timing policy

Phase 8 keeps the fairness policy explicit.

Excluded from the canonical comparison window:

- text loading
- text embedding generation
- binary file loading
- CSV writing

Included but separated:

- FAISS `build_time`

Included in the canonical `total_time` comparison:

- sequential retrieval search window from Phase 6
- parallel retrieval search window from Phase 6
- FAISS `compute_time`

That policy is the reason `faiss_total_time` is currently locked equal to `faiss_compute_time` rather than `build_time + compute_time`.

### Phase 8 artifact layout

The Phase 8 workflow writes:

- `results/faiss/synthetic_topk.csv`
- `results/faiss/synthetic_run_metrics.csv`
- `results/faiss/synthetic_correctness.csv`
- `results/faiss/squad_topk.csv`
- `results/faiss/squad_run_metrics.csv`
- `results/faiss/squad_correctness.csv`
- `results/faiss/comparison.csv`

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

Use `/mnt/e/data` as the canonical root for larger external corpora and use `.cache/real_corpora/` for converted real-corpus binaries produced by the maintained Phase 8 workflow.

Typical WSL flow:

```bash
cd ~/work/Parallel-Retrieval-Engine-for-RAG
bash scripts/configure_debug.sh
cmake --build build/debug
ctest --test-dir build/debug --output-on-failure
./build/debug/generate_vectors --N 100000 --D 384 --output data/memory_vectors.bin
./build/debug/generate_queries --Q 100 --D 384 --output data/query_vectors.bin
./build/debug/inspect_dataset --input data/memory_vectors.bin
./build/debug/sequential_retriever --vectors data/memory_vectors.bin --queries data/query_vectors.bin --topk 10 --output results/sequential_topk.csv --run-metrics results/sequential_run_metrics.csv
mpirun -np 4 ./build/debug/parallel_retriever --vectors data/memory_vectors.bin --queries data/query_vectors.bin --topk 10 --output results/parallel_topk.csv --metrics results/parallel_metrics.csv --run-metrics results/parallel_run_metrics.csv
./build/debug/verify_results --sequential results/sequential_topk.csv --parallel results/parallel_topk.csv --epsilon 1e-5 --output results/correctness.csv
bash scripts/run_all_experiments.sh
bash scripts/run_faiss_comparison.sh
```

