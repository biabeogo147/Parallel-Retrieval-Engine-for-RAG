# Cluster Runbook

This runbook is the repeatable generic N-node operating flow after the cluster has already passed the initial assembly and validation steps.

All commands below run from the head node unless a section explicitly says otherwise.

If you want the exact validated `rag-head + rag-worker1` process, including the dedicated full-bundle rerun and cluster postprocess flow, use [two-node-runbook-two-nodes.md](two-node-runbook-two-nodes.md) instead of adapting this generic guide.

The examples below assume:

- canonical repo path: `~/work/Parallel-Retrieval-Engine-for-RAG`
- authoritative shared-data path: `~/cluster-shared/parallel-rag-data`
- Linux username: `rag`
- hostfile working copy: `.cache/cluster/hosts.cluster`
- generic wrapper config copy: `.cache/cluster/n_node_bundle.env`
- generic wrapper manifest copy: `.cache/cluster/benchmark_selection.env`

The generic wrapper introduced here is intentionally post-calibration only. It starts only after you have already prepared all of the following manually:

- release binaries on every node
- the authoritative hostfile with explicit `slots=...`
- the selected-workload memory and query datasets on every node
- the speedup-workload memory dataset on every node
- an existing `benchmark_selection.env`

The wrapper does not generate datasets, does not `rsync` files, does not SSH-orchestrate workers, and does not run FAISS.

## 1. Reconfirm Cluster Readiness

**Prerequisites**

- The cluster already passed [cluster-assembly-and-validation.md](cluster-assembly-and-validation.md).

**Bash**

```bash
cd ~/work/Parallel-Retrieval-Engine-for-RAG
test -x ./build/release/parallel_retriever
test -x ./build/release/sequential_retriever
test -x ./build/release/verify_results

for host in rag-worker1 rag-worker2; do
  ssh "rag@${host}" 'cd ~/work/Parallel-Retrieval-Engine-for-RAG && hostname && test -x ./build/release/parallel_retriever && test -x ./build/release/sequential_retriever && test -x ./build/release/verify_results'
done
```

**What success looks like**

- every worker responds
- every node already has the release retriever binaries

## 2. Refresh The Release Build On Every Node

Run this when the repo changed or when you want to ensure every node uses the same binary revision.

**Bash**

```bash
cd ~/work/Parallel-Retrieval-Engine-for-RAG
bash ./scripts/configure_release.sh
cmake --build build/release

for host in rag-worker1 rag-worker2; do
  ssh "rag@${host}" 'cd ~/work/Parallel-Retrieval-Engine-for-RAG && bash ./scripts/configure_release.sh && cmake --build build/release'
done
```

**What success looks like**

- all release builds complete without error

## 3. Prepare Or Refresh The Authoritative Hostfile

The hostfile is the single authoritative topology source for the generic N-node rerun wrapper.

Every active line must include explicit `slots=...`.

**Bash**

```bash
cd ~/work/Parallel-Retrieval-Engine-for-RAG
mkdir -p .cache/cluster
cp docs/usage/mpi-cluster/examples/hosts.example .cache/cluster/hosts.cluster
nano .cache/cluster/hosts.cluster
cat .cache/cluster/hosts.cluster
```

Example shape:

```text
rag-head slots=4 max-slots=4
rag-worker1 slots=4 max-slots=4
rag-worker2 slots=4 max-slots=4
```

**What success looks like**

- the hostfile lists exactly the nodes you want to use
- every entry includes an explicit positive `slots=...` value

## 4. Create Or Refresh The Prepared Synthetic Datasets

The generic wrapper expects two prepared workloads:

- selected workload
  - used for the sequential versus parallel correctness rerun
- speedup workload
  - used for the sequential baseline plus `BENCH_P_LIST` sweep

The example below keeps them separate under repo-local `data/`.

**Bash**

```bash
cd ~/work/Parallel-Retrieval-Engine-for-RAG
mkdir -p data/cluster_selected data/cluster_speedup

# Replace the sizes below with the already-chosen calibration outputs.
SELECTED_N=100000
SELECTED_Q=100
SPEEDUP_N=200000
D=384

./build/release/generate_vectors \
  --N "${SELECTED_N}" \
  --D "${D}" \
  --output data/cluster_selected/memory_vectors.bin

./build/release/generate_queries \
  --Q "${SELECTED_Q}" \
  --D "${D}" \
  --output data/cluster_selected/query_vectors.bin

./build/release/generate_vectors \
  --N "${SPEEDUP_N}" \
  --D "${D}" \
  --output data/cluster_speedup/memory_vectors.bin

# Optional. If omitted, the wrapper reuses the selected-workload queries.
cp data/cluster_selected/query_vectors.bin data/cluster_speedup/query_vectors.bin
```

If you already have these binaries from a prior calibration flow, copy them into these paths instead of regenerating them.

**What success looks like**

- the selected-workload memory and query files exist on the head node
- the speedup-workload memory file exists on the head node
- any optional speedup query file you want to use exists on the head node

## 5. Sync The Prepared Datasets To Every Node

The generic wrapper assumes these prepared dataset paths already exist identically on every node.

**Bash**

```bash
cd ~/work/Parallel-Retrieval-Engine-for-RAG

for host in rag-worker1 rag-worker2; do
  ssh "rag@${host}" 'mkdir -p ~/work/Parallel-Retrieval-Engine-for-RAG/data/cluster_selected ~/work/Parallel-Retrieval-Engine-for-RAG/data/cluster_speedup'

  rsync -av data/cluster_selected/memory_vectors.bin "rag@${host}:~/work/Parallel-Retrieval-Engine-for-RAG/data/cluster_selected/"
  rsync -av data/cluster_selected/query_vectors.bin "rag@${host}:~/work/Parallel-Retrieval-Engine-for-RAG/data/cluster_selected/"
  rsync -av data/cluster_speedup/memory_vectors.bin "rag@${host}:~/work/Parallel-Retrieval-Engine-for-RAG/data/cluster_speedup/"

  if [ -f data/cluster_speedup/query_vectors.bin ]; then
    rsync -av data/cluster_speedup/query_vectors.bin "rag@${host}:~/work/Parallel-Retrieval-Engine-for-RAG/data/cluster_speedup/"
  fi
done
```

**What success looks like**

- every node now exposes the same prepared dataset paths referenced by the future bundle config

## 6. Prepare The Existing Selection Manifest

The generic wrapper consumes an already-existing `benchmark_selection.env` instead of recalibrating `runtime_by_N.csv` itself.

You can either:

- copy a manifest that came from a prior calibration flow
- or prepare one manually if you already know the selected values

**Bash**

```bash
cd ~/work/Parallel-Retrieval-Engine-for-RAG
mkdir -p .cache/cluster
cp /path/to/existing/benchmark_selection.env .cache/cluster/benchmark_selection.env
cat .cache/cluster/benchmark_selection.env
```

Required fields:

- `N_SELECTED`
- `N_SPEEDUP`
- `P_SELECTED`
- `D`
- `Q`
- `K`
- `EPSILON`
- `CALIBRATION_MODE`
- `N_MAX_FEASIBLE`

If you prepare the file manually, keep it as plain `NAME=value` assignments only.

**What success looks like**

- `.cache/cluster/benchmark_selection.env` exists
- the manifest fields match the prepared dataset sizes and the intended selected process count

## 7. Run The Generic N-Node Post-Calibration Bundle

This is the first automated step in the generic flow.

**Bash**

```bash
cd ~/work/Parallel-Retrieval-Engine-for-RAG
mkdir -p .cache/cluster
cp docs/usage/mpi-cluster/examples/n_node_bundle.env.example .cache/cluster/n_node_bundle.env
nano .cache/cluster/n_node_bundle.env

bash ./scripts/run_cluster_n_node_bundle.sh \
  --config .cache/cluster/n_node_bundle.env \
  --run-tag "$(date +%F)-n-node-bundle"
```

At minimum, confirm these values match the real environment:

- `CLUSTER_HOSTFILE`
- `CLUSTER_SELECTION_ENV`
- `CLUSTER_SELECTED_MEMORY_PATH`
- `CLUSTER_SELECTED_QUERY_PATH`
- `CLUSTER_SPEEDUP_MEMORY_PATH`
- `CLUSTER_HEAD_LAN_CIDR`

Optional:

- `CLUSTER_SPEEDUP_QUERY_PATH`
- `BENCH_P_LIST`
- `BENCH_STORAGE_ROOT`
- `CLUSTER_DOCS_OUTPUT`

**Expected artifacts**

- `results/cluster/<run-tag>/benchmark_selection.env`
- `results/cluster/<run-tag>/runtime_by_N.csv`
- `results/cluster/<run-tag>/sequential_topk.csv`
- `results/cluster/<run-tag>/sequential_run_metrics.csv`
- `results/cluster/<run-tag>/parallel_topk.csv`
- `results/cluster/<run-tag>/parallel_metrics.csv`
- `results/cluster/<run-tag>/parallel_run_metrics.csv`
- `results/cluster/<run-tag>/correctness.csv`
- `results/cluster/<run-tag>/granularity.csv`
- `results/cluster/<run-tag>/granularity_summary.txt`
- `results/cluster/<run-tag>/speedup.csv`
- `results/cluster/<run-tag>/analysis/`
- `results/cluster/<run-tag>/figures/`
- `docs/analysis/latest-cluster-benchmark-review.md`

**What success looks like**

- the script prints all four stages:
  - selected synthetic correctness run
  - granularity summary
  - speedup sweep
  - postprocess
- the script finishes with:
  - `Cluster n-node bundle completed at ...`
- `correctness.csv` records only `PASS`

## 8. Optional Manual FAISS Or Real-Corpus Follow-Up

The generic N-node wrapper intentionally stops before FAISS.

Use this section when you want to run a manual synthetic FAISS comparison on the head node after the generic bundle completed.

**Bash**

```bash
cd ~/work/Parallel-Retrieval-Engine-for-RAG
RUN_TAG="$(date +%F)-n-node-bundle"
RESULT_DIR="results/cluster/${RUN_TAG}"
mkdir -p "${RESULT_DIR}/faiss"

python3 ./scripts/faiss_compare.py \
  --dataset-name synthetic \
  --vectors data/cluster_selected/memory_vectors.bin \
  --queries data/cluster_selected/query_vectors.bin \
  --topk 10 \
  --threads 4 \
  --output-topk "${RESULT_DIR}/faiss/synthetic_topk.csv" \
  --output-metrics "${RESULT_DIR}/faiss/synthetic_run_metrics.csv"

./build/release/verify_results \
  --sequential "${RESULT_DIR}/sequential_topk.csv" \
  --parallel "${RESULT_DIR}/faiss/synthetic_topk.csv" \
  --epsilon 1e-5 \
  --output "${RESULT_DIR}/faiss/synthetic_correctness.csv"
```

Optional real-corpus follow-up stays manual as well:

- prepare the corpus with `scripts/prepare_squad_minilm.py`
- run sequential retrieval on the head node
- run parallel retrieval with the same hostfile
- run `faiss_compare.py`
- compare the outputs with `verify_results`

If you need the fully maintained FAISS bundle path today, keep using the existing single-machine workflow or the dedicated validated two-node runbook.

## 9. Optional Postprocess-Only Regeneration

Use this when the raw cluster CSVs already exist but `analysis/`, `figures/`, or `docs/analysis/latest-cluster-benchmark-review.md` need to be rebuilt.

**Bash**

```bash
cd ~/work/Parallel-Retrieval-Engine-for-RAG
RUN_TAG="$(date +%F)-n-node-bundle"
RESULT_DIR="results/cluster/${RUN_TAG}"

bash ./scripts/run_cluster_postprocess.sh \
  --results-dir "${RESULT_DIR}" \
  --docs-output docs/analysis/latest-cluster-benchmark-review.md
```

**What success looks like**

- the cluster result directory contains both:
  - `analysis/`
  - `figures/`
- `docs/analysis/latest-cluster-benchmark-review.md` is refreshed from the selected cluster run

## 10. What This Generic Runbook Does Not Automate

The generic N-node operator surface still does not automate:

- hostfile authoring
- dataset generation
- `rsync` dataset distribution
- remote release builds
- selection-manifest generation
- FAISS comparison
- optional real-corpus preparation and reruns

That split is intentional:

- manual steps remain explicit where they depend on real node inventory and storage layout
- the generic wrapper only handles the repeated post-calibration benchmark rerun
- the dedicated validated two-node full bundle remains documented separately in [two-node-runbook-two-nodes.md](two-node-runbook-two-nodes.md)
