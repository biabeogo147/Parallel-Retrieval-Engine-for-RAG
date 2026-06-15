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
```
