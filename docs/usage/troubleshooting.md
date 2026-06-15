# Troubleshooting

This page collects the most common problems a developer may hit while following the usage guides.

All Bash commands below assume:

```bash
cd ~/work/Parallel-Retrieval-Engine-for-RAG
```

## I Am Not Inside WSL

**Symptoms**

- `uname -s` does not print `Linux`
- `mpirun` or `mpicxx` is missing because you are in PowerShell or CMD
- Linux paths such as `~/work/...` do not resolve

**Fix**

Use PowerShell only to enter Ubuntu:

```powershell
wsl.exe -d Ubuntu-24.04
```

Then verify inside the shell:

```bash
uname -s
pwd
```

**What success looks like**

- `uname -s` prints `Linux`
- `pwd` is a Linux path, not a Windows path

## `git`, `mpicxx`, `mpirun`, `cmake`, Or `ninja` Is Missing

**Symptoms**

- `command not found`
- setup, configure, or smoke commands fail immediately

**Fix**

If `git` is missing before clone:

```bash
sudo apt update
sudo apt install -y git
```

If toolchain commands are missing after clone:

```bash
./scripts/setup_wsl_dev_env.sh
```

Then verify:

```bash
git --version
mpicxx --version
mpirun --version
cmake --version
ninja --version
```

**What success looks like**

- Every command above prints a version instead of failing.

## OpenMPI Refuses To Run As `root`

**Symptoms**

- `mpirun` exits with a root-user warning
- the sequential binary works, but the parallel binary fails before startup

**Fix**

The preferred fix is to use a normal Ubuntu user. If you are temporarily in a `root` WSL shell, use the one-off environment override:

```bash
OMPI_ALLOW_RUN_AS_ROOT=1 OMPI_ALLOW_RUN_AS_ROOT_CONFIRM=1 \
mpirun -np 4 ./build/debug/parallel_retriever --help
```

The benchmark scripts already apply the root override automatically when they detect `id -u = 0`.

**What success looks like**

- `mpirun` starts successfully and the target binary runs.

## A Binary Under `build/debug/` Is Missing

**Symptoms**

- `No such file or directory`
- one binary exists but others do not

**Fix**

Re-run configure and build:

```bash
./scripts/configure_debug.sh
cmake --build build/debug
```

If you want to verify the common command surface afterward:

```bash
./scripts/run_smoke_tests.sh
```

**What success looks like**

- The missing binary now exists under `build/debug/`.

## Benchmark Plotting Spends Time Creating `.venv/`

**Symptoms**

- `run_all_experiments.sh` pauses while installing Python packages
- `.venv/` appears at the repo root

**Why this happens**

- The benchmark figure generation step bootstraps a repo-local Python virtual environment if one does not already exist.
- `matplotlib` is installed there the first time plotting is needed.

**What to do**

- Wait for the first run to finish.
- Re-run the command later; subsequent runs are usually faster because `.venv/` is reused.

Optional override:

```bash
BENCH_PLOT_VENV_DIR=.venv-custom bash ./scripts/run_all_experiments.sh
```

## I Cannot Find The Generated Files

Use these locations:

- `data/`
  - local synthetic `.bin` files used in manual retrieval workflows
- `results/`
  - final top-k CSVs, correctness CSV, benchmark tables, selection manifest, and figures
- `.cache/benchmarks/`
  - benchmark scratch datasets and intermediate outputs
- `.venv/`
  - plotting runtime environment

If you used custom benchmark environment variables, check those overridden paths instead of the defaults.

## Safe Generated-State Cleanup

These commands remove repo-local generated state only. They do not touch tracked source files.

**Bash**

```bash
cd ~/work/Parallel-Retrieval-Engine-for-RAG
rm -rf build/debug build/release
rm -f data/*.bin
rm -f results/*.csv results/*.txt
rm -rf results/figures
rm -rf .cache/benchmarks
rm -rf .venv
```

Then rebuild as needed:

```bash
./scripts/configure_debug.sh
cmake --build build/debug
```

**Important**

- Do not use `git reset --hard` or `git clean -fdx` unless you intentionally want to discard much more than generated outputs.
- If you used custom result or scratch directories, clean those custom paths separately.
