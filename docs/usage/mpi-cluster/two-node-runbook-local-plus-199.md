# Validated Two-Node Runbook: `rag-head` + `rag-worker1`

This document records the exact two-node workflow that was validated in this repository with:

- local machine as the head node
- Ubuntu 24.04 under WSL2 on the head node
- one Ubuntu server worker at `192.168.1.199`
- Linux user `rag` on both nodes

Unlike the generic cluster guides, this file is intentionally concrete and end-to-end. Follow it when you want one complete checklist instead of adapting the broader `head + 2 workers` documentation.

## Scope

This runbook covers:

- preparing the Windows host and local WSL head node
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

The generic Phase 6-8 automation remains single-machine oriented. This runbook adds the repository's dedicated operator wrapper only for the validated `rag-head + rag-worker1` physical-cluster case:

- `scripts/run_cluster_two_node_bundle.sh`
- `scripts/run_cluster_postprocess.sh`

## Validated Topology

```text
Windows host
`-- WSL2 Ubuntu 24.04 guest
    `-- head node: rag-head

Ubuntu server on LAN
`-- worker node: rag-worker1
    `-- IP: 192.168.1.199
```

Canonical values used throughout this guide:

- repo path on both nodes: `~/work/Parallel-Retrieval-Engine-for-RAG`
- Linux username on both nodes: `rag`
- worker slot budget: `SERVER_SLOTS=4`
- recommended large-run benchmark storage root on the head node: `/mnt/e/data/pdp_retrieve_engine`

The head-node slot budget is detected at setup time with:

```bash
lscpu -p=Core,Socket | grep -v '^#' | sort -u | wc -l
```

In the validated run, this returned `10`, which produced:

```text
P_TOTAL = LOCAL_SLOTS + SERVER_SLOTS = 14
```

## 1. Prepare The Windows Host For A WSL Head Node

This section runs on the Windows host, not inside Ubuntu.

### Prerequisites

- Windows 11 with administrator access
- WSL2 available
- a LAN connection to the Ubuntu server worker

### PowerShell

Install Ubuntu 24.04 if needed:

```powershell
wsl --install -d Ubuntu-24.04
```

Create or update `C:\Users\<you>\.wslconfig` so the Ubuntu guest uses mirrored networking:

```ini
[wsl2]
networkingMode=mirrored
dnsTunneling=true
firewall=false
autoProxy=true
```

Apply the change:

```powershell
wsl.exe --shutdown
```

Then allow inbound LAN traffic to mirrored-mode WSL through the Hyper-V firewall. This step was required in the validated run so the worker could connect back to the head node on dynamic MPI ports.

```powershell
Set-NetFirewallHyperVVMSetting `
  -Name '{40E0AC32-46A5-438A-A0B2-2B479E8F2E90}' `
  -DefaultInboundAction Allow
```

### What success looks like

- WSL restarts cleanly
- the Ubuntu guest later gets a LAN-visible `192.168.1.x` address
- the worker can later reach the head node over LAN on `:22`

## 2. Normalize The Local WSL Head Node

All commands in this section run inside the Ubuntu 24.04 WSL guest.

### Prerequisites

- the Windows-side mirrored-networking and Hyper-V firewall steps are already done

### Bash

If you are still entering Ubuntu as `root`, create the normal Linux user `rag` and make it the default WSL user:

```bash
id -u rag >/dev/null 2>&1 || sudo useradd -m -s /bin/bash rag
sudo usermod -aG sudo rag
sudo tee /etc/wsl.conf >/dev/null <<'EOF'
[boot]
systemd=true

[user]
default=rag
EOF
```

Restart WSL from Windows:

```powershell
wsl.exe --shutdown
```

Re-enter Ubuntu as `rag`, then set the hostname and enable SSH:

```bash
sudo hostnamectl set-hostname rag-head
sudo apt update
sudo apt install -y openssh-server
sudo systemctl enable --now ssh
```

Verify the head node and record its current LAN IPv4 address:

```bash
whoami
hostnamectl --static
hostname -I
ss -tln | grep ':22'
HEAD_IP=$(ip -4 -o addr show scope global | awk '{split($4,a,"/"); print a[1]; exit}')
echo "${HEAD_IP}"
```

### What success looks like

- `whoami` prints `rag`
- `hostnamectl --static` prints `rag-head`
- `hostname -I` shows a LAN-visible address instead of a NAT-only `172.x.x.x`
- SSH listens on `:22`
- you recorded the current `HEAD_IP`

## 3. Clone And Build The Repo On The Head Node

### Prerequisites

- you are logged into the WSL Ubuntu guest as `rag`

### Bash

```bash
mkdir -p ~/work
cd ~/work
git clone <your-remote-url> Parallel-Retrieval-Engine-for-RAG
cd ~/work/Parallel-Retrieval-Engine-for-RAG

chmod +x scripts/*.sh
./scripts/setup_wsl_dev_env.sh
./scripts/configure_release.sh
cmake --build build/release

test -x ./build/release/parallel_retriever
test -x ./build/release/sequential_retriever
test -x ./build/release/verify_results
```

### What success looks like

- the release build completes cleanly
- the key binaries exist under `build/release/`

## 4. Prepare The Ubuntu Server Worker

This section starts from an existing bootstrap account on the Ubuntu server. Do not store the bootstrap password in the repo. Use your current admin-capable login account interactively.

### Prerequisites

- the worker is reachable on LAN at `192.168.1.199`
- you have an existing SSH login on the worker with `sudo`

### Bash

Log in to the worker:

```bash
ssh <bootstrap-user>@192.168.1.199
```

Create the Linux user `rag`, grant `sudo`, and set the hostname:

```bash
sudo useradd -m -s /bin/bash rag
sudo usermod -aG sudo rag
sudo hostnamectl set-hostname rag-worker1
```

Prepare the canonical repo path:

```bash
sudo mkdir -p /home/rag/work
sudo chown -R rag:rag /home/rag/work
```

Clone and build as `rag`:

```bash
sudo -u rag bash -lc '
  set -euo pipefail
  cd ~/work
  git clone <your-remote-url> Parallel-Retrieval-Engine-for-RAG
  cd ~/work/Parallel-Retrieval-Engine-for-RAG
  chmod +x scripts/*.sh
  ./scripts/setup_wsl_dev_env.sh
  ./scripts/configure_release.sh
  cmake --build build/release
'
```

Verify:

```bash
hostnamectl --static
sudo -u rag bash -lc '
  cd ~/work/Parallel-Retrieval-Engine-for-RAG
  realpath .
  test -x ./build/release/parallel_retriever
  test -x ./build/release/sequential_retriever
'
```

### What success looks like

- `hostnamectl --static` prints `rag-worker1`
- the worker repo and release binaries exist under `/home/rag`

## 5. Stabilize Hostname Resolution

Do this on both nodes.

### Prerequisites

- you know the current `HEAD_IP` from step 2
- the worker IP is `192.168.1.199`

### Bash

On `rag-head`:

```bash
HEAD_IP="<head-node-ip-from-step-2>"
sudo tee -a /etc/hosts >/dev/null <<EOF
${HEAD_IP} rag-head
192.168.1.199 rag-worker1
EOF
getent hosts rag-head rag-worker1
```

On `rag-worker1`:

```bash
HEAD_IP="<head-node-ip-from-step-2>"
sudo tee -a /etc/hosts >/dev/null <<EOF
${HEAD_IP} rag-head
192.168.1.199 rag-worker1
EOF
getent hosts rag-head rag-worker1
```

### What success looks like

- both nodes resolve `rag-head` and `rag-worker1`

## 6. Configure Passwordless SSH From Head To Worker

All commands in this section run from `rag-head`.

### Prerequisites

- the worker already has Linux user `rag`
- the head node can SSH to the worker through the bootstrap path

### Bash

Create the SSH key on the head node:

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

## 7. Create The Two-Node Hostfile

All commands in this section run from `rag-head`.

### Bash

```bash
cd ~/work/Parallel-Retrieval-Engine-for-RAG
LOCAL_SLOTS=$(lscpu -p=Core,Socket | grep -v '^#' | sort -u | wc -l)
SERVER_SLOTS=4
mkdir -p .cache/cluster
cat > .cache/cluster/hosts.local-plus-199 <<EOF
rag-head slots=${LOCAL_SLOTS} max-slots=${LOCAL_SLOTS}
rag-worker1 slots=${SERVER_SLOTS} max-slots=${SERVER_SLOTS}
EOF
cat .cache/cluster/hosts.local-plus-199
```

### What success looks like

- the hostfile contains exactly two lines
- `rag-head` uses the detected slot count
- `rag-worker1` uses `slots=4 max-slots=4`

## 8. Validate MPI Transport And Remote Launch

All commands in this section run from `rag-head`.

### Why the extra flags matter

The validated WSL head node needed:

- `HWLOC_COMPONENTS=-gl`
  - avoids `mpirun` hanging on WSLg/X11-related `hwloc` probing
- `--mca oob_tcp_disable_ipv6_family 1`
  - keeps OpenMPI bootstrap off IPv6 paths
- `--mca oob_tcp_if_include 192.168.1.0/24`
  - keeps OOB traffic on the LAN subnet
- `--mca btl self,tcp`
- `--mca btl_tcp_if_include 192.168.1.0/24`
  - keeps MPI data traffic on the IPv4 LAN path

### Bash

Hostname smoke:

```bash
cd ~/work/Parallel-Retrieval-Engine-for-RAG
env HWLOC_COMPONENTS=-gl \
  mpirun \
  -x HWLOC_COMPONENTS \
  --mca oob_tcp_disable_ipv6_family 1 \
  --mca oob_tcp_if_include 192.168.1.0/24 \
  --mca btl self,tcp \
  --mca btl_tcp_if_include 192.168.1.0/24 \
  --hostfile .cache/cluster/hosts.local-plus-199 \
  --map-by ppr:1:node \
  -np 2 \
  hostname
```

Help-path smoke:

```bash
cd ~/work/Parallel-Retrieval-Engine-for-RAG
env HWLOC_COMPONENTS=-gl \
  mpirun \
  -x HWLOC_COMPONENTS \
  --mca oob_tcp_disable_ipv6_family 1 \
  --mca oob_tcp_if_include 192.168.1.0/24 \
  --mca btl self,tcp \
  --mca btl_tcp_if_include 192.168.1.0/24 \
  --hostfile .cache/cluster/hosts.local-plus-199 \
  --map-by ppr:1:node \
  -np 2 \
  ./build/release/parallel_retriever --help
```

### What success looks like

- the hostname smoke prints:

```text
rag-head
rag-worker1
```

- the help-path smoke exits `0`

## 9. Run The Small Exactness Smoke

All commands in this section run from `rag-head`.

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

env HWLOC_COMPONENTS=-gl \
  mpirun \
  -x HWLOC_COMPONENTS \
  --mca oob_tcp_disable_ipv6_family 1 \
  --mca oob_tcp_if_include 192.168.1.0/24 \
  --mca btl self,tcp \
  --mca btl_tcp_if_include 192.168.1.0/24 \
  --hostfile .cache/cluster/hosts.local-plus-199 \
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

## 10. Run The Canonical Two-Node Benchmark

All commands in this section run from `rag-head`.

### Canonical profile

- `N=100000`
- `D=384`
- `Q=100`
- `k=10`

### Recommended run tag

For a fresh rerun:

```bash
RUN_TAG="$(date +%F)-local-plus-199"
```

To reproduce the original validated output path exactly:

```bash
RUN_TAG="2026-06-22-local-plus-199"
```

### Bash

```bash
cd ~/work/Parallel-Retrieval-Engine-for-RAG

RUN_TAG="$(date +%F)-local-plus-199"
RESULT_DIR="results/cluster/${RUN_TAG}"
DATA_DIR="data/cluster_local_plus_199"
HEAD_IP=$(ip -4 -o addr show scope global | awk '{split($4,a,"/"); print a[1]; exit}')
LOCAL_SLOTS=$(lscpu -p=Core,Socket | grep -v '^#' | sort -u | wc -l)
SERVER_SLOTS=4
P_TOTAL=$((LOCAL_SLOTS + SERVER_SLOTS))

mkdir -p "${RESULT_DIR}" "${DATA_DIR}"
cp .cache/cluster/hosts.local-plus-199 "${RESULT_DIR}/hostfile.snapshot.txt"

cat > "${RESULT_DIR}/run_notes.txt" <<EOF
cluster_date=$(date +%F)
head_node=rag-head
head_ip=${HEAD_IP}
worker_node=rag-worker1
worker_ip=192.168.1.199
local_slots=${LOCAL_SLOTS}
server_slots=${SERVER_SLOTS}
p_total=${P_TOTAL}
profile_N=100000
profile_D=384
profile_Q=100
profile_k=10
mpi_flags=HWLOC_COMPONENTS=-gl,oob_tcp_disable_ipv6_family=1,oob_tcp_if_include=192.168.1.0/24,btl=self,tcp,btl_tcp_if_include=192.168.1.0/24
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

env HWLOC_COMPONENTS=-gl \
  mpirun \
  -x HWLOC_COMPONENTS \
  --mca oob_tcp_disable_ipv6_family 1 \
  --mca oob_tcp_if_include 192.168.1.0/24 \
  --mca btl self,tcp \
  --mca btl_tcp_if_include 192.168.1.0/24 \
  --hostfile .cache/cluster/hosts.local-plus-199 \
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

## 11. Prepare The Dedicated Bundle Config

All commands in this section run from the WSL-native `rag-head` checkout.

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

- `CLUSTER_HOSTFILE="$HOME/work/Parallel-Retrieval-Engine-for-RAG/.cache/cluster/hosts.local-plus-199"`
- `CLUSTER_WORKER_HOST="rag-worker1"`
- `CLUSTER_WORKER_REPO_ROOT="$HOME/work/Parallel-Retrieval-Engine-for-RAG"`
- `CLUSTER_SERVER_SLOTS=4`
- `CLUSTER_HEAD_LAN_CIDR="192.168.1.0/24"`
- `BENCH_STORAGE_ROOT="/mnt/e/data/pdp_retrieve_engine"`
- `CLUSTER_RUNTIME_ROOT="$HOME/work/Parallel-Retrieval-Engine-for-RAG/.cache/cluster_runtime"`

Why these two storage knobs matter on the current Windows + WSL machine:

- `BENCH_STORAGE_ROOT` moves the heavy bundle outputs off the WSL ext4 virtual disk on `C:`
- `CLUSTER_RUNTIME_ROOT` stays repo-local so the wrapper can create lightweight symlinks on the head node and sync real dataset files to the worker under the same repo-relative paths

### What success looks like

- `.cache/cluster/two_node_bundle.env` exists
- the file points at the real two-node hostfile
- the file still contains only shell variable assignments

## 12. Run The Full Two-Node Bundle

All commands in this section run from the WSL-native `rag-head` checkout.

### Prerequisites

- steps `1` through `11` already succeeded
- the head checkout is the WSL-native repo path:
  - `~/work/Parallel-Retrieval-Engine-for-RAG`
- the worker still responds through `ssh rag-worker1 hostname`

### Bash

```bash
cd ~/work/Parallel-Retrieval-Engine-for-RAG
RUN_TAG="$(date +%F)-local-plus-199-full-bundle"

mkdir -p /mnt/e/data/pdp_retrieve_engine

bash ./scripts/run_cluster_two_node_bundle.sh \
  --config .cache/cluster/two_node_bundle.env \
  --run-tag "${RUN_TAG}"
```

### Expected artifacts

- `/mnt/e/data/pdp_retrieve_engine/results/cluster/${RUN_TAG}/runtime_by_N.csv`
- `/mnt/e/data/pdp_retrieve_engine/results/cluster/${RUN_TAG}/benchmark_selection.env`
- `/mnt/e/data/pdp_retrieve_engine/results/cluster/${RUN_TAG}/sequential_topk.csv`
- `/mnt/e/data/pdp_retrieve_engine/results/cluster/${RUN_TAG}/parallel_topk.csv`
- `/mnt/e/data/pdp_retrieve_engine/results/cluster/${RUN_TAG}/correctness.csv`
- `/mnt/e/data/pdp_retrieve_engine/results/cluster/${RUN_TAG}/granularity.csv`
- `/mnt/e/data/pdp_retrieve_engine/results/cluster/${RUN_TAG}/speedup.csv`
- `/mnt/e/data/pdp_retrieve_engine/results/cluster/${RUN_TAG}/faiss/`
- `/mnt/e/data/pdp_retrieve_engine/results/cluster/${RUN_TAG}/analysis/`
- `/mnt/e/data/pdp_retrieve_engine/results/cluster/${RUN_TAG}/figures/`
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
  - `Cluster bundle completed at /mnt/e/data/pdp_retrieve_engine/results/cluster/<run-tag>`
- both:
  - `correctness.csv`
  - `faiss/synthetic_correctness.csv`
  - `faiss/squad_correctness.csv`
  record only `PASS`

### Validated expedited no-FAISS finish for the current machine

The validated final rerun on `2026-06-23` did not restart from zero after the operator decided to skip FAISS. Instead, it reused the finished calibration outputs from the same run tag:

- run tag:
  - `2026-06-23-local-plus-199-e-root-final`
- selected synthetic benchmark point:
  - `N_SELECTED=10000000`
  - `Q=400`
  - `CALIBRATION_MODE=N_PLUS_Q`
- selected parallel timing:
  - `10000000,384,400,10,14,137.86811244,20.44452541,144.11783635`
- selected sequential timing:
  - `10000000,384,400,10,1,792.45887554,0.00000000,792.45887554`
- expedited speedup scale used for the same rerun:
  - `N_SPEEDUP=2000000`

Use this recovery path when:

- Stage 1 calibration has already finished for the run tag
- the operator wants to skip FAISS rather than waiting for the full six-stage wrapper
- the goal is to finish correctness, speedup, figures, and analysis from the same run tag without regenerating the earlier calibration outputs

### Bash

```bash
cd ~/work/Parallel-Retrieval-Engine-for-RAG
RUN_TAG=2026-06-23-local-plus-199-e-root-final
RESULT_DIR=/mnt/e/data/pdp_retrieve_engine/results/cluster/${RUN_TAG}
PROBE_DIR=/mnt/e/data/pdp_retrieve_engine/scratch/cluster_bundle/${RUN_TAG}/probes

mkdir -p "${RESULT_DIR}"

# Reuse the selected Q=400 parallel artifacts from calibration.
cp "${PROBE_DIR}/calibration_parallel_topk_N10000000_Q400.csv" "${RESULT_DIR}/parallel_topk.csv"
cp "${PROBE_DIR}/calibration_parallel_metrics_N10000000_Q400.csv" "${RESULT_DIR}/parallel_metrics.csv"
cp "${PROBE_DIR}/calibration_parallel_run_metrics_N10000000_Q400.csv" "${RESULT_DIR}/parallel_run_metrics.csv"
cp "${RESULT_DIR}/parallel_metrics.csv" "${RESULT_DIR}/granularity.csv"

python3 - <<'PY'
from pathlib import Path
result_dir = Path("/mnt/e/data/pdp_retrieve_engine/results/cluster/2026-06-23-local-plus-199-e-root-final")
result_dir.joinpath("benchmark_selection.env").write_text(
    "N_SELECTED=10000000\n"
    "N_SPEEDUP=2000000\n"
    "P_SELECTED=14\n"
    "D=384\n"
    "Q=400\n"
    "K=10\n"
    "EPSILON=1e-5\n"
    "CALIBRATION_MODE=N_PLUS_Q\n"
    "N_MAX_FEASIBLE=10000000\n",
    encoding="utf-8",
)
PY

python3 ./scripts/benchmark_csv.py \
  summarize-granularity \
  --input "${RESULT_DIR}/granularity.csv" \
  --output "${RESULT_DIR}/granularity_summary.txt"

./build/cluster_release/sequential_retriever \
  --vectors /mnt/e/data/pdp_retrieve_engine/scratch/cluster_bundle/${RUN_TAG}/memory_vectors_N10000000_D384.bin \
  --queries /mnt/e/data/pdp_retrieve_engine/scratch/cluster_bundle/${RUN_TAG}/query_vectors_Q400_D384.bin \
  --topk 10 \
  --output "${RESULT_DIR}/sequential_topk.csv" \
  --run-metrics "${RESULT_DIR}/sequential_run_metrics.csv"

./build/cluster_release/verify_results \
  --sequential "${RESULT_DIR}/sequential_topk.csv" \
  --parallel "${RESULT_DIR}/parallel_topk.csv" \
  --epsilon 1e-5 \
  --output "${RESULT_DIR}/correctness.csv"

# The validated expedited rerun used N_SPEEDUP=2000000.
for P in 2 4 8 10 12 14; do
  HOSTFILE=".cache/cluster/speedup-p${P}.hosts"
  if [ "${P}" -le 10 ]; then
    cat > "${HOSTFILE}" <<EOF
192.168.1.17 slots=${P} max-slots=${P}
EOF
  else
    WORKER=$((P - 10))
    cat > "${HOSTFILE}" <<EOF
192.168.1.17 slots=10 max-slots=10
192.168.1.199 slots=${WORKER} max-slots=${WORKER}
EOF
  fi

  env HWLOC_COMPONENTS=-gl \
    mpirun \
    -x HWLOC_COMPONENTS \
    --mca oob_tcp_disable_ipv6_family 1 \
    --mca oob_tcp_if_include 192.168.1.0/24 \
    --mca btl self,tcp \
    --mca btl_tcp_if_include 192.168.1.0/24 \
    --hostfile "${HOSTFILE}" \
    --map-by slot \
    -np "${P}" \
    ./build/cluster_release/parallel_retriever \
    --vectors .cache/cluster_runtime/${RUN_TAG}/datasets/synthetic/memory_vectors.bin \
    --queries .cache/cluster_runtime/${RUN_TAG}/datasets/synthetic/query_vectors.bin \
    --topk 10 \
    --output "${PROBE_DIR}/speedup_parallel_topk_P${P}.csv" \
    --metrics "${PROBE_DIR}/speedup_parallel_metrics_P${P}.csv" \
    --run-metrics "${PROBE_DIR}/speedup_parallel_run_metrics_P${P}.csv"
done

python3 ./scripts/benchmark_csv.py \
  build-speedup \
  --baseline "${PROBE_DIR}/calibration_speedup_run_metrics_N2000000.csv" \
  --output "${RESULT_DIR}/speedup.csv" \
  "${PROBE_DIR}/speedup_parallel_run_metrics_P2.csv" \
  "${PROBE_DIR}/speedup_parallel_run_metrics_P4.csv" \
  "${PROBE_DIR}/speedup_parallel_run_metrics_P8.csv" \
  "${PROBE_DIR}/speedup_parallel_run_metrics_P10.csv" \
  "${PROBE_DIR}/speedup_parallel_run_metrics_P12.csv" \
  "${PROBE_DIR}/speedup_parallel_run_metrics_P14.csv"

bash ./scripts/run_cluster_postprocess.sh \
  --results-dir "${RESULT_DIR}" \
  --docs-output docs/analysis/latest-cluster-benchmark-review.md
```

### What success looks like

- `correctness.csv` records only `PASS`
- `analysis/final_conclusions.md` explicitly says:
  - `FAISS comparison was skipped for this run`
- `analysis/faiss_analysis.csv` still exists with its fixed header
- `speedup.csv` uses:
  - `N=2000000`
  - `Q=400`
  - `P in {1,2,4,8,10,12,14}`

### Optional repo-local mirror after the bundle finishes

If you want the final cluster outputs to also appear under the repo `results/` tree for easier review or git-side comparison, mirror them back explicitly after the external-storage run:

```bash
cd ~/work/Parallel-Retrieval-Engine-for-RAG
RUN_TAG="$(date +%F)-local-plus-199-full-bundle"
mkdir -p results/cluster/"${RUN_TAG}"
rsync -a \
  /mnt/e/data/pdp_retrieve_engine/results/cluster/"${RUN_TAG}"/ \
  results/cluster/"${RUN_TAG}"/
```

## 13. Regenerate Cluster Analysis And Figures Only

Use this when the raw cluster CSVs already exist but `analysis/`, `figures/`, or `docs/analysis/latest-cluster-benchmark-review.md` need to be rebuilt.

### Bash

```bash
cd ~/work/Parallel-Retrieval-Engine-for-RAG
RUN_TAG="$(date +%F)-local-plus-199-full-bundle"
RESULT_DIR="/mnt/e/data/pdp_retrieve_engine/results/cluster/${RUN_TAG}"

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

- `/mnt/e/data/pdp_retrieve_engine/results/cluster/...`

### What success looks like

- the cluster result directory now contains both:
  - `analysis/`
  - `figures/`
- `docs/analysis/latest-cluster-benchmark-review.md` is refreshed from the cluster run, not left as the checked-in placeholder
- if the run intentionally skipped FAISS:
  - `analysis/final_conclusions.md` states that FAISS was skipped
  - `analysis/faiss_analysis.csv` may contain only the header row

## 14. Output Layout After The Full Bundle

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

## 15. Final Verification Checklist

Run these checks from `rag-head`:

```bash
cd ~/work/Parallel-Retrieval-Engine-for-RAG

RUN_TAG="$(date +%F)-local-plus-199-full-bundle"
RESULT_DIR="/mnt/e/data/pdp_retrieve_engine/results/cluster/${RUN_TAG}"

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
head -n 5 "${RESULT_DIR}/correctness.csv"
head -n 20 "${RESULT_DIR}/analysis/final_conclusions.md"
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

## 16. Optional: Copy Results Back To The Repo Or To A Windows-Mounted Workspace

You only need this if:

- your real benchmark ran from external storage and you want a repo-local mirror under `results/cluster/`
- or your editing workspace is a separate Windows checkout and you want a Windows-visible copy

```bash
RUN_TAG="$(date +%F)-local-plus-199-full-bundle"
mkdir -p ~/work/Parallel-Retrieval-Engine-for-RAG/results/cluster/"${RUN_TAG}"
rsync -a \
  /mnt/e/data/pdp_retrieve_engine/results/cluster/"${RUN_TAG}"/ \
  ~/work/Parallel-Retrieval-Engine-for-RAG/results/cluster/"${RUN_TAG}"/
```

Optional Windows-mounted copy:

```bash
RUN_TAG="$(date +%F)-local-plus-199-full-bundle"
rsync -a \
  /mnt/e/data/pdp_retrieve_engine/results/cluster/"${RUN_TAG}"/ \
  /mnt/d/DS-AI/Parallel-Retrieval-Engine-for-RAG/results/cluster/"${RUN_TAG}"/
```

Adjust `/mnt/d/...` to match the Windows-mounted workspace path you actually use.

## Troubleshooting Shortlist

If this exact runbook stalls:

- `ssh rag-worker1 hostname` works, but `mpirun` hangs before printing anything
  - re-check `HWLOC_COMPONENTS=-gl`
- worker launches but cannot connect back to the head node
  - re-check mirrored networking
  - re-check the Hyper-V firewall inbound allow step
  - verify the worker can open `192.168.1.x:22` on the head node
- head node IP changed after WSL restart
  - update `/etc/hosts`
  - update `~/.ssh/config` if needed
  - regenerate `hosts.local-plus-199`
- `run_cluster_two_node_bundle.sh` refuses to start
  - confirm you launched it from:
    - `~/work/Parallel-Retrieval-Engine-for-RAG`
  - do not launch the real bundle from:
    - `/mnt/d/DS-AI/Parallel-Retrieval-Engine-for-RAG`
- `parallel_retriever` works on one node but hangs across two nodes
  - keep the IPv4-only MPI flags exactly as shown
  - verify the hostfile names resolve correctly on both nodes

For broader cluster problems, continue with [troubleshooting.md](troubleshooting.md).
