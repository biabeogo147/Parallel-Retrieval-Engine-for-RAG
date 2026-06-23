# Validated Two-Node Runbook: `rag-header` + `rag-worker1`

This document records the exact two-node workflow that was validated in this repository with:

- local machine as the header node
- Ubuntu 24.04 under WSL2 on the header node
- one Ubuntu server worker at `192.168.1.199`
- Linux user `rag` on both nodes

Unlike the generic cluster guides, this file is intentionally concrete and end-to-end. Follow it when you want one complete checklist instead of adapting the broader `header + 2 workers` documentation.

## Scope

This runbook covers:

- preparing the Windows host and local WSL header node
- preparing the Ubuntu server worker
- creating and using the Linux user `rag`
- cloning and building the repo on both nodes
- enabling LAN-reachable WSL networking for MPI
- configuring SSH, `/etc/hosts`, and the hostfile
- running a two-node MPI smoke test
- running a small exactness smoke workflow
- running the canonical manual benchmark
- preparing the dedicated two-node bundle config
- running the full two-node bundle rerun
- completing the validated no-FAISS expedited rerun path that reuses calibration outputs instead of restarting from zero
- regenerating cluster `analysis/` and `figures/` outputs
- collecting the final artifacts under `results/cluster/...`

The generic Phase 6-8 automation remains single-machine oriented. This runbook adds the repository's dedicated operator wrapper only for the validated `rag-header + rag-worker1` physical-cluster case:

- `scripts/run_cluster_two_node_bundle.sh`
- `scripts/run_cluster_postprocess.sh`

## Validated Topology

```text
Windows host
`-- worker node: rag-header
    `-- IP: 192.168.1.200

Ubuntu server on LAN
`-- worker node: rag-worker1
    `-- IP: 192.168.1.199
```

Canonical values used throughout this guide:

- repo path on both nodes: `~/work/Parallel-Retrieval-Engine-for-RAG`
- Linux username on both nodes: `rag`
The slot budget is detected at setup time with:

```bash
lscpu -p=Core,Socket | grep -v '^#' | sort -u | wc -l
```

## 1. Stabilize Hostname Resolution

Do this on both nodes.

### Bash

On `rag-header`:

```bash
sudo tee -a /etc/hosts >/dev/null <<EOF
192.168.1.200 rag-header
192.168.1.199 rag-worker1
EOF
getent hosts rag-header rag-worker1
```

On `rag-worker1`:

```bash
sudo tee -a /etc/hosts >/dev/null <<EOF
192.168.1.200 rag-header
192.168.1.199 rag-worker1
EOF
getent hosts rag-header rag-worker1
```

### What success looks like

- both nodes resolve `rag-header` and `rag-worker1`

## 2. Configure Passwordless SSH From Head To Worker

All commands in this section run from `rag-header`.

### Prerequisites

- the worker already has Linux user `rag`
- the header node can SSH to the worker through the bootstrap path

### Bash

Create the SSH key on the header node:

```bash
mkdir -p ~/.ssh
chmod 700 ~/.ssh
test -f ~/.ssh/id_ed25519 || ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -N ""
chmod 600 ~/.ssh/id_ed25519
chmod 644 ~/.ssh/id_ed25519.pub
```

If `ssh-copy-id` is missing:

```bash
sudo apt install -y openssh-client
```

Install the public key on the worker:

```bash
ssh-copy-id rag@192.168.1.199
```

Add a local SSH alias:

```bash
cat >> ~/.ssh/config <<'EOF'
Host rag-worker1
  HostName 192.168.1.199
  User rag
  IdentityFile ~/.ssh/id_ed25519
  StrictHostKeyChecking accept-new
EOF
chmod 600 ~/.ssh/config
```

Verify:

```bash
ssh rag@192.168.1.199 hostname
ssh rag-worker1 hostname
```

### What success looks like

- both SSH commands return `rag-worker1` without a password prompt

## 3. Create The Two-Node Hostfile

All commands in this section run from `rag-header`.

### Bash

```bash
cd ~/work/Parallel-Retrieval-Engine-for-RAG
LOCAL_SLOTS=$(lscpu -p=Core,Socket | grep -v '^#' | sort -u | wc -l)
SERVER_SLOTS=4
mkdir -p .cache/cluster
cat > .cache/cluster/hosts.two-nodes <<EOF
rag-header slots=${LOCAL_SLOTS} max-slots=${LOCAL_SLOTS}
rag-worker1 slots=${SERVER_SLOTS} max-slots=${SERVER_SLOTS}
EOF
cat .cache/cluster/hosts.two-nodes
```

### What success looks like

- the hostfile contains exactly two lines
- `rag-header` uses the detected slot count
- `rag-worker1` uses `slots=4 max-slots=4`

## 3. Validate MPI Transport And Remote Launch

All commands in this section run from `rag-header`.

### Bash

Hostname smoke:

```bash
mpirun \
  --hostfile .cache/cluster/hosts.two-nodes \
  --map-by ppr:1:node \
  -np 2 \
  hostname
```

Help-path smoke:

```bash
cd ~/work/Parallel-Retrieval-Engine-for-RAG
mpirun \
  --hostfile .cache/cluster/hosts.two-nodes \
  --map-by ppr:1:node \
  -np 2 \
  ./build/release/parallel_retriever --help
```

### What success looks like

- the hostname smoke prints:

```text
rag-header
rag-worker1
```

- the help-path smoke exits `0`

## 4. Run The Small Exactness Smoke

All commands in this section run from `rag-header`.

### Bash

```bash
cd ~/work/Parallel-Retrieval-Engine-for-RAG
mkdir -p data/cluster_smoke results/cluster_smoke

./build/release/generate_vectors \
  --N 64 \
  --D 8 \
  --output data/cluster_smoke/memory_vectors.bin

./build/release/generate_queries \
  --Q 5 \
  --D 8 \
  --output data/cluster_smoke/query_vectors.bin

rsync -a data/cluster_smoke/ \
  rag-worker1:~/work/Parallel-Retrieval-Engine-for-RAG/data/cluster_smoke/

./build/release/sequential_retriever \
  --vectors data/cluster_smoke/memory_vectors.bin \
  --queries data/cluster_smoke/query_vectors.bin \
  --topk 3 \
  --output results/cluster_smoke/sequential_topk.csv \
  --run-metrics results/cluster_smoke/sequential_run_metrics.csv

mpirun \
  --hostfile .cache/cluster/hosts.two-nodes \
  --map-by ppr:1:node \
  -np 2 \
  ./build/release/parallel_retriever \
  --vectors data/cluster_smoke/memory_vectors.bin \
  --queries data/cluster_smoke/query_vectors.bin \
  --topk 3 \
  --output results/cluster_smoke/parallel_topk.csv \
  --metrics results/cluster_smoke/parallel_metrics.csv \
  --run-metrics results/cluster_smoke/parallel_run_metrics.csv

./build/release/verify_results \
  --sequential results/cluster_smoke/sequential_topk.csv \
  --parallel results/cluster_smoke/parallel_topk.csv \
  --epsilon 1e-5 \
  --output results/cluster_smoke/correctness.csv
```

### What success looks like

- `verify_results` prints `All queries PASS`

## 5. Run The Canonical Two-Node Benchmark

All commands in this section run from `rag-header`.

### Canonical profile

- `N=100000`
- `D=384`
- `Q=100`
- `k=10`


### Bash

```bash
cd ~/work/Parallel-Retrieval-Engine-for-RAG

RUN_TAG="$(date +%F)-two-nodes"
RESULT_DIR="results/cluster/${RUN_TAG}"
DATA_DIR="data/cluster_two_node"
LOCAL_SLOTS=$(lscpu -p=Core,Socket | grep -v '^#' | sort -u | wc -l)
SERVER_SLOTS=4
P_TOTAL=$((LOCAL_SLOTS + SERVER_SLOTS))

mkdir -p "${RESULT_DIR}" "${DATA_DIR}"
cp .cache/cluster/hosts.two-nodes "${RESULT_DIR}/hostfile.snapshot.txt"

cat > "${RESULT_DIR}/run_notes.txt" <<EOF
cluster_date=$(date +%F)
head_node=rag-header
head_ip=192.168.1.200
worker_node=rag-worker1
worker_ip=192.168.1.199
local_slots=${LOCAL_SLOTS}
server_slots=${SERVER_SLOTS}
p_total=${P_TOTAL}
profile_N=100000
profile_D=384
profile_Q=100
profile_k=10
EOF

./build/release/generate_vectors \
  --N 100000 \
  --D 384 \
  --output "${DATA_DIR}/memory_vectors.bin"

./build/release/generate_queries \
  --Q 100 \
  --D 384 \
  --output "${DATA_DIR}/query_vectors.bin"

rsync -a "${DATA_DIR}/" \
  rag-worker1:~/work/Parallel-Retrieval-Engine-for-RAG/"${DATA_DIR}"/

./build/release/sequential_retriever \
  --vectors "${DATA_DIR}/memory_vectors.bin" \
  --queries "${DATA_DIR}/query_vectors.bin" \
  --topk 10 \
  --output "${RESULT_DIR}/sequential_topk.csv" \
  --run-metrics "${RESULT_DIR}/sequential_run_metrics.csv"

mpirun \
  --hostfile .cache/cluster/hosts.two-nodes \
  --map-by slot \
  -np "${P_TOTAL}" \
  ./build/release/parallel_retriever \
  --vectors "${DATA_DIR}/memory_vectors.bin" \
  --queries "${DATA_DIR}/query_vectors.bin" \
  --topk 10 \
  --output "${RESULT_DIR}/parallel_topk.csv" \
  --metrics "${RESULT_DIR}/parallel_metrics.csv" \
  --run-metrics "${RESULT_DIR}/parallel_run_metrics.csv"

./build/release/verify_results \
  --sequential "${RESULT_DIR}/sequential_topk.csv" \
  --parallel "${RESULT_DIR}/parallel_topk.csv" \
  --epsilon 1e-5 \
  --output "${RESULT_DIR}/correctness.csv"
```

### What success looks like

- `verify_results` prints `All queries PASS`
- `parallel_metrics.csv` has one header row plus `P_TOTAL` rank rows
- both top-k CSVs have `Q * k + 1` lines

## 6. Prepare The Dedicated Bundle Config

All commands in this section run from the WSL-native `rag-header` checkout.

### Why this config exists

The dedicated two-node bundle wrapper sources a shell config file so the operator can lock:

- the real hostfile path
- the real worker host
- the worker slot budget
- the benchmark-calibration overrides for the next rerun

Keep this file as plain POSIX-shell assignments only. Do not put arbitrary shell commands in it.

### Bash

```bash
cd ~/work/Parallel-Retrieval-Engine-for-RAG
mkdir -p .cache/cluster
cp docs/usage/mpi-cluster/examples/two_node_bundle.env.example .cache/cluster/two_node_bundle.env
nano .cache/cluster/two_node_bundle.env
grep -E '^(CLUSTER_|BENCH_)' .cache/cluster/two_node_bundle.env
```

At minimum, confirm these values match the real environment:

- `CLUSTER_HOSTFILE="$HOME/work/Parallel-Retrieval-Engine-for-RAG/.cache/cluster/hosts.two-nodes"`
- `CLUSTER_WORKER_HOST="rag-worker1"`
- `CLUSTER_WORKER_REPO_ROOT="$HOME/work/Parallel-Retrieval-Engine-for-RAG"`
- `CLUSTER_SERVER_SLOTS=4`
- `CLUSTER_HEAD_LAN_CIDR="192.168.1.0/24"`
- `BENCH_STORAGE_ROOT="/mnt/e/data/pdp_retrieve_engine"`
- `CLUSTER_RUNTIME_ROOT="$HOME/work/Parallel-Retrieval-Engine-for-RAG/.cache/cluster_runtime"`

Why these two storage knobs matter on the current Windows + WSL machine:

- `BENCH_STORAGE_ROOT` moves the heavy bundle outputs off the WSL ext4 virtual disk on `C:`
- `CLUSTER_RUNTIME_ROOT` stays repo-local so the wrapper can create lightweight symlinks on the header node and sync real dataset files to the worker under the same repo-relative paths

### What success looks like

- `.cache/cluster/two_node_bundle.env` exists
- the file points at the real two-node hostfile
- the file still contains only shell variable assignments

## 7. Run The Full Two-Node Bundle

All commands in this section run from the WSL-native `rag-header` checkout.

### Prerequisites

- steps `1` through `11` already succeeded
- the header checkout is the WSL-native repo path:
  - `~/work/Parallel-Retrieval-Engine-for-RAG`
- the worker still responds through `ssh rag-worker1 hostname`

### Bash

```bash
cd ~/work/Parallel-Retrieval-Engine-for-RAG
RUN_TAG="$(date +%F)-two-nodes-full-bundle"

mkdir -p mkdir -p "$HOME/data/pdp_retrieve_engine"

bash ./scripts/run_cluster_two_node_bundle.sh \
  --config .cache/cluster/two_node_bundle.env \
  --run-tag "${RUN_TAG}"
```

### Expected artifacts

- `$HOME/data/pdp_retrieve_engineresults/cluster/${RUN_TAG}/runtime_by_N.csv`
- `$HOME/data/pdp_retrieve_engineresults/cluster/${RUN_TAG}/benchmark_selection.env`
- `$HOME/data/pdp_retrieve_engineresults/cluster/${RUN_TAG}/sequential_topk.csv`
- `$HOME/data/pdp_retrieve_engineresults/cluster/${RUN_TAG}/parallel_topk.csv`
- `$HOME/data/pdp_retrieve_engineresults/cluster/${RUN_TAG}/correctness.csv`
- `$HOME/data/pdp_retrieve_engineresults/cluster/${RUN_TAG}/granularity.csv`
- `$HOME/data/pdp_retrieve_engineresults/cluster/${RUN_TAG}/speedup.csv`
- `$HOME/data/pdp_retrieve_engineresults/cluster/${RUN_TAG}/faiss/`
- `$HOME/data/pdp_retrieve_engineresults/cluster/${RUN_TAG}/analysis/`
- `$HOME/data/pdp_retrieve_engineresults/cluster/${RUN_TAG}/figures/`
- `docs/analysis/latest-cluster-benchmark-review.md`

### What success looks like

- the script prints all six stages:
  - runtime calibration
  - selected synthetic correctness run
  - granularity summary
  - speedup sweep
  - FAISS comparisons
  - postprocess
- the script finishes with:
  - `Cluster bundle completed at $HOME/data/pdp_retrieve_engineresults/cluster/<run-tag>`
- both:
  - `correctness.csv`
  - `faiss/synthetic_correctness.csv`
  - `faiss/squad_correctness.csv`
  record only `PASS`

## 8. Regenerate Cluster Analysis And Figures Only

Use this when the raw cluster CSVs already exist but `analysis/`, `figures/`, or `docs/analysis/latest-cluster-benchmark-review.md` need to be rebuilt.

### Bash

```bash
cd ~/work/Parallel-Retrieval-Engine-for-RAG
RUN_TAG="$(date +%F)-two-nodes-full-bundle"
RESULT_DIR="$HOME/data/pdp_retrieve_engineresults/cluster/${RUN_TAG}"

bash ./scripts/run_cluster_postprocess.sh \
  --results-dir "${RESULT_DIR}" \
  --docs-output docs/analysis/latest-cluster-benchmark-review.md
```

### Expected artifacts

- `results/cluster/${RUN_TAG}/figures/runtime_by_N.png`
- `results/cluster/${RUN_TAG}/figures/granularity.png`
- `results/cluster/${RUN_TAG}/figures/speedup_runtime.png`
- `results/cluster/${RUN_TAG}/figures/speedup_curves.png`
- `results/cluster/${RUN_TAG}/analysis/runtime_analysis.csv`
- `results/cluster/${RUN_TAG}/analysis/granularity_analysis.csv`
- `results/cluster/${RUN_TAG}/analysis/speedup_analysis.csv`
- `results/cluster/${RUN_TAG}/analysis/faiss_analysis.csv`
- `results/cluster/${RUN_TAG}/analysis/benchmark_summary.json`
- `results/cluster/${RUN_TAG}/analysis/final_conclusions.md`
- `docs/analysis/latest-cluster-benchmark-review.md`

In the external-storage setup above, replace the `results/cluster/...` prefix with:

- `$HOME/data/pdp_retrieve_engineresults/cluster/...`

### What success looks like

- the cluster result directory now contains both:
  - `analysis/`
  - `figures/`
- `docs/analysis/latest-cluster-benchmark-review.md` is refreshed from the cluster run, not left as the checked-in placeholder
- if the run intentionally skipped FAISS:
  - `analysis/final_conclusions.md` states that FAISS was skipped
  - `analysis/faiss_analysis.csv` may contain only the header row

## 9. Output Layout After The Full Bundle

After a successful bundle run, the cluster result directory should look like this:

```text
results/cluster/<run-tag>/
|-- benchmark_selection.env
|-- correctness.csv
|-- granularity.csv
|-- granularity_summary.txt
|-- hostfile.snapshot.txt
|-- parallel_metrics.csv
|-- parallel_run_metrics.csv
|-- parallel_topk.csv
|-- run_notes.txt
|-- runtime_by_N.csv
|-- sequential_run_metrics.csv
|-- sequential_topk.csv
|-- speedup.csv
|-- faiss/
|   `-- ...
|-- analysis/
|   |-- benchmark_summary.json
|   |-- faiss_analysis.csv
|   |-- final_conclusions.md
|   |-- granularity_analysis.csv
|   |-- runtime_analysis.csv
|   `-- speedup_analysis.csv
`-- figures/
    |-- granularity.png
    |-- runtime_by_N.png
    |-- speedup_curves.png
    `-- speedup_runtime.png
```

## 10. Final Verification Checklist

Run these checks from `rag-header`:

```bash
cd ~/work/Parallel-Retrieval-Engine-for-RAG

RUN_TAG="$(date +%F)-two-nodes-full-bundle"
RESULT_DIR="$HOME/data/pdp_retrieve_engineresults/cluster/${RUN_TAG}"

test -f "${RESULT_DIR}/runtime_by_N.csv"
test -f "${RESULT_DIR}/benchmark_selection.env"
test -f "${RESULT_DIR}/parallel_topk.csv"
test -f "${RESULT_DIR}/parallel_metrics.csv"
test -f "${RESULT_DIR}/parallel_run_metrics.csv"
test -f "${RESULT_DIR}/sequential_topk.csv"
test -f "${RESULT_DIR}/sequential_run_metrics.csv"
test -f "${RESULT_DIR}/correctness.csv"
test -f "${RESULT_DIR}/speedup.csv"
test -f "${RESULT_DIR}/analysis/final_conclusions.md"
test -f "${RESULT_DIR}/figures/runtime_by_N.png"
test -f "${RESULT_DIR}/figures/granularity.png"
test -f "${RESULT_DIR}/figures/speedup_runtime.png"
test -f "${RESULT_DIR}/figures/speedup_curves.png"

wc -l "${RESULT_DIR}/parallel_metrics.csv"
wc -l "${RESULT_DIR}/parallel_topk.csv"
wc -l "${RESULT_DIR}/sequential_topk.csv"
header -n 5 "${RESULT_DIR}/correctness.csv"
header -n 20 "${RESULT_DIR}/analysis/final_conclusions.md"
cat "${RESULT_DIR}/parallel_run_metrics.csv"
cat "${RESULT_DIR}/sequential_run_metrics.csv"
```

What you want to see:

- `correctness.csv` shows only `PASS`
- `parallel_run_metrics.csv` has exactly one data row
- `sequential_run_metrics.csv` has exactly one data row
- `analysis/` contains the derived benchmark review files
- `figures/` contains the four canonical PNG outputs
- if FAISS was skipped for this run:
  - `analysis/final_conclusions.md` states that FAISS was skipped
  - `analysis/faiss_analysis.csv` still exists, even if it has header-only content

## Troubleshooting Shortlist

If this exact runbook stalls:

- `ssh rag-worker1 hostname` works, but `mpirun` hangs before printing anything
  - re-check `HWLOC_COMPONENTS=-gl`
- worker launches but cannot connect back to the header node
  - re-check mirrored networking
  - re-check the Hyper-V firewall inbound allow step
  - verify the worker can open `192.168.1.x:22` on the header node
- header node IP changed after WSL restart
  - update `/etc/hosts`
  - update `~/.ssh/config` if needed
  - regenerate `hosts.two-nodes`
- `run_cluster_two_node_bundle.sh` refuses to start
  - confirm you launched it from:
    - `~/work/Parallel-Retrieval-Engine-for-RAG`
  - do not launch the real bundle from:
    - `/mnt/d/DS-AI/Parallel-Retrieval-Engine-for-RAG`
- `parallel_retriever` works on one node but hangs across two nodes
  - keep the IPv4-only MPI flags exactly as shown
  - verify the hostfile names resolve correctly on both nodes

For broader cluster problems, continue with [troubleshooting.md](troubleshooting.md).
