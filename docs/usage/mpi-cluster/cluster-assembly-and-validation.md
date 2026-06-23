# Cluster Assembly And Validation

This guide starts after all physical machines have already finished one of the node bootstrap guides.

All commands below run from the head node unless a section explicitly says otherwise.

The examples assume:

- head node hostname: `rag-head`
- worker node hostnames: `rag-worker1`, `rag-worker2`
- Linux username on all nodes: `rag`
- canonical repo path on all nodes: `~/work/Parallel-Retrieval-Engine-for-RAG`
- authoritative shared-data path on the head node: `~/cluster-shared/parallel-rag-data`

## 1. Confirm The Three Nodes Are Ready

**Prerequisites**

- All three machines completed one of the node bootstrap guides.
- Each node has:
  - Ubuntu 24.04 shell access
  - `ssh` listening
  - repo cloned to `~/work/Parallel-Retrieval-Engine-for-RAG`
  - `build/release/parallel_retriever` present

**Bash**

```bash
cd ~/work/Parallel-Retrieval-Engine-for-RAG
hostnamectl --static
whoami
realpath .
test -x ./build/release/parallel_retriever
test -x ./build/release/sequential_retriever
test -x ./build/release/verify_results
```

Run the same checks on `rag-worker1` and `rag-worker2`.

**Expected artifacts**

- None. This is a readiness check only.

**What success looks like**

- Every node has the same repo path and the same release binaries.

**Next step**

- Stabilize hostname resolution across the three Ubuntu environments.

## 2. Stabilize Hostname Resolution

If your LAN already has stable DNS for the three node names, keep using that. Otherwise, add fixed entries to `/etc/hosts` on all three Ubuntu environments.

Example LAN addresses:

- `192.168.1.10` -> `rag-head`
- `192.168.1.11` -> `rag-worker1`
- `192.168.1.12` -> `rag-worker2`

**Prerequisites**

- You know the actual LAN IP address for each Ubuntu node.

**Bash**

```bash
sudo tee -a /etc/hosts >/dev/null <<'EOF'
192.168.1.10 rag-head
192.168.1.11 rag-worker1
192.168.1.12 rag-worker2
EOF
getent hosts rag-head rag-worker1 rag-worker2
```

Run this on all three nodes, replacing the example IPs with the actual ones.

**Expected artifacts**

- `/etc/hosts` contains stable entries for all three nodes when DNS is not available.

**What success looks like**

- `getent hosts rag-head rag-worker1 rag-worker2` resolves all three names on every node.

**Next step**

- Configure passwordless SSH from the head node to the workers.

## 3. Configure Passwordless SSH From The Head Node

OpenMPI remote launch is simplest when the head node can SSH to every worker without interactive password prompts.

**Prerequisites**

- `ssh` is active on every worker node.
- The same Linux username exists on every node, or you know the per-node usernames.

**Bash**

```bash
cd ~/work/Parallel-Retrieval-Engine-for-RAG
mkdir -p ~/.ssh
chmod 700 ~/.ssh
test -f ~/.ssh/id_ed25519 || ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -N ""
ssh-copy-id rag@rag-worker1
ssh-copy-id rag@rag-worker2
ssh rag@rag-worker1 hostname
ssh rag@rag-worker2 hostname
```

If `ssh-copy-id` is missing, install it on the head node:

```bash
sudo apt update
sudo apt install -y openssh-client
```

**Expected artifacts**

- `~/.ssh/id_ed25519`
- authorized public keys installed on both worker nodes

**What success looks like**

- `ssh rag@rag-worker1 hostname` and `ssh rag@rag-worker2 hostname` both return the expected hostnames without asking for a password.

**Next step**

- Create repo-local hostfile and SSH-config working copies from the bundled examples.

## 4. Create The Local Hostfile And SSH Config

This guide keeps cluster operator templates under `.cache/cluster/` so they stay repo-local and untracked.

The OpenMPI hostfile is canonical for `mpirun`. The bundled `ssh_config` file is only a convenience template for the human operator. If you rely on SSH aliases beyond the explicit `ssh -F` checks below, merge the relevant stanzas into `~/.ssh/config`.

**Prerequisites**

- Passwordless SSH works from the head node to both workers.

**Bash**

```bash
cd ~/work/Parallel-Retrieval-Engine-for-RAG
mkdir -p .cache/cluster
cp docs/usage/mpi-cluster/examples/hosts.example .cache/cluster/hosts.cluster
cp docs/usage/mpi-cluster/examples/ssh_config.example .cache/cluster/ssh_config
```

Edit both files with the real IPs, usernames, and slot counts:

```bash
cd ~/work/Parallel-Retrieval-Engine-for-RAG
nano .cache/cluster/hosts.cluster
nano .cache/cluster/ssh_config
```

Then verify the template explicitly:

```bash
cd ~/work/Parallel-Retrieval-Engine-for-RAG
ssh -F .cache/cluster/ssh_config rag-worker1 hostname
ssh -F .cache/cluster/ssh_config rag-worker2 hostname
cat .cache/cluster/hosts.cluster
```

**Expected artifacts**

- `.cache/cluster/hosts.cluster`
- `.cache/cluster/ssh_config`

**What success looks like**

- The SSH config resolves both workers successfully.
- The hostfile lists exactly the three nodes you intend to use.
- You understand that `mpirun` reads the hostfile, while `ssh_config` is only an operator convenience unless you merge it into `~/.ssh/config`.

**Next step**

- Create the authoritative shared-data area on the head node and place runtime datasets there.

## 5. Create The Authoritative Shared Dataset Copy

This guide uses the head node as the authoritative source for cluster-ready datasets.

**Prerequisites**

- Release binaries exist on the head node.

**Bash**

```bash
cd ~/work/Parallel-Retrieval-Engine-for-RAG
mkdir -p ~/cluster-shared/parallel-rag-data
./build/release/generate_vectors --N 64 --D 8 --output ~/cluster-shared/parallel-rag-data/memory_vectors.bin
./build/release/generate_queries --Q 5 --D 8 --output ~/cluster-shared/parallel-rag-data/query_vectors.bin
./build/release/inspect_dataset --input ~/cluster-shared/parallel-rag-data/memory_vectors.bin
./build/release/inspect_dataset --input ~/cluster-shared/parallel-rag-data/query_vectors.bin
```

**Expected artifacts**

- `~/cluster-shared/parallel-rag-data/memory_vectors.bin`
- `~/cluster-shared/parallel-rag-data/query_vectors.bin`

**What success looks like**

- Both files exist in the authoritative shared-data directory.
- `inspect_dataset` reports the expected header fields.

**Next step**

- Synchronize those authoritative files into the repo-local `data/` directory on all three nodes.

## 6. Sync Runtime Data Into The Local Repo On Every Node

Only the head node manages the authoritative copy. Each node receives its own local runtime copy under `data/`.

**Prerequisites**

- The authoritative shared-data files already exist on the head node.
- SSH from the head node to both workers already works.

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
ssh rag@rag-worker1 'cd ~/work/Parallel-Retrieval-Engine-for-RAG && ls -l data/memory_vectors.bin data/query_vectors.bin'
ssh rag@rag-worker2 'cd ~/work/Parallel-Retrieval-Engine-for-RAG && ls -l data/memory_vectors.bin data/query_vectors.bin'
```

**Expected artifacts**

- `data/memory_vectors.bin`
- `data/query_vectors.bin`

on the head node and both worker nodes.

**What success looks like**

- Both workers show the expected runtime files under their local repo `data/` directories.

**Next step**

- Run MPI connectivity and remote-launch validation.

## 7. Validate MPI Connectivity And Remote Launch

Use the hostfile from `.cache/cluster/`.

**Prerequisites**

- The hostfile has been edited with the real hosts and slot counts.
- SSH works without passwords.
- Every node has the same release binary paths.

**Bash**

```bash
cd ~/work/Parallel-Retrieval-Engine-for-RAG
mpirun --hostfile .cache/cluster/hosts.cluster -np 3 hostname
mpirun --hostfile .cache/cluster/hosts.cluster -np 3 ./build/release/parallel_retriever --help
```

If you want one-rank-per-node placement explicitly for the connectivity smoke, use:

```bash
cd ~/work/Parallel-Retrieval-Engine-for-RAG
mpirun --hostfile .cache/cluster/hosts.cluster --map-by ppr:1:node -np 3 hostname
```

**Expected artifacts**

- No new files are required for the help-path validation.

**What success looks like**

- `hostname` shows that remote launch works across the cluster.
- `parallel_retriever --help` exits `0`.
- Only rank 0 prints the help text.

**Next step**

- Run the small synthetic end-to-end cluster validation.

## 8. Run The Small Synthetic End-To-End Validation

This stage confirms that the three-machine MPI path, sequential comparison path, and correctness checker all work together.

**Prerequisites**

- Local runtime datasets already exist under `data/` on all nodes.
- The connectivity validation already succeeded.

**Bash**

```bash
cd ~/work/Parallel-Retrieval-Engine-for-RAG
mpirun --hostfile .cache/cluster/hosts.cluster -np 3 ./build/release/parallel_retriever \
  --vectors data/memory_vectors.bin \
  --queries data/query_vectors.bin \
  --topk 3 \
  --output results/parallel_topk_cluster.csv \
  --metrics results/parallel_metrics_cluster.csv
./build/release/sequential_retriever \
  --vectors data/memory_vectors.bin \
  --queries data/query_vectors.bin \
  --topk 3 \
  --output results/sequential_topk_cluster.csv
./build/release/verify_results \
  --sequential results/sequential_topk_cluster.csv \
  --parallel results/parallel_topk_cluster.csv \
  --epsilon 1e-5 \
  --output results/correctness_cluster.csv
```

**Expected artifacts**

- `results/parallel_topk_cluster.csv`
- `results/parallel_metrics_cluster.csv`
- `results/sequential_topk_cluster.csv`
- `results/correctness_cluster.csv`

**What success looks like**

- `verify_results` prints `All queries PASS`.
- The output CSVs appear on the head node under `results/`.

**Next step**

- Move to [cluster-runbook.md](cluster-runbook.md) for the repeatable day-to-day cluster operating flow.

## 9. Optional Worker Result Collection

The canonical retriever outputs are written by rank 0 on the head node, so you usually do not need to pull worker `results/` directories. Use this only when you manually created extra worker-local artifacts.

**Prerequisites**

- You intentionally created worker-local debug outputs or logs.

**Bash**

```bash
cd ~/work/Parallel-Retrieval-Engine-for-RAG
mkdir -p results/worker1-results results/worker2-results
rsync -av rag@rag-worker1:~/work/Parallel-Retrieval-Engine-for-RAG/results/ results/worker1-results/
rsync -av rag@rag-worker2:~/work/Parallel-Retrieval-Engine-for-RAG/results/ results/worker2-results/
```

**Expected artifacts**

- `results/worker1-results/`
- `results/worker2-results/`

**What success looks like**

- Any worker-local debug files are now available on the head node.

**Next step**

- Continue with larger manual runs in [cluster-runbook.md](cluster-runbook.md).
