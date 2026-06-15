# Development Workflow

## Canonical Paths

Use these paths consistently in docs, commands, and day-to-day development:

- repo root in WSL: `~/work/Parallel-Retrieval-Engine-for-RAG`
- dataset root in WSL: `/mnt/e/data`
- debug build tree: `~/work/Parallel-Retrieval-Engine-for-RAG/build/debug`
- release build tree: `~/work/Parallel-Retrieval-Engine-for-RAG/build/release`

If the repository still lives on the Windows drive, move or reclone it into the WSL filesystem before doing normal development work. Native WSL storage is the default because it avoids Windows mount latency and ownership friction.

## Bootstrap Flow

### 1. Install Ubuntu on the Windows host

Run this in PowerShell on Windows:

```powershell
wsl --install -d Ubuntu-24.04
```

If Windows asks for a restart, reboot first and finish the Ubuntu first-run setup.

Do not stop at the temporary `root` shell. Complete the Ubuntu first-run flow so the distro has a normal Linux user for daily development.

### 2. Open the Ubuntu shell and create the canonical workspace

```bash
mkdir -p ~/work
cd ~/work
git clone <your-remote-url> Parallel-Retrieval-Engine-for-RAG
cd Parallel-Retrieval-Engine-for-RAG
```

### 3. Install toolchain dependencies

```bash
./scripts/setup_wsl_dev_env.sh
```

## Day-to-Day Build Flow

Configure a debug build:

```bash
./scripts/configure_debug.sh
```

Build targets:

```bash
cmake --build build/debug
```

Run tests:

```bash
ctest --test-dir build/debug --output-on-failure
```

Run the Phase 1 smoke bundle:

```bash
./scripts/run_smoke_tests.sh
```

## CLI Smoke Commands

Sequential help:

```bash
./build/debug/sequential_retriever --help
```

Parallel help:

```bash
mpirun -np 4 ./build/debug/parallel_retriever --help
```

If you are temporarily running as `root`, use:

```bash
OMPI_ALLOW_RUN_AS_ROOT=1 OMPI_ALLOW_RUN_AS_ROOT_CONFIRM=1 \
  mpirun -np 4 ./build/debug/parallel_retriever --help
```

## Generated Artifacts

Generated files should stay inside these locations:

- build outputs: `build/debug` and `build/release`
- local datasets produced by future phases: `data/`
- benchmark outputs produced by future phases: `results/`

Do not commit generated content from `build/`, `data/`, or `results/`.

## Documentation Maintenance Rules

When you add or move docs:

1. Keep implementation and architecture docs in `docs/development/`.
2. Keep plan artifacts in `docs/plans/`.
3. Update cross-links immediately if a doc path changes.
4. Prefer WSL paths in all developer-facing commands.
