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
bash scripts/setup_wsl_dev_env.sh
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
bash scripts/configure_debug.sh
cmake --build build/debug
```

If you want to verify the common command surface afterward:

```bash
bash scripts/run_smoke_tests.sh
```

**What success looks like**

- The missing binary now exists under `build/debug/`.

## Benchmark Plotting Or Phase 8 FAISS Setup Spends Time Creating `.venv/`

**Symptoms**

- `run_all_experiments.sh` pauses while installing Python packages
- `run_faiss_comparison.sh` pauses while installing Python packages
- `.venv/` appears at the repo root

**Why this happens**

- The benchmark figure generation step bootstraps a repo-local Python virtual environment if one does not already exist.
- Phase 8 also reuses that same `.venv/` for `faiss-cpu`, `pyarrow`, and `sentence-transformers` when needed.
- `matplotlib` is installed there the first time plotting is needed.

**What to do**

- Wait for the first run to finish.
- Re-run the command later; subsequent runs are usually faster because `.venv/` is reused.

Optional override:

```bash
BENCH_PLOT_VENV_DIR=.venv-custom bash scripts/run_all_experiments.sh
```

For Phase 8, the same override path applies because `run_faiss_comparison.sh` reuses `BENCH_PLOT_VENV_DIR`.

## `run_faiss_comparison.sh` Cannot Find SQuAD Input Files

**Symptoms**

- the script reports a missing directory under `/mnt/e/data/squad/plain_text`
- `prepare_squad_minilm.py` reports a missing `train-*.parquet` or `validation-*.parquet`

**Fix**

Confirm the expected input path exists:

```bash
ls /mnt/e/data/squad/plain_text
```

If your SQuAD copy lives elsewhere, override the input root:

```bash
BENCH_SQUAD_INPUT_DIR=/your/custom/squad/path \
bash scripts/run_faiss_comparison.sh
```

If you already prepared compatible `vectors.bin` and `queries.bin`, point the workflow at that output directory instead:

```bash
BENCH_SQUAD_OUTPUT_DIR=.cache/real_corpora/squad_minilm \
bash scripts/run_faiss_comparison.sh
```

**What success looks like**

- the script either finds the parquet input files or reuses the prepared binary outputs without failing during startup

## Phase 8 Model Download Or Python Dependency Bootstrap Takes Time

**Symptoms**

- `prepare_squad_minilm.py` pauses on first run
- the first Phase 8 run uses network bandwidth
- the terminal shows Python package installation or model download activity

**Why this happens**

- Phase 8 may need to install:
  - `faiss-cpu`
  - `numpy`
  - `pyarrow`
  - `sentence-transformers`
- the first real-corpus run may also need to download `sentence-transformers/all-MiniLM-L6-v2`

**What to do**

- wait for the first run to complete
- rerun the same command later; the repo-local `.venv/` and cached model files usually make later runs faster

**What success looks like**

- later Phase 8 runs spend much less time in environment bootstrap

## I Cannot Find The Generated Files

Use these locations:

- `data/`
  - local synthetic `.bin` files used in manual retrieval workflows
- `results/`
  - final top-k CSVs, correctness CSVs, benchmark tables, selection manifest, figures, and `results/faiss/` outputs
- `.cache/benchmarks/`
  - benchmark scratch datasets and intermediate outputs
- `.cache/real_corpora/`
  - converted real-corpus binaries and metadata for the Phase 8 workflow
- `.venv/`
  - plotting and Phase 8 Python runtime environment

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
rm -rf results/faiss
rm -rf .cache/benchmarks
rm -rf .cache/real_corpora
rm -rf .venv
```

Then rebuild as needed:

```bash
bash scripts/configure_debug.sh
cmake --build build/debug
```

**Important**

- Do not use `git reset --hard` or `git clean -fdx` unless you intentionally want to discard much more than generated outputs.
- If you used custom result or scratch directories, clean those custom paths separately.
