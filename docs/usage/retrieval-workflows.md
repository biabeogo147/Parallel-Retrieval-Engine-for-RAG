# Retrieval Workflows

This guide covers the current synthetic pipeline from dataset generation through correctness verification.

All commands below assume:

```bash
cd ~/work/Parallel-Retrieval-Engine-for-RAG
```

If `id -u` prints `0`, OpenMPI blocks manual `mpirun` commands by default. In that temporary case, prefix manual MPI runs with:

```bash
OMPI_ALLOW_RUN_AS_ROOT=1 OMPI_ALLOW_RUN_AS_ROOT_CONFIRM=1
```

The benchmark scripts already handle this automatically for their own internal MPI invocations.

## 1. Check The CLI Surfaces

**Prerequisites**

- `build/debug/` has already been configured and built.

**Bash**

```bash
./build/debug/sequential_retriever --help
mpirun -np 4 ./build/debug/parallel_retriever --help
./build/debug/verify_results --help
./build/debug/generate_vectors --help
./build/debug/generate_queries --help
./build/debug/inspect_dataset --help
```

**Expected artifacts**

- No files are created.

**What success looks like**

- Each command exits `0`.
- Each tool prints usage text.

**Next step**

- Generate a small synthetic dataset.

## 2. Generate Synthetic Vectors

**Prerequisites**

- The generator binaries exist in `build/debug/`.

**Bash**

```bash
./build/debug/generate_vectors --N 64 --D 8 --output data/memory_vectors.bin
./build/debug/generate_queries --Q 5 --D 8 --output data/query_vectors.bin
```

**Expected artifacts**

- `data/memory_vectors.bin`
- `data/query_vectors.bin`

**What success looks like**

- Both commands exit `0`.
- The two binary files appear under `data/`.

**Next step**

- Inspect the generated header fields.

## 3. Inspect A Dataset Header

**Prerequisites**

- A dataset file already exists under `data/`.

**Bash**

```bash
./build/debug/inspect_dataset --input data/memory_vectors.bin
```

**Expected artifacts**

- No files are created.

**What success looks like**

- Output includes:
  - `magic = PMRAGV1`
  - `version = 1`
  - `flags = 3`
  - `num_vectors = 64`
  - `dimension = 8`

**Next step**

- Run the sequential retriever.

## 4. Run Exact Sequential Retrieval

**Prerequisites**

- `data/memory_vectors.bin` and `data/query_vectors.bin` exist.
- Their dimensions match.

**Bash**

```bash
./build/debug/sequential_retriever \
  --vectors data/memory_vectors.bin \
  --queries data/query_vectors.bin \
  --topk 3 \
  --output results/sequential_topk.csv
```

**Expected artifacts**

- `results/sequential_topk.csv`

**What success looks like**

- The CSV header is exactly:
  - `query_id,rank_position,memory_id,score`
- The file has `Q * k + 1` lines, so this small example produces `16` lines.

**Next step**

- Run the MPI path on the same inputs.

## 5. Run Exact Blocking MPI Retrieval

**Prerequisites**

- The same memory and query datasets used for the sequential run already exist.
- OpenMPI is installed inside Ubuntu WSL.

**Bash**

```bash
mpirun -np 4 ./build/debug/parallel_retriever \
  --vectors data/memory_vectors.bin \
  --queries data/query_vectors.bin \
  --topk 3 \
  --output results/parallel_topk.csv \
  --metrics results/parallel_metrics.csv
```

**Expected artifacts**

- `results/parallel_topk.csv`
- `results/parallel_metrics.csv`

**What success looks like**

- `parallel_topk.csv` uses the same header as the sequential path:
  - `query_id,rank_position,memory_id,score`
- `parallel_metrics.csv` uses:
  - `rank,local_N,compute_time,communication_time,active_time,global_total_time,idle_time`
- The small example produces `16` lines in `parallel_topk.csv` and `5` lines in `parallel_metrics.csv`.

**Next step**

- Verify correctness against the sequential output.

## 6. Verify Sequential Versus Parallel Correctness

**Prerequisites**

- `results/sequential_topk.csv` exists.
- `results/parallel_topk.csv` exists.

**Bash**

```bash
./build/debug/verify_results \
  --sequential results/sequential_topk.csv \
  --parallel results/parallel_topk.csv \
  --epsilon 1e-5 \
  --output results/correctness.csv
```

**Expected artifacts**

- `results/correctness.csv`

**What success looks like**

- The tool prints `All queries PASS`.
- `correctness.csv` uses:
  - `query_id,k,matched,matched_ids,max_score_diff,status`

**Next step**

- Read [results-csv-reference.md](results-csv-reference.md) if you want a detailed explanation of every output column, then add optional run-summary metrics or move to benchmark automation.

## 7. Optional Run-Summary Metrics

**Prerequisites**

- The normal sequential or parallel retrieval commands already work.

**Bash**

```bash
./build/debug/sequential_retriever \
  --vectors data/memory_vectors.bin \
  --queries data/query_vectors.bin \
  --topk 3 \
  --output results/sequential_topk.csv \
  --run-metrics results/sequential_run_metrics.csv

mpirun -np 4 ./build/debug/parallel_retriever \
  --vectors data/memory_vectors.bin \
  --queries data/query_vectors.bin \
  --topk 3 \
  --output results/parallel_topk.csv \
  --metrics results/parallel_metrics.csv \
  --run-metrics results/parallel_run_metrics.csv
```

**Expected artifacts**

- `results/sequential_run_metrics.csv`
- `results/parallel_run_metrics.csv`

**What success looks like**

- Both files use this exact header:
  - `N,D,Q,k,P,compute_time,communication_time,total_time`

**Next step**

- Continue to [results-csv-reference.md](results-csv-reference.md) for a detailed explanation of the run-summary CSV columns, or move directly to [benchmark-workflows.md](benchmark-workflows.md) if you want the full experiment pipeline.

## 8. Full Minimal Working Session

Use this when you want one copy-paste block that exercises the whole current synthetic retrieval path:

**Prerequisites**

- Toolchain setup, debug configure, and build are already complete.

**Bash**

```bash
cd ~/work/Parallel-Retrieval-Engine-for-RAG
./build/debug/generate_vectors --N 64 --D 8 --output data/memory_vectors.bin
./build/debug/generate_queries --Q 5 --D 8 --output data/query_vectors.bin
./build/debug/inspect_dataset --input data/memory_vectors.bin
./build/debug/sequential_retriever \
  --vectors data/memory_vectors.bin \
  --queries data/query_vectors.bin \
  --topk 3 \
  --output results/sequential_topk.csv
mpirun -np 4 ./build/debug/parallel_retriever \
  --vectors data/memory_vectors.bin \
  --queries data/query_vectors.bin \
  --topk 3 \
  --output results/parallel_topk.csv \
  --metrics results/parallel_metrics.csv
./build/debug/verify_results \
  --sequential results/sequential_topk.csv \
  --parallel results/parallel_topk.csv \
  --epsilon 1e-5 \
  --output results/correctness.csv
```

**Expected artifacts**

- `data/memory_vectors.bin`
- `data/query_vectors.bin`
- `results/sequential_topk.csv`
- `results/parallel_topk.csv`
- `results/parallel_metrics.csv`
- `results/correctness.csv`

**What success looks like**

- `verify_results` prints `All queries PASS`.

**Next step**

- Use [results-csv-reference.md](results-csv-reference.md) to interpret the generated CSVs, then try larger dimensions and dataset sizes or run the full benchmark automation.
