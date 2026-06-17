# Cluster Runbook

This runbook is the repeatable day-to-day operating flow after the cluster has already passed the initial assembly and validation steps.

All commands below run from the head node unless a section explicitly says otherwise.

The examples assume:

- canonical repo path: `~/work/Parallel-Retrieval-Engine-for-RAG`
- authoritative shared-data path: `~/cluster-shared/parallel-rag-data`
- worker hosts: `rag-worker1`, `rag-worker2`
- Linux username: `rag`
- hostfile: `.cache/cluster/hosts.cluster`
- example slot budget: `4` per node, which implies `-np 12` total

If your nodes use different slot counts, update both the hostfile and the `-np` values below.

## 1. Reconfirm Cluster Readiness

**Prerequisites**

- The three-machine cluster already passed [cluster-assembly-and-validation.md](cluster-assembly-and-validation.md).

**Bash**

```bash
cd ~/work/Parallel-Retrieval-Engine-for-RAG
ssh rag@rag-worker1 'cd ~/work/Parallel-Retrieval-Engine-for-RAG && hostname && test -x ./build/release/parallel_retriever'
ssh rag@rag-worker2 'cd ~/work/Parallel-Retrieval-Engine-for-RAG && hostname && test -x ./build/release/parallel_retriever'
```

**Expected artifacts**

- None. This is a readiness check.

**What success looks like**

- Both workers respond and already have release binaries.

**Next step**

- Refresh the release build on every node when needed.

## 2. Refresh The Release Build On Every Node

Run this when the repo changed or when you want to ensure all nodes use the same binary revision.

**Prerequisites**

- SSH from the head node to both workers already works without passwords.

**Bash**

```bash
cd ~/work/Parallel-Retrieval-Engine-for-RAG
./scripts/configure_release.sh
cmake --build build/release
ssh rag@rag-worker1 'cd ~/work/Parallel-Retrieval-Engine-for-RAG && ./scripts/configure_release.sh && cmake --build build/release'
ssh rag@rag-worker2 'cd ~/work/Parallel-Retrieval-Engine-for-RAG && ./scripts/configure_release.sh && cmake --build build/release'
```

**Expected artifacts**

- Up-to-date release binaries on all three nodes.

**What success looks like**

- All three build commands complete without error.

**Next step**

- Create or refresh the authoritative synthetic datasets on the head node.

## 3. Create Or Refresh The Authoritative Synthetic Datasets

This runbook keeps one authoritative dataset copy on the head node, then synchronizes that copy into repo-local `data/` directories.

**Prerequisites**

- Release generator binaries exist on the head node.

**Bash**

```bash
cd ~/work/Parallel-Retrieval-Engine-for-RAG
mkdir -p ~/cluster-shared/parallel-rag-data
./build/release/generate_vectors --N 100000 --D 384 --output ~/cluster-shared/parallel-rag-data/memory_vectors.bin
./build/release/generate_queries --Q 100 --D 384 --output ~/cluster-shared/parallel-rag-data/query_vectors.bin
./build/release/inspect_dataset --input ~/cluster-shared/parallel-rag-data/memory_vectors.bin
./build/release/inspect_dataset --input ~/cluster-shared/parallel-rag-data/query_vectors.bin
```

Replace `N`, `D`, and `Q` with the sizes you actually want to run.

**Expected artifacts**

- `~/cluster-shared/parallel-rag-data/memory_vectors.bin`
- `~/cluster-shared/parallel-rag-data/query_vectors.bin`

**What success looks like**

- Both files exist and inspect cleanly.

**Next step**

- Synchronize the authoritative data into the local repo `data/` directory on every node.

## 4. Sync Runtime Datasets To Every Node

**Prerequisites**

- The authoritative head-node datasets already exist.

**Bash**

```bash
cd ~/work/Parallel-Retrieval-Engine-for-RAG
mkdir -p data results
cp ~/cluster-shared/parallel-rag-data/memory_vectors.bin data/memory_vectors.bin
cp ~/cluster-shared/parallel-rag-data/query_vectors.bin data/query_vectors.bin
rsync -av ~/cluster-shared/parallel-rag-data/memory_vectors.bin rag@rag-worker1:~/work/Parallel-Retrieval-Engine-for-RAG/data/
rsync -av ~/cluster-shared/parallel-rag-data/query_vectors.bin rag@rag-worker1:~/work/Parallel-Retrieval-Engine-for-RAG/data/
rsync -av ~/cluster-shared/parallel-rag-data/memory_vectors.bin rag@rag-worker2:~/work/Parallel-Retrieval-Engine-for-RAG/data/
rsync -av ~/cluster-shared/parallel-rag-data/query_vectors.bin rag@rag-worker2:~/work/Parallel-Retrieval-Engine-for-RAG/data/
```

**Expected artifacts**

- `data/memory_vectors.bin`
- `data/query_vectors.bin`

on all three nodes.

**What success looks like**

- Every node now has the same runtime input files in its local repo.

**Next step**

- Run the real multi-node parallel retrieval command.

## 5. Run Multi-Node Parallel Retrieval

The example below assumes `4` slots per node in the hostfile, for a total of `12` ranks.

**Prerequisites**

- The hostfile exists at `.cache/cluster/hosts.cluster`.
- Runtime input datasets exist under `data/` on every node.
- The release binary paths match on all nodes.

**Bash**

```bash
cd ~/work/Parallel-Retrieval-Engine-for-RAG
mpirun --hostfile .cache/cluster/hosts.cluster -np 12 ./build/release/parallel_retriever \
  --vectors data/memory_vectors.bin \
  --queries data/query_vectors.bin \
  --topk 10 \
  --output results/parallel_topk.csv \
  --metrics results/parallel_metrics.csv \
  --run-metrics results/parallel_run_metrics.csv
```

**Expected artifacts**

- `results/parallel_topk.csv`
- `results/parallel_metrics.csv`
- `results/parallel_run_metrics.csv`

**What success looks like**

- All output files are written on the head node.
- `parallel_topk.csv` and `parallel_metrics.csv` use the canonical schemas.

**Next step**

- Run the sequential comparison on the head node using the same local inputs.

## 6. Run The Sequential Comparison On The Head Node

**Prerequisites**

- The same `data/memory_vectors.bin` and `data/query_vectors.bin` exist on the head node.

**Bash**

```bash
cd ~/work/Parallel-Retrieval-Engine-for-RAG
./build/release/sequential_retriever \
  --vectors data/memory_vectors.bin \
  --queries data/query_vectors.bin \
  --topk 10 \
  --output results/sequential_topk.csv \
  --run-metrics results/sequential_run_metrics.csv
```

**Expected artifacts**

- `results/sequential_topk.csv`
- `results/sequential_run_metrics.csv`

**What success looks like**

- The sequential output is available for deterministic comparison against the cluster result.

**Next step**

- Run the correctness checker on the two top-k CSV files.

## 7. Verify The Multi-Node Parallel Output

**Prerequisites**

- `results/sequential_topk.csv` exists.
- `results/parallel_topk.csv` exists.

**Bash**

```bash
cd ~/work/Parallel-Retrieval-Engine-for-RAG
./build/release/verify_results \
  --sequential results/sequential_topk.csv \
  --parallel results/parallel_topk.csv \
  --epsilon 1e-5 \
  --output results/correctness.csv
```

**Expected artifacts**

- `results/correctness.csv`

**What success looks like**

- `verify_results` prints `All queries PASS`.
- The correctness CSV records `PASS` for every query.

**Next step**

- Archive, inspect, or report the generated outputs from the head node.

## 8. Optional Result Collection And Archiving

Most canonical outputs already live on the head node. Use this step when you want to snapshot a run or collect any manually generated worker-local files.

**Prerequisites**

- The cluster run has already completed.

**Bash**

```bash
cd ~/work/Parallel-Retrieval-Engine-for-RAG
mkdir -p results/archive/manual-cluster-run
cp results/parallel_topk.csv results/archive/manual-cluster-run/
cp results/parallel_metrics.csv results/archive/manual-cluster-run/
cp results/parallel_run_metrics.csv results/archive/manual-cluster-run/
cp results/sequential_topk.csv results/archive/manual-cluster-run/
cp results/sequential_run_metrics.csv results/archive/manual-cluster-run/
cp results/correctness.csv results/archive/manual-cluster-run/
```

Optional worker pull:

```bash
cd ~/work/Parallel-Retrieval-Engine-for-RAG
mkdir -p results/archive/manual-cluster-run/worker1-results
mkdir -p results/archive/manual-cluster-run/worker2-results
rsync -av rag@rag-worker1:~/work/Parallel-Retrieval-Engine-for-RAG/results/ results/archive/manual-cluster-run/worker1-results/
rsync -av rag@rag-worker2:~/work/Parallel-Retrieval-Engine-for-RAG/results/ results/archive/manual-cluster-run/worker2-results/
```

**Expected artifacts**

- `results/archive/manual-cluster-run/`

**What success looks like**

- The important cluster outputs are preserved in one place on the head node.

**Next step**

- Use the normal repo analysis or reporting flow on the archived head-node outputs.

## What This Runbook Does Not Automate

The current repository does not yet provide cluster-aware automation for:

- `bash ./scripts/run_all_experiments.sh`
- `bash ./scripts/run_faiss_comparison.sh`
- per-node remote build orchestration beyond the explicit SSH commands in this guide

For now, keep physical multi-node execution manual and explicit. The single-machine benchmark scripts remain the canonical automation path.
