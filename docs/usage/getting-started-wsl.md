# Getting Started In WSL

This guide is the onboarding path for a new developer after cloning the repository.

## 1. Install Or Launch Ubuntu 24.04

**Prerequisites**

- You are on the Windows host.
- You have permission to install or enable WSL if it is not already installed.

**PowerShell**

```powershell
wsl --install -d Ubuntu-24.04
```

If Ubuntu is already installed, open it from Windows Terminal or launch it directly:

```powershell
wsl.exe -d Ubuntu-24.04
```

**Expected result**

- `Ubuntu-24.04` exists as a WSL distro.
- You can open a Linux shell.

**What success looks like**

- `uname -s` inside the shell prints `Linux`.

**Next step**

- Move into the canonical workspace and clone the repository there.

## 2. Clone Into The Canonical WSL Workspace

**Prerequisites**

- You are inside Ubuntu WSL.
- You have a usable remote URL for the repository.

If `git` is missing in Ubuntu, install it first:

```bash
sudo apt update
sudo apt install -y git
```

**Bash**

```bash
mkdir -p ~/work
cd ~/work
git clone <your-remote-url> Parallel-Retrieval-Engine-for-RAG
cd ~/work/Parallel-Retrieval-Engine-for-RAG
```

**Expected artifacts**

- `.git/`
- `README.md`
- `scripts/`
- `docs/`

**What success looks like**

- `pwd` prints `~/work/Parallel-Retrieval-Engine-for-RAG` or the expanded equivalent.
- `ls` shows the repository root files and folders.

**Next step**

- Install the development toolchain used by this project.

## 3. Install The Ubuntu Toolchain

**Prerequisites**

- You are at the repository root.
- Network access to Ubuntu package repositories is available.

**Bash**

```bash
cd ~/work/Parallel-Retrieval-Engine-for-RAG
./scripts/setup_wsl_dev_env.sh
```

**Expected result**

The script installs and verifies these tools:

- `mpicxx`
- `mpirun`
- `cmake`
- `ninja`

**What success looks like**

- The script finishes without error.
- It prints version output for `mpicxx`, `mpirun`, `cmake`, and `ninja`.

**Next step**

- Configure a debug build tree.

## 4. Configure And Build A Debug Tree

**Prerequisites**

- Toolchain setup has completed successfully.
- You are at the repository root.

**Bash**

```bash
cd ~/work/Parallel-Retrieval-Engine-for-RAG
./scripts/configure_debug.sh
cmake --build build/debug
```

**Expected artifacts**

- `build/debug/CMakeCache.txt`
- `build/debug/build.ninja`
- `build/debug/sequential_retriever`
- `build/debug/parallel_retriever`
- `build/debug/generate_vectors`
- `build/debug/generate_queries`
- `build/debug/inspect_dataset`
- `build/debug/verify_results`

**What success looks like**

- CMake configure finishes without error.
- `cmake --build` exits `0`.

**Next step**

- Run `CTest` and the smoke wrapper.

## 5. Run The Full Debug Test Suite

**Prerequisites**

- `build/debug/` has been configured and built.

**Bash**

```bash
cd ~/work/Parallel-Retrieval-Engine-for-RAG
ctest --test-dir build/debug --output-on-failure
```

**Expected result**

- The test run ends with `0 tests failed`.

**What success looks like**

- `ctest` exits `0`.

**Next step**

- Run the wrapper smoke script to verify the common command surface.

## 6. Run The Repository Smoke Wrapper

**Prerequisites**

- Debug binaries already exist in `build/debug/`.

**Bash**

```bash
cd ~/work/Parallel-Retrieval-Engine-for-RAG
./scripts/run_smoke_tests.sh
```

**Expected result**

- The script builds the debug tree if needed.
- It runs `ctest`.
- It checks `sequential_retriever --help`.
- It checks `verify_results --help`.
- It checks `parallel_retriever --help` under `mpirun`.

**What success looks like**

- The script prints `Repository smoke tests completed.`

**Next step**

- Continue to [retrieval-workflows.md](retrieval-workflows.md) for the first real data path.

## 7. Optional Release Build

**Prerequisites**

- Toolchain setup has completed successfully.

**Bash**

```bash
cd ~/work/Parallel-Retrieval-Engine-for-RAG
./scripts/configure_release.sh
cmake --build build/release
```

**Expected artifacts**

- `build/release/CMakeCache.txt`
- `build/release/sequential_retriever`
- `build/release/parallel_retriever`

**What success looks like**

- The release configure and build both exit `0`.

**Next step**

- Use `build/release/` when you want non-debug binaries, or continue development with `build/debug/`.

## Notes

- The preferred repo location is `~/work/Parallel-Retrieval-Engine-for-RAG`.
- The canonical external dataset root is `/mnt/e/data`.
- If you are still running inside a temporary `root` shell, MPI commands may require the one-off environment override described in [troubleshooting.md](troubleshooting.md).
