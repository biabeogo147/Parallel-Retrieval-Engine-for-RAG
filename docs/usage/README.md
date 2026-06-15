# Usage Docs

This folder is the command-first entrypoint for developers who have just cloned the repository and want to use it without reading the deeper architecture material first.

Use `docs/usage/` for:

- WSL onboarding after `git clone`
- build and smoke-test commands
- synthetic retrieval workflows
- benchmark automation workflows
- common troubleshooting and safe generated-state cleanup

Use `docs/development/` for:

- technical contracts
- dataset and benchmark policy
- source-code walkthroughs
- codebase structure and maintenance rules

## Reading Order

1. [getting-started-wsl.md](getting-started-wsl.md)
2. [retrieval-workflows.md](retrieval-workflows.md)
3. [results-csv-reference.md](results-csv-reference.md)
4. [benchmark-workflows.md](benchmark-workflows.md)
5. [troubleshooting.md](troubleshooting.md)

If you only need the shortest path after cloning, start with `getting-started-wsl.md`, then jump directly to the specific workflow you need.

## Command Conventions

- Bash commands assume you are already inside Ubuntu WSL.
- PowerShell commands are used only for installing or launching WSL from Windows.
- Unless a section says otherwise, run commands from:

```bash
cd ~/work/Parallel-Retrieval-Engine-for-RAG
```

- Paths inside command examples are repo-relative unless marked as external dataset paths.

## Canonical Paths

- WSL repo root: `~/work/Parallel-Retrieval-Engine-for-RAG`
- External dataset root in WSL: `/mnt/e/data`

## Artifact Map

- `build/debug/`
  - debug binaries and CMake/Ninja build files
- `build/release/`
  - release binaries and release build files
- `data/`
  - local synthetic dataset files such as `memory_vectors.bin` and `query_vectors.bin`
- `results/`
  - top-k CSV outputs, correctness CSVs, benchmark tables, selection manifest, and generated figures
- `.cache/benchmarks/`
  - scratch benchmark datasets and intermediate CSV files created by the automation scripts
- `.venv/`
  - repo-local Python virtual environment used by benchmark plotting

## Deeper Technical References

When you need more than the operational steps, continue here:

- [../development/project_specification.md](../development/project_specification.md)
  - scope, algorithm design, and fixed contracts
- [../development/data_pipeline_and_benchmarks.md](../development/data_pipeline_and_benchmarks.md)
  - dataset rules, benchmark semantics, and CSV contracts
- [../development/developer_guide.md](../development/developer_guide.md)
  - technical WSL rationale, codebase layout, and maintenance guidance
- [../development/source_guide.md](../development/source_guide.md)
  - runtime flow and source-file responsibilities

## Typical First Session

If you want the shortest successful path:

1. Follow [getting-started-wsl.md](getting-started-wsl.md).
2. Run the small synthetic flow in [retrieval-workflows.md](retrieval-workflows.md).
3. Read [results-csv-reference.md](results-csv-reference.md) to understand the generated outputs.
4. When that works, move to [benchmark-workflows.md](benchmark-workflows.md).
5. If anything fails, check [troubleshooting.md](troubleshooting.md).
