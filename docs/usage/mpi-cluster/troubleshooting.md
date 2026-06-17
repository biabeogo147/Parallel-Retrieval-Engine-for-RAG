# MPI Cluster Troubleshooting

This page focuses on the most common problems specific to the three-machine physical MPI cluster workflow.

Unless a section says otherwise, Bash commands assume:

```bash
cd ~/work/Parallel-Retrieval-Engine-for-RAG
```

## The Head Node Cannot SSH To A Worker

**Symptoms**

- `ssh rag@rag-worker1 hostname` hangs or fails
- `mpirun` reports a remote launch failure before `parallel_retriever` starts

**Fix**

On the worker node, confirm that `ssh` is installed and running:

```bash
sudo systemctl status ssh --no-pager
ss -tln | grep ':22'
hostname -I
```

From the head node, retry by IP first:

```bash
ssh rag@192.168.1.11 hostname
```

If the IP works but the hostname does not, fix name resolution as described in `cluster-assembly-and-validation.md`.

**What success looks like**

- The head node can SSH to the worker without a password prompt and without timing out.

## Hostnames Resolve Incorrectly Or Not At All

**Symptoms**

- `ssh rag@rag-worker1 hostname` fails, but `ssh rag@192.168.1.11 hostname` works
- `getent hosts rag-worker1` returns nothing or the wrong IP

**Fix**

Add stable entries to `/etc/hosts` on all three nodes:

```bash
sudo tee -a /etc/hosts >/dev/null <<'EOF'
192.168.1.10 rag-head
192.168.1.11 rag-worker1
192.168.1.12 rag-worker2
EOF
getent hosts rag-head rag-worker1 rag-worker2
```

**What success looks like**

- `getent hosts` resolves the expected IP for every node name on every node.

## A WSL Ubuntu Guest Is Not Reachable From The LAN

**Symptoms**

- the head node cannot SSH to the WSL node
- `hostname -I` inside Ubuntu shows an address that is not reachable from the head node

**Fix**

On the Windows host, confirm mirrored networking is configured:

```powershell
notepad $env:USERPROFILE\.wslconfig
wsl.exe --shutdown
Set-NetFirewallHyperVVMSetting -Name '{40E0AC32-46A5-438A-A0B2-2B479E8F2E90}' -DefaultInboundAction Allow
wsl.exe -d Ubuntu-24.04
```

The `.wslconfig` file should include:

```ini
[wsl2]
networkingMode=mirrored
```

Inside Ubuntu, confirm:

```bash
hostname -I
sudo systemctl status ssh --no-pager
```

If the guest still cannot be reached reliably, do not use that machine as a cluster worker until the networking issue is resolved. Use the native Ubuntu or Multipass path instead for that node.

**What success looks like**

- The head node can SSH to the WSL guest IP.

## A WSL Node Works Once, Then Disappears Later

**Symptoms**

- the WSL node is reachable at first, then stops responding later
- remote MPI launch fails after the Windows machine has been idle

**Why this happens**

- WSL services do not keep the Ubuntu guest alive by themselves.

**Fix**

Before the cluster run, launch the Ubuntu distro on that Windows host and keep it active:

```powershell
wsl.exe -d Ubuntu-24.04
```

Inside the guest, confirm `ssh` is still listening:

```bash
ss -tln | grep ':22'
```

**What success looks like**

- The WSL guest remains reachable during the entire MPI job window.

## A Multipass Guest Is Not Reachable From The LAN

**Symptoms**

- the head node cannot SSH to the Multipass guest
- `multipass info <name>` shows an address that is not usable from the cluster

**Fix**

On the macOS host, confirm the instance is bridged:

```zsh
multipass networks
multipass get local.rag-worker2.bridged
multipass info rag-worker2
```

If needed, reapply the bridging flow:

```zsh
multipass set local.bridged-network=en0
multipass stop rag-worker2
multipass set local.rag-worker2.bridged=true
multipass start rag-worker2
```

Inside the guest, confirm `ssh` is active:

```bash
sudo systemctl status ssh --no-pager
hostname -I
```

**What success looks like**

- The guest exposes a reachable LAN IP and accepts SSH from the head node.

## `mpirun` Launches Locally But Not Remotely

**Symptoms**

- `./build/release/parallel_retriever --help` works locally
- `mpirun --hostfile ...` fails before or during remote startup

**Fix**

Check the three most common causes from the head node:

```bash
ssh rag@rag-worker1 'cd ~/work/Parallel-Retrieval-Engine-for-RAG && hostname && realpath . && test -x ./build/release/parallel_retriever'
ssh rag@rag-worker2 'cd ~/work/Parallel-Retrieval-Engine-for-RAG && hostname && realpath . && test -x ./build/release/parallel_retriever'
mpirun --hostfile .cache/cluster/hosts.cluster --map-by ppr:1:node -np 3 hostname
```

Verify that:

- SSH works without prompting
- the repo path is identical on every node
- the release binary exists on every node
- the hostfile points at the intended machines

**What success looks like**

- `mpirun` can start a trivial remote `hostname` run across the cluster.

## The Repo Path Differs Across Nodes

**Symptoms**

- remote launch works, but the target binary path is missing on one worker
- one machine cloned the repo somewhere other than `~/work/Parallel-Retrieval-Engine-for-RAG`

**Fix**

On every node, confirm:

```bash
realpath ~/work/Parallel-Retrieval-Engine-for-RAG
```

If one node differs, reclone or move the repo so every node matches the canonical path.

**What success looks like**

- The same absolute repo path exists on all three nodes.

## A Worker Is Missing The Release Binary

**Symptoms**

- `mpirun` errors out because `./build/release/parallel_retriever` cannot be found remotely

**Fix**

From the head node, rebuild that worker:

```bash
ssh rag@rag-worker1 'cd ~/work/Parallel-Retrieval-Engine-for-RAG && ./scripts/configure_release.sh && cmake --build build/release'
ssh rag@rag-worker1 'cd ~/work/Parallel-Retrieval-Engine-for-RAG && test -x ./build/release/parallel_retriever'
```

Repeat for `rag-worker2` as needed.

**What success looks like**

- The worker now has an executable `build/release/parallel_retriever`.

## The Data Files Were Not Synced Or Were Synced To The Wrong Path

**Symptoms**

- the parallel run starts but fails to open `data/memory_vectors.bin` or `data/query_vectors.bin`
- one worker still has an older file or no file at all

**Fix**

Resync from the head node:

```bash
mkdir -p data
cp ~/cluster-shared/parallel-rag-data/memory_vectors.bin data/memory_vectors.bin
cp ~/cluster-shared/parallel-rag-data/query_vectors.bin data/query_vectors.bin
rsync -av ~/cluster-shared/parallel-rag-data/memory_vectors.bin rag@rag-worker1:~/work/Parallel-Retrieval-Engine-for-RAG/data/
rsync -av ~/cluster-shared/parallel-rag-data/query_vectors.bin rag@rag-worker1:~/work/Parallel-Retrieval-Engine-for-RAG/data/
rsync -av ~/cluster-shared/parallel-rag-data/memory_vectors.bin rag@rag-worker2:~/work/Parallel-Retrieval-Engine-for-RAG/data/
rsync -av ~/cluster-shared/parallel-rag-data/query_vectors.bin rag@rag-worker2:~/work/Parallel-Retrieval-Engine-for-RAG/data/
```

Then verify:

```bash
ssh rag@rag-worker1 'cd ~/work/Parallel-Retrieval-Engine-for-RAG && ls -l data/memory_vectors.bin data/query_vectors.bin'
ssh rag@rag-worker2 'cd ~/work/Parallel-Retrieval-Engine-for-RAG && ls -l data/memory_vectors.bin data/query_vectors.bin'
```

**What success looks like**

- Every node has the expected files under its local repo `data/` directory.

## OpenMPI Refuses To Run As `root`

**Symptoms**

- `mpirun` prints a root-user warning and exits

**Fix**

The real fix is to run the cluster as a normal Linux user. Use the root override only as a one-off emergency check:

```bash
OMPI_ALLOW_RUN_AS_ROOT=1 OMPI_ALLOW_RUN_AS_ROOT_CONFIRM=1 \
mpirun --hostfile .cache/cluster/hosts.cluster -np 3 ./build/release/parallel_retriever --help
```

Do not normalize a root-based cluster workflow if you can avoid it.

**What success looks like**

- The cluster runs under a normal Linux user, or the emergency help-path check succeeds with the override.
