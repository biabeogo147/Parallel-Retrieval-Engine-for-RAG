# Algorithm Design

## Design Goal

Implement a deterministic, exact, MPI-based top-k retriever whose output can be compared directly against a sequential baseline.

## Version 1 Design Summary

Version 1 uses:

1. Sequential scan for the baseline.
2. Static 1D contiguous block decomposition for the parallel path.
3. Blocking collectives for clarity and reproducibility.
4. Rank 0 merge of local top-k candidate lists.

This is intentionally simple. It minimizes moving parts in the first implementation and makes correctness easier to prove.

## Data Model

### Memory Record

```text
memory_id: uint64
embedding: float32[D]
metadata_text: stored separately in metadata.tsv when needed
```

### Query Record

```text
query_id: uint64
embedding: float32[D]
```

## Binary Dataset Format

The project will use a slightly richer header than the original draft so the file is self-describing and easier to inspect.

### Header Layout

```text
magic[8]      = "PMRAGV1"
version       = uint32 = 1
flags         = uint32
num_vectors   = uint64
dimension     = uint32
reserved0     = uint32
```

### Flags

- bit 0: vectors are L2-normalized
- bit 1: data is row-major

### Data Layout

```text
float32 vectors[num_vectors][dimension]
```

### Contract

1. Little-endian layout.
2. Dense row-major storage.
3. No text metadata embedded in the binary file.
4. Optional `metadata.tsv` stores `memory_id<TAB>memory_text`.

## Similarity Function

All vectors should be normalized during dataset creation or preprocessing. With normalized vectors:

```text
score(q, v) = dot(q, v)
```

This keeps the runtime kernel simple and predictable.

## Sequential Baseline

### Purpose

1. Produce the ground-truth exact result.
2. Act as the speedup denominator.
3. Catch merge or communication bugs in the parallel path.

### Pseudocode

```text
for each query q:
    create min-heap H with capacity k
    for memory_id in [0, N):
        score = dot(q, V[memory_id])
        if H.size < k:
            push (memory_id, score)
        else if score > H.min_score:
            pop min
            push (memory_id, score)
        else if score == H.min_score and memory_id < H.min_memory_id:
            pop min
            push (memory_id, score)
    sort H by score descending, memory_id ascending
    emit result row(s)
```

## Parallel Retrieval Design

## Shard Assignment

For `N` vectors and `P` MPI ranks:

```text
base = N / P
rem  = N % P

local_N(rank) = base + 1, if rank < rem
local_N(rank) = base,     otherwise

start(rank) = rank * base + min(rank, rem)
end(rank)   = start(rank) + local_N(rank)
```

This guarantees balanced shards when `N` is not divisible by `P`.

## Communication Pattern

For each query:

1. Rank 0 loads or owns the query vector.
2. Rank 0 broadcasts the query vector to all ranks.
3. Each rank computes local top-k on its shard.
4. Each rank packs its local candidates into a flat array.
5. Rank 0 gathers all local candidate arrays.
6. Rank 0 merges `P * k` candidates into the global top-k.
7. Rank 0 writes the final results and metrics.

## Why Contiguous 1D Blocks

This is the best Phase 1-4 default because:

1. The full dot product stays local to each rank.
2. There is no partial-score reduction across ranks.
3. The communication volume is small: only query vectors and local top-k candidates move.
4. The load is naturally balanced for dense fixed-width vectors.

Block-cyclic and dynamic scheduling remain fallback options if measurements later show imbalance.

## Global Merge Contract

Each candidate is ordered by:

1. Higher score first.
2. Lower `memory_id` first on ties.

This same rule must be used in:

1. Local heap maintenance.
2. Local result sorting.
3. Rank 0 global merge.
4. Correctness checker.

## Determinism and Correctness

The project uses exact search, so correctness means:

1. Parallel and sequential top-k IDs match for every query.
2. Score differences remain within `epsilon`.

Recommended epsilon:

```text
1e-5
```

## Metrics to Record

Per run:

- `compute_time`
- `communication_time`
- `total_time`

Per rank:

- `rank`
- `local_N`
- `compute_time`
- `communication_time`
- `active_time`
- `global_total_time`
- `idle_time`

Definitions:

```text
active_time = compute_time + communication_time
idle_time   = global_total_time - active_time
```

## CSV Contracts

### Top-k Output

Suggested schema:

```csv
query_id,rank_position,memory_id,score
0,1,12345,0.892341
```

### Correctness Output

```csv
query_id,k,matched,matched_ids,max_score_diff,status
0,10,true,10,0.000001,PASS
```

### Runtime by N

```csv
N,D,Q,k,P,compute_time,total_communication_time,total_time
100000,384,100,10,8,12.4,0.8,13.2
```

### Granularity

```csv
rank,local_N,compute_time,communication_time,active_time,global_total_time,idle_time
0,125000,35.2,1.8,37.0,37.5,0.5
```

### Speedup

```csv
N,D,Q,k,P,compute_time,communication_time,total_time,compute_speedup,total_speedup,compute_efficiency,total_efficiency
2000000,384,100,10,8,40.0,1.9,41.9,7.10,6.87,0.89,0.86
```

## Initial Benchmark Modes

1. `synthetic-runtime`: generated normalized float32 vectors for speedup and granularity.
2. `realtext-demo`: text-backed vectors plus metadata for qualitative inspection.
3. `correctness`: sequential versus parallel on the same binary vector input.

## Deferred Design Choices

These are intentionally not part of Version 1:

1. Non-blocking collectives.
2. Query-batch parallelism as a first-class mode.
3. ANN indexes.
4. Embedded metadata in the binary file.
5. Two-dimensional decomposition.
