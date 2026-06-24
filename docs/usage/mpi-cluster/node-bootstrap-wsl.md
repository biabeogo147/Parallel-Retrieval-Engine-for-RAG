# Bootstrap A Windows + WSL2 Node

This guide prepares one physical Windows machine to act as one Ubuntu-based node in the three-machine MPI cluster.

Use this guide for the machine that will become `rag-head`, `rag-worker1`, or `rag-worker2` when that machine provides Ubuntu through WSL2.

## 1. Install Or Verify Ubuntu 24.04 In WSL

**Prerequisites**

- You are on the Windows host.
- You can open an elevated or normal PowerShell session as needed.
- You have a remote URL for this repository.

**PowerShell**

```powershell
wsl --install -d Ubuntu-24.04
wsl -l -v
wsl.exe -d Ubuntu-24.04
```

**Expected artifacts**

- A WSL distro named `Ubuntu-24.04`.
- A first-run Ubuntu user account created inside the distro.

**What success looks like**

- `wsl -l -v` lists `Ubuntu-24.04`.
- The Ubuntu shell opens successfully.
- Inside Ubuntu, `uname -s` prints `Linux`.

**Next step**

- Create or confirm the Linux user `rag`, then configure the WSL node so the Ubuntu guest can participate in LAN-based SSH and MPI workflows.

## 2. Create Or Confirm The Linux User `rag`

The cluster examples in this repository assume the Linux username `rag` on every Ubuntu node.

If this Ubuntu distro has not completed first-run setup yet, create that user during the first Ubuntu prompt flow:

- enter `rag` when Ubuntu asks for the new UNIX username
- choose a password for `rag`

If the distro already exists with another default user and you still want the canonical username, create `rag` explicitly and make it the default WSL user.

**Prerequisites**

- `Ubuntu-24.04` already opens successfully in WSL.
- You can run `sudo` as the current Ubuntu user.

**Bash**

```bash
whoami
id
getent passwd rag || sudo adduser rag
sudo usermod -aG sudo rag
sudo tee /etc/wsl.conf >/dev/null <<'EOF'
[boot]
systemd=true

[user]
default=rag
EOF
getent passwd rag
```

Then restart the distro from Windows:

**PowerShell**

```powershell
wsl.exe --shutdown
wsl.exe -d Ubuntu-24.04
```

Back inside Ubuntu, verify:

**Bash**

```bash
whoami
id
sudo -l
```

**Expected artifacts**

- A Linux account named `rag`.
- `/etc/wsl.conf` includes a `[user]` section with `default=rag`.

**What success looks like**

- `whoami` prints `rag` after reopening Ubuntu.
- `sudo -l` works for the `rag` user.

**Next step**

- Configure the Windows host so the Ubuntu guest is LAN-reachable for SSH and MPI.

## 3. Enable Mirrored Networking On The Windows Host

Mirrored networking is the recommended path when a WSL guest must be reachable from the local network.

**Prerequisites**

- `Ubuntu-24.04` is installed under WSL2.
- The Windows host is running a WSL version that supports mirrored networking.
- You can edit the Windows user's `.wslconfig` file.

**PowerShell**

```powershell
notepad $env:USERPROFILE\.wslconfig
```

Put this block under `[wsl2]` in `%UserProfile%\.wslconfig`:

```ini
[wsl2]
networkingMode=mirrored
```

Then restart WSL and allow inbound Hyper-V traffic:

```powershell
wsl.exe --shutdown
Set-NetFirewallHyperVVMSetting -Name '{40E0AC32-46A5-438A-A0B2-2B479E8F2E90}' -DefaultInboundAction Allow
wsl.exe -d Ubuntu-24.04
```

**Expected artifacts**

- `%UserProfile%\.wslconfig` includes `networkingMode=mirrored`.

**What success looks like**

- After relaunching Ubuntu, `hostname -I` inside the guest prints a LAN-visible IP address.
- You can later SSH to that guest IP from the head node during cluster assembly.

**Next step**

- Verify systemd support so the `ssh` service can be managed cleanly inside Ubuntu.

## 4. Verify Or Enable systemd In Ubuntu

Current Ubuntu versions installed through `wsl --install` usually enable systemd by default. This section verifies that assumption and gives a fallback if needed.

**Prerequisites**

- You are inside the Ubuntu guest shell.

**Bash**

```bash
ps -p 1 -o comm=
systemctl list-unit-files --type=service | head
```

If PID 1 is not `systemd`, enable it with:

```bash
sudo tee /etc/wsl.conf >/dev/null <<'EOF'
[boot]
systemd=true
EOF
exit
```

Then restart the guest from Windows:

**PowerShell**

```powershell
wsl.exe --shutdown
wsl.exe -d Ubuntu-24.04
```

Back inside Ubuntu, verify again:

**Bash**

```bash
ps -p 1 -o comm=
systemctl status --no-pager
```

**Expected artifacts**

- `systemd` is available as PID 1.
- `/etc/wsl.conf` contains the `[boot]` block if fallback enablement was required.

**What success looks like**

- `ps -p 1 -o comm=` prints `systemd`.
- `systemctl` commands no longer fail with a WSL-init error.

**Next step**

- Install SSH and the node-local prerequisites used by the cluster workflow.

## 5. Install SSH And Node Utilities

**Prerequisites**

- You are inside Ubuntu as the `rag` user or another normal Linux user you intentionally chose for every node.
- `systemd` is available.

**Bash**

```bash
sudo apt update
sudo apt install -y git openssh-server rsync
sudo systemctl enable --now ssh
sudo systemctl status ssh --no-pager
hostname -I
```

**Expected artifacts**

- `openssh-server` installed.
- `rsync` installed.
- `ssh` service enabled and started.

**What success looks like**

- `systemctl status ssh --no-pager` reports the service as active.
- `hostname -I` prints at least one usable IP address.

**Next step**

- Give the Ubuntu guest a stable cluster identity and then clone the repository.

## 6. Set The Node Identity

Use one of the canonical names from this bundle:

- `rag-head`
- `rag-worker1`
- `rag-worker2`

**Prerequisites**

- You know which role this machine will play in the cluster.

**Bash**

```bash
sudo hostnamectl set-hostname rag-worker1
hostnamectl --static
whoami
```

**Expected artifacts**

- A stable Linux hostname for the Ubuntu guest.

**What success looks like**

- `hostnamectl --static` prints the chosen cluster hostname.
- `whoami` prints `rag` or the one Linux username you will reuse on the other nodes.

**Next step**

- Clone the repository into the canonical path inside Ubuntu.

## 7. Clone The Repo And Install The Repo Toolchain

**Prerequisites**

- `git` is installed.
- You are inside Ubuntu as `rag` or the one Linux username you intentionally chose for the whole cluster.

**Bash**

```bash
mkdir -p ~/work
cd ~/work
git clone <your-remote-url> Parallel-Retrieval-Engine-for-RAG
cd ~/work/Parallel-Retrieval-Engine-for-RAG
bash ./scripts/setup_wsl_dev_env.sh
```

**Expected artifacts**

- `~/work/Parallel-Retrieval-Engine-for-RAG/.git/`
- `~/work/Parallel-Retrieval-Engine-for-RAG/scripts/`
- `~/work/Parallel-Retrieval-Engine-for-RAG/docs/`

**What success looks like**

- The repo exists at the canonical path.
- The setup script finishes without error.
- `mpicxx --version`, `mpirun --version`, `cmake --version`, and `ninja --version` all work.

**Next step**

- Configure and build the debug and release trees used by the cluster workflow.

## 8. Configure, Build, And Smoke-Test The Node

**Prerequisites**

- The repo exists at `~/work/Parallel-Retrieval-Engine-for-RAG`.
- `bash ./scripts/setup_wsl_dev_env.sh` already succeeded.

**Bash**

```bash
cd ~/work/Parallel-Retrieval-Engine-for-RAG
bash ./scripts/configure_debug.sh
cmake --build build/debug
ctest --test-dir build/debug --output-on-failure
bash ./scripts/run_smoke_tests.sh
bash ./scripts/configure_release.sh
cmake --build build/release
```

**Expected artifacts**

- `build/debug/sequential_retriever`
- `build/debug/parallel_retriever`
- `build/debug/verify_results`
- `build/release/sequential_retriever`
- `build/release/parallel_retriever`

**What success looks like**

- Debug build, `CTest`, and smoke checks all exit `0`.
- Release binaries exist under `build/release/`.

**Next step**

- Record the node facts that the head node will need during cluster assembly.

## 9. Record Node Facts For The Head Node

Before leaving this machine, record these facts:

- hostname
- Linux username
- LAN-reachable Ubuntu IP
- repo path

**Prerequisites**

- The node has been fully built and smoke-tested.

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

- A short operator note with the node identity facts.

**What success looks like**

- You know exactly which hostname, username, and IP this node exposes to the head node.
- `ss -tln | grep ':22'` shows the SSH listener.

**Next step**

- Repeat this bootstrap flow on the other physical machines, then move to [cluster-assembly-and-validation.md](cluster-assembly-and-validation.md) from the head node.

## Important WSL Node Reminder

WSL systemd services do not keep the guest alive by themselves. Before any multi-node run:

- launch `wsl.exe -d Ubuntu-24.04` on the Windows host
- keep the Ubuntu guest running during the MPI job window
- verify that `ssh` is listening inside the guest

If you cannot keep the WSL guest reliably running and reachable, use the native Ubuntu or Multipass bootstrap paths instead for that node.
