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

The generic wrapper introduced here is intentionally post-calibration only. Before you invoke it, the environment must already provide all of the following:

- release binaries on every node
- the authoritative hostfile with explicit `slots=...`
- the selected-workload memory and query datasets on every node
- the speedup-workload memory dataset on every node
- an existing `benchmark_selection.env` on the head node

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

## 4. Prepare The Head-Node Inputs And Selection Manifest

This step leaves the head node with one shared file layout regardless of how you produced it:

- `data/cluster_selected/memory_vectors.bin`
- `data/cluster_selected/query_vectors.bin`
- `data/cluster_speedup/memory_vectors.bin`
- optional `data/cluster_speedup/query_vectors.bin`
- `.cache/cluster/benchmark_selection.env`

The generic wrapper expects two prepared workloads:

- selected workload
  - used for the sequential versus parallel correctness rerun
- speedup workload
  - used for the sequential baseline plus `BENCH_P_LIST` sweep

Choose exactly one option below.

### Option A. Use The Normal Calibration Flow

Use this when you want the repo-standard calibration stage to choose `N_SELECTED`, `N_SPEEDUP`, `Q`, and the selected process count for you.

Calibration runs only on the head node. It does not `rsync` files, does not SSH to workers, and does not update remote binaries. This runbook then copies the generated outputs into the stable repo-local `data/cluster_*` paths so the later sync step stays identical to the manual path.

**Bash**

```bash
cd ~/work/Parallel-Retrieval-Engine-for-RAG
BENCH_BUILD_DIR="$HOME/work/Parallel-Retrieval-Engine-for-RAG/build/release" \
BENCH_P_SELECTED=12 \
bash ./scripts/run_calibrate_target.sh

mkdir -p data/cluster_selected data/cluster_speedup
mkdir -p .cache/cluster

. results/benchmark_selection.env

cp results/benchmark_selection.env .cache/cluster/benchmark_selection.env
cp ".cache/benchmarks/memory_vectors_N${N_SELECTED}_D${D}.bin" data/cluster_selected/memory_vectors.bin
cp ".cache/benchmarks/query_vectors_Q${Q}_D${D}.bin" data/cluster_selected/query_vectors.bin
cp ".cache/benchmarks/memory_vectors_N${N_SPEEDUP}_D${D}.bin" data/cluster_speedup/memory_vectors.bin

# Optional. If omitted, the wrapper reuses the selected-workload queries.
cp data/cluster_selected/query_vectors.bin data/cluster_speedup/query_vectors.bin

cat .cache/cluster/benchmark_selection.env
```

If your calibration used a custom `BENCH_RESULTS_DIR`, `BENCH_SCRATCH_DIR`, or `BENCH_STORAGE_ROOT`, replace the `results/...` and `.cache/benchmarks/...` source paths above with the real calibration output paths.

### Option B. Create The Inputs And Manifest Manually

Use this when you already know the selected workload settings and want to create the exact cluster input paths yourself.

The example below keeps the selected and speedup workloads separate under repo-local `data/`.

**Bash**

```bash
cd ~/work/Parallel-Retrieval-Engine-for-RAG
mkdir -p data/cluster_selected data/cluster_speedup
mkdir -p .cache/cluster

# Replace the values below with the already-chosen workload settings.
SELECTED_N=100000
SELECTED_Q=100
SPEEDUP_N=200000
SELECTED_P=12
D=384
K=10
EPSILON=1e-5

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

cp docs/usage/mpi-cluster/examples/benchmark_selection.env.example .cache/cluster/benchmark_selection.env
nano .cache/cluster/benchmark_selection.env
cat .cache/cluster/benchmark_selection.env
```

When editing the manifest in this manual path, set these fields from the values above:

- `N_SELECTED=${SELECTED_N}`
- `N_SPEEDUP=${SPEEDUP_N}`
- `P_SELECTED=${SELECTED_P}`
- `D=${D}`
- `Q=${SELECTED_Q}`
- `K=${K}`
- `EPSILON=${EPSILON}`

Required manifest fields in either path:

- `N_SELECTED`
- `N_SPEEDUP`
- `P_SELECTED`
- `D`
- `Q`
- `K`
- `EPSILON`
- `CALIBRATION_MODE`
- `N_MAX_FEASIBLE`

Manual-authoring rules:

- `N_SELECTED` must match `data/cluster_selected/memory_vectors.bin`.
- `N_SPEEDUP` must match `data/cluster_speedup/memory_vectors.bin`.
- `P_SELECTED` must be the intended selected parallel process count for the correctness and granularity rerun.
- `D`, `Q`, `K`, and `EPSILON` must match the dataset and retrieval settings you intend to reuse.
- `CALIBRATION_MODE` should usually stay `N_ONLY` or `N_PLUS_Q`.
- `N_MAX_FEASIBLE` should be the largest successful `N` from the original calibration story; if you are authoring manually and do not know a separate larger value, keep it equal to `N_SELECTED`.
- Keep the file as plain `NAME=value` assignments only.

**What success looks like**

- `.cache/cluster/benchmark_selection.env` exists
- the manifest fields match the prepared dataset sizes and the intended selected process count

## 5. Sync The Prepared Datasets To Every Node

After either option in step 4, sync the prepared dataset paths so every node exposes the same runtime files.

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

## 6. Run The Generic N-Node Post-Calibration Bundle

This is the first automated step in the generic flow after the hostfile, head-node input files, and selection manifest are already ready.

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

## 7. Optional Manual FAISS Or Real-Corpus Follow-Up

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

## 8. Optional Postprocess-Only Regeneration

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

## 9. What This Generic Runbook Does Not Automate

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
