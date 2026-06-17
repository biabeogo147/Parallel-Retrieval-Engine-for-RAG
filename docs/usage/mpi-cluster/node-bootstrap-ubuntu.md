# Bootstrap A Native Ubuntu 24.04 Node

This guide prepares one physical computer running native Ubuntu 24.04 to act as one node in the three-machine MPI cluster.

Use this guide for the machine that will become `rag-head`, `rag-worker1`, or `rag-worker2` when that machine runs Ubuntu directly on bare metal.

## 1. Confirm The Base OS And Cluster Role

Pick one canonical hostname before you touch the repo:

- `rag-head`
- `rag-worker1`
- `rag-worker2`

**Prerequisites**

- The machine already boots into Ubuntu 24.04.
- You can use `sudo`.

**Bash**

```bash
uname -s
lsb_release -ds
sudo hostnamectl set-hostname rag-worker1
hostnamectl --static
whoami
hostname -I
```

**Expected artifacts**

- A stable Ubuntu hostname.

**What success looks like**

- `lsb_release -ds` identifies Ubuntu 24.04.
- `hostnamectl --static` prints the chosen cluster name.
- `hostname -I` prints a LAN IP that the head node can reach.

**Next step**

- Install the node packages needed for Git, SSH, data sync, and the repo toolchain.

## 2. Install Git, SSH, And Rsync

**Prerequisites**

- The machine has network access to Ubuntu package repositories.

**Bash**

```bash
sudo apt update
sudo apt install -y git openssh-server rsync
sudo systemctl enable --now ssh
sudo systemctl status ssh --no-pager
```

If you use `ufw`, allow SSH before closing your current terminal:

```bash
sudo ufw allow OpenSSH
sudo ufw status
```

**Expected artifacts**

- `git`, `openssh-server`, and `rsync` installed.
- `ssh` service enabled and active.

**What success looks like**

- `systemctl status ssh --no-pager` reports an active service.
- If `ufw` is enabled, `OpenSSH` is allowed.

**Next step**

- Clone the repository into the canonical working path.

## 3. Clone The Repo Into The Canonical Path

**Prerequisites**

- `git` is installed.
- You have the remote URL for the repository.

**Bash**

```bash
mkdir -p ~/work
cd ~/work
git clone <your-remote-url> Parallel-Retrieval-Engine-for-RAG
cd ~/work/Parallel-Retrieval-Engine-for-RAG
```

**Expected artifacts**

- `~/work/Parallel-Retrieval-Engine-for-RAG/.git/`
- `~/work/Parallel-Retrieval-Engine-for-RAG/scripts/`
- `~/work/Parallel-Retrieval-Engine-for-RAG/docs/`

**What success looks like**

- `realpath .` resolves to `~/work/Parallel-Retrieval-Engine-for-RAG` or its expanded equivalent.
- The repository root files are present.

**Next step**

- Install the repo-local development and MPI toolchain.

## 4. Install The Repo Toolchain

**Prerequisites**

- The repository exists at the canonical path.

**Bash**

```bash
cd ~/work/Parallel-Retrieval-Engine-for-RAG
./scripts/setup_wsl_dev_env.sh
```

**Expected artifacts**

- OpenMPI, CMake, Ninja, and the other repo dependencies installed on the node.

**What success looks like**

- `mpicxx --version`, `mpirun --version`, `cmake --version`, and `ninja --version` all work.

**Next step**

- Configure and build the debug and release trees.

## 5. Configure, Build, And Smoke-Test The Node

**Prerequisites**

- `./scripts/setup_wsl_dev_env.sh` already succeeded.

**Bash**

```bash
cd ~/work/Parallel-Retrieval-Engine-for-RAG
./scripts/configure_debug.sh
cmake --build build/debug
ctest --test-dir build/debug --output-on-failure
./scripts/run_smoke_tests.sh
./scripts/configure_release.sh
cmake --build build/release
```

**Expected artifacts**

- `build/debug/parallel_retriever`
- `build/release/parallel_retriever`
- `build/debug/verify_results`

**What success looks like**

- The debug build, tests, and smoke commands all exit `0`.
- Release binaries exist under `build/release/`.

**Next step**

- Record the node facts needed by the head node for cluster assembly.

## 6. Record Node Facts For Cluster Assembly

**Prerequisites**

- The node is fully built and reachable on the LAN.

**Bash**

```bash
cd ~/work/Parallel-Retrieval-Engine-for-RAG
hostnamectl --static
whoami
hostname -I
realpath .
ss -tln | grep ':22'
```

**Expected artifacts**

- An operator note containing the hostname, Linux username, and LAN IP.

**What success looks like**

- You know exactly how the head node should reach this worker.
- The SSH listener is visible on port 22.

**Next step**

- Repeat this flow on the other physical machines, then move to [cluster-assembly-and-validation.md](cluster-assembly-and-validation.md) on the head node.
