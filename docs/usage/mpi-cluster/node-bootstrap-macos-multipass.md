# Bootstrap A macOS + Multipass Ubuntu Node

This guide prepares one physical macOS machine to act as one Ubuntu-based node in the three-machine MPI cluster by running Ubuntu 24.04 inside Multipass.

Use this guide for the machine that will become `rag-head`, `rag-worker1`, or `rag-worker2` when that machine provides Ubuntu through a Multipass guest.

## 1. Install Or Verify Multipass On The macOS Host

If Multipass is already installed, you can skip directly to the verification command.

**Prerequisites**

- You are on the macOS host.
- Homebrew is available on this machine, or Multipass is already installed another way.

**zsh**

```zsh
brew install --cask multipass
multipass version
```

If you use the official Multipass installer instead of Homebrew, install it first and then run only the verification command:

```zsh
multipass version
```

**Expected artifacts**

- A working `multipass` command on the macOS host.

**What success looks like**

- `multipass version` prints the installed client and daemon versions.

**Next step**

- Launch the Ubuntu 24.04 guest that will become the cluster node.

## 2. Launch The Ubuntu 24.04 Guest

Use one canonical cluster hostname:

- `rag-head`
- `rag-worker1`
- `rag-worker2`

The example below uses `rag-worker2`.

**Prerequisites**

- Multipass is installed and working.

**zsh**

```zsh
multipass launch 24.04 --name rag-worker2 --cpus 4 --memory 8G --disk 40G
multipass info rag-worker2
```

**Expected artifacts**

- A running Multipass instance named `rag-worker2`.

**What success looks like**

- `multipass info rag-worker2` shows the instance in a running state.

**Next step**

- Bridge the guest onto the LAN so other cluster nodes can reach it over SSH.

## 3. Bridge The Multipass Guest To The LAN

This guide uses the Multipass bridged-network workflow so the Ubuntu guest can participate as a normal LAN node.

**Prerequisites**

- Multipass version supports bridged networking.
- You know the correct host network interface for your Mac, such as `en0`.

**zsh**

```zsh
multipass networks
multipass set local.bridged-network=en0
multipass stop rag-worker2
multipass set local.rag-worker2.bridged=true
multipass start rag-worker2
multipass get local.rag-worker2.bridged
multipass info rag-worker2
```

Replace `en0` if your Mac uses a different interface name.

**Expected artifacts**

- The instance is configured for bridged networking.

**What success looks like**

- `multipass get local.rag-worker2.bridged` returns `true`.
- `multipass info rag-worker2` shows a LAN-reachable IPv4 address for the guest.

**Next step**

- Enter the Ubuntu guest, create or confirm the Linux user `rag`, and then prepare SSH plus the repo toolchain.

## 4. Create Or Confirm The Linux User `rag` Inside Ubuntu

The cluster examples in this repository assume the Linux username `rag` on every Ubuntu node.

Multipass usually creates a default Ubuntu user for you automatically. If you want the canonical cluster username, create `rag` inside the guest before continuing.

Enter the guest:

**zsh**

```zsh
multipass shell rag-worker2
```

Now continue inside Ubuntu.

**Prerequisites**

- You are inside the Ubuntu guest shell.
- The current guest user can run `sudo`.

**Bash**

```bash
whoami
id
getent passwd rag || sudo adduser rag
sudo usermod -aG sudo rag
getent passwd rag
sudo -l -U rag
su - rag
whoami
pwd
```

**Expected artifacts**

- A Linux account named `rag` inside the guest.
- `rag` belongs to the `sudo`-capable admin group inside the guest.

**What success looks like**

- `whoami` prints `rag` after `su - rag`.
- `sudo -l -U rag` succeeds.

**Next step**

- Install SSH and the node utilities while using `rag` inside the Ubuntu guest.

## 5. Install SSH And Node Utilities Inside Ubuntu

**Prerequisites**

- You are inside the Ubuntu guest shell as `rag` or the one Linux username you intentionally chose for the cluster.

**Bash**

```bash
sudo apt update
sudo apt install -y git openssh-server rsync
sudo systemctl enable --now ssh
sudo systemctl status ssh --no-pager
hostnamectl --static
hostname -I
```

**Expected artifacts**

- `git`, `openssh-server`, and `rsync` installed in the guest.
- SSH enabled and active inside Ubuntu.

**What success looks like**

- `systemctl status ssh --no-pager` shows an active SSH service.
- `hostname -I` prints a LAN-visible guest IP.

**Next step**

- Clone the repository and install the repo toolchain inside the guest.

## 6. Clone The Repo And Install The Repo Toolchain

**Prerequisites**

- You are still inside the Ubuntu guest shell.
- You have the repository remote URL.

**Bash**

```bash
mkdir -p ~/work
cd ~/work
git clone <your-remote-url> Parallel-Retrieval-Engine-for-RAG
cd ~/work/Parallel-Retrieval-Engine-for-RAG
./scripts/setup_wsl_dev_env.sh
```

**Expected artifacts**

- `~/work/Parallel-Retrieval-Engine-for-RAG/.git/`
- Ubuntu build dependencies installed inside the guest

**What success looks like**

- The repo exists under the canonical guest path.
- `mpicxx --version`, `mpirun --version`, `cmake --version`, and `ninja --version` all work in the guest.

**Next step**

- Configure and build the node.

## 7. Configure, Build, And Smoke-Test The Node

**Prerequisites**

- The repo exists inside the guest at `~/work/Parallel-Retrieval-Engine-for-RAG`.

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

- Debug build, tests, and smoke checks pass.
- Release binaries exist under `build/release/`.

**Next step**

- Record the guest identity facts needed by the head node.

## 8. Record Node Facts For The Head Node

**Prerequisites**

- The guest is fully built and the SSH service is active.

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

- An operator note containing the cluster hostname, Linux username, guest IP, and repo path.

**What success looks like**

- You know exactly how the head node should reach the guest.
- The SSH listener is active on port 22.

**Next step**

- Repeat this flow on the other physical machines, then move to [cluster-assembly-and-validation.md](cluster-assembly-and-validation.md) from the head node.

## Important macOS Host Reminder

This repository still runs inside Ubuntu, not directly on macOS. Treat the Multipass guest as the real cluster node:

- clone the repo inside the Ubuntu guest
- install OpenMPI inside the guest
- build and run the binaries inside the guest
- use the guest IP, not the macOS host IP, in the cluster topology
