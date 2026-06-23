# 2026-06-22 2-Node Local Plus 192.168.1.199 Cluster Benchmark

## Objective

Set up and validate a concrete two-node MPI cluster using:

- local machine as the head node
- Ubuntu server `192.168.1.199` as the worker node
- normalized Linux user `rag` on both nodes

and run the manual benchmark profile:

- `N=100000`
- `D=384`
- `Q=100`
- `k=10`

while updating the canonical cluster-operation docs in the same task.

## Scope

Included:

- normalize the real local WSL head node and the real Ubuntu server worker
- create or confirm user `rag`
- validate release builds on both nodes
- configure passwordless SSH from head to worker
- assemble a two-node hostfile
- run cluster smoke validation
- run the canonical manual sequential + parallel + verify workflow
- copy the generated cluster artifacts into the current workspace `results/cluster/`
- update the canonical docs with the concrete two-node example and the real operational findings

Excluded:

- making the Phase 6-8 benchmark scripts cluster-aware
- replacing the single-machine automation flow
- changing any retrieval algorithm, dataset format, or CSV schema

## Architecture Summary

The validated topology is:

- `rag-head`
  - Ubuntu 24.04 under WSL2
  - WSL-native repo checkout at `~/work/Parallel-Retrieval-Engine-for-RAG`
  - detected `LOCAL_SLOTS=10`
- `rag-worker1`
  - native Ubuntu server at `192.168.1.199`
  - repo checkout at `~/work/Parallel-Retrieval-Engine-for-RAG`
  - fixed `SERVER_SLOTS=4`

Concrete hostfile:

```text
rag-head slots=10 max-slots=10
rag-worker1 slots=4 max-slots=4
```

Total MPI process budget:

```text
P_TOTAL = 14
```

The validated MPI runtime controls for the WSL head node were:

- `HWLOC_COMPONENTS=-gl`
- `--mca oob_tcp_disable_ipv6_family 1`
- `--mca oob_tcp_if_include 192.168.1.0/24`
- `--mca btl self,tcp`
- `--mca btl_tcp_if_include 192.168.1.0/24`

The validated Windows host-side prerequisite for mirrored-mode WSL inbound LAN traffic was:

```powershell
Set-NetFirewallHyperVVMSetting `
  -Name '{40E0AC32-46A5-438A-A0B2-2B479E8F2E90}' `
  -DefaultInboundAction Allow
```

## Files Modified

- `docs/usage/mpi-cluster/cluster-assembly-and-validation.md`
- `docs/usage/mpi-cluster/cluster-runbook.md`
- `docs/usage/results-csv-reference.md`
- `docs/development/developer_guide.md`
- `docs/plans/2026-06-22-2-node-local-plus-199-cluster-benchmark.md`

Generated workspace-local artifacts:

- `results/cluster/2026-06-22-local-plus-199/`
- `.cache/cluster/run_two_node_local_plus_199.sh`
- `.cache/cluster/hyperv-firewall.txt`

## Implementation Summary

### 1. Local head node normalization

- confirmed WSL distro `Ubuntu-24.04`
- created Linux user `rag`
- enabled and validated `sshd`
- cloned the repo to `~/work/Parallel-Retrieval-Engine-for-RAG`
- built the release binaries in the WSL-native checkout
- enabled mirrored networking in `.wslconfig`
- configured Hyper-V inbound allowance so the worker could connect back to dynamic MPI ports

### 2. Remote worker normalization

- connected to the Ubuntu server bootstrap account
- created Linux user `rag`
- granted `sudo`
- changed hostname to `rag-worker1`
- cloned the repo to `~/work/Parallel-Retrieval-Engine-for-RAG`
- built the release binaries there

### 3. Cluster assembly

- generated an SSH key for `rag@rag-head`
- installed the public key into `rag@rag-worker1`
- validated `ssh rag@rag-worker1 hostname`
- created `.cache/cluster/hosts.local-plus-199` in the WSL-native checkout
- validated a two-node `hostname` MPI smoke through the real hostfile

### 4. Smoke workflow

Validated:

- `N=64`
- `D=8`
- `Q=5`
- `k=3`
- one MPI rank per node

Outputs matched and `verify_results` reported `All queries PASS`.

### 5. Canonical manual benchmark workflow

Validated:

- `N=100000`
- `D=384`
- `Q=100`
- `k=10`
- `P=14`

Artifacts were generated under the WSL-native checkout and then synchronized into the current workspace:

- `results/cluster/2026-06-22-local-plus-199/sequential_topk.csv`
- `results/cluster/2026-06-22-local-plus-199/sequential_run_metrics.csv`
- `results/cluster/2026-06-22-local-plus-199/parallel_topk.csv`
- `results/cluster/2026-06-22-local-plus-199/parallel_metrics.csv`
- `results/cluster/2026-06-22-local-plus-199/parallel_run_metrics.csv`
- `results/cluster/2026-06-22-local-plus-199/correctness.csv`
- `results/cluster/2026-06-22-local-plus-199/hostfile.snapshot.txt`
- `results/cluster/2026-06-22-local-plus-199/run_notes.txt`

## Acceptance Results

### Environment checks

- local WSL head node:
  - `whoami` -> `rag`
  - hostname set to `rag-head`
  - repo available at `~/work/Parallel-Retrieval-Engine-for-RAG`
  - `sshd` listening
- Ubuntu worker:
  - hostname set to `rag-worker1`
  - repo available at `~/work/Parallel-Retrieval-Engine-for-RAG`
  - release binaries present
- SSH:
  - `ssh rag@rag-worker1 hostname` succeeded

### MPI connectivity checks

- two-node `hostname` smoke wrote:

```text
rag-head
rag-worker1
```

- `parallel_retriever --help` succeeded across two nodes with the validated WSL-specific MPI flags

### Benchmark acceptance checks

- `correctness.csv` recorded `PASS` for all queries
- `parallel_metrics.csv` contains `15` lines
  - one header row
  - `14` rank rows
- `parallel_topk.csv` contains `1001` lines
  - one header row
  - `100 * 10` retrieved rows
- `sequential_topk.csv` contains `1001` lines
- `parallel_run_metrics.csv` contains one data row:

```text
100000,384,100,10,14,0.34452429,0.22751977,0.51632384
```

- `sequential_run_metrics.csv` contains one data row:

```text
100000,384,100,10,1,1.69749336,0.00000000,1.69749336
```

## Verification Commands

Environment and cluster setup:

```bash
ssh rag@rag-worker1 hostname
lscpu -p=Core,Socket | grep -v '^#' | sort -u | wc -l
```

Validated MPI smoke:

```bash
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

Canonical run:

```bash
bash /mnt/d/DS-AI/Parallel-Retrieval-Engine-for-RAG/.cache/cluster/run_two_node_local_plus_199.sh
```

Workspace verification:

```powershell
Get-ChildItem -File -Recurse results\cluster\2026-06-22-local-plus-199
(Get-Content results\cluster\2026-06-22-local-plus-199\parallel_metrics.csv | Measure-Object -Line).Lines
(Get-Content results\cluster\2026-06-22-local-plus-199\parallel_topk.csv | Measure-Object -Line).Lines
Get-Content results\cluster\2026-06-22-local-plus-199\correctness.csv | Select-Object -First 5
```

## Assumptions And Defaults

- local machine remains the head node
- worker node remains `192.168.1.199`
- runtime user remains `rag` on both nodes
- worker slot budget remains fixed at `4`
- current validated head-node slot count is `10`, but operators should still re-run the physical-core detection command if the local hardware changes
- this task keeps multi-node execution manual and explicit
- top-level `results/` remains gitignored, so the generated cluster-result directory is a repo-local artifact, not a tracked deliverable by default
