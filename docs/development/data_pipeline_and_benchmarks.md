# Data Pipeline And Benchmarks

This file merges the former `benchmark_data.md` and `dataset_pipeline.md` without shortening their content.

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
- `Q = 500` for standard benchmark runs
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

This is now the canonical ID contract for sequential output, parallel output, and future correctness comparison tooling.

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
./build/debug/sequential_retriever --vectors data/memory_vectors.bin --queries data/query_vectors.bin --topk 10 --output results/sequential_topk.csv
mpirun -np 4 ./build/debug/parallel_retriever --vectors data/memory_vectors.bin --queries data/query_vectors.bin --topk 10 --output results/parallel_topk.csv --metrics results/parallel_metrics.csv
```

