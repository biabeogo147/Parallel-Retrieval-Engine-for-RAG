# AGENTS.md

## Purpose

This file defines the required working rules for both human developers and AI agents in this repository.

Its purpose is to keep the project:

- phase-based
- document-driven
- implementation-consistent
- free of duplicate docs, stale plans, and drifting contracts

This file is a strict playbook. The keywords `must`, `required`, `do not`, and `only` are intentional.

## Scope

These rules apply to:

- feature work
- bug fixes
- refactors
- benchmark changes
- dataset contract changes
- developer workflow changes
- documentation changes

They apply whether the work is done by:

- a human developer
- an AI coding agent
- a mixed human + AI workflow

## Project Context

The repository currently provides:

- a WSL-first C++17 and OpenMPI development foundation
- retriever CLI scaffolding
- a deterministic synthetic dataset generator and binary dataset loader
- source-level, developer-facing, and operational usage documentation

The repository is phase-based. Work must stay aligned with the current phase plan and approved next-phase direction.

## Canonical Reading Order

Before making non-trivial changes, contributors must read the current canonical materials in this order:

1. `README.md`
2. `AGENTS.md`
3. `docs/development/project_specification.md`
4. `docs/development/data_pipeline_and_benchmarks.md`
5. `docs/development/developer_guide.md`
6. `docs/development/source_guide.md`
7. `docs/development/parallel_agent_memory_retriever_plan.md`
8. the relevant file(s) in `docs/plans/` for the phase or task being changed

If a task touches only one narrow area, contributors may read deeper in that area after finishing this baseline reading order.

If a task affects fresh-clone onboarding, copy-paste command workflows, or troubleshooting for day-to-day repo usage, contributors must also read:

- `docs/usage/README.md`
- the relevant file(s) under `docs/usage/`

If a task affects benchmark interpretation, report wording, or next-step recommendations derived from benchmark artifacts, contributors must also read:

- the relevant file(s) under `docs/analysis/`

## Canonical Document Roles

The repository has one canonical document per major concern. Do not create a second source of truth for the same topic.

- `docs/usage/`
  - fresh-clone onboarding
  - copy-paste operational workflows
  - benchmark script usage
  - troubleshooting and generated-state cleanup

- `docs/analysis/`
  - benchmark interpretation
  - report-ready conclusions
  - report-section mapping
  - post-run next-step recommendations

- `docs/development/project_specification.md`
  - project scope
  - algorithm design
  - fixed technical decisions
  - input and output contracts
- `docs/development/data_pipeline_and_benchmarks.md`
  - dataset choices
  - dataset pipeline rules
  - binary dataset contract
  - benchmark policy
- `docs/development/developer_guide.md`
  - technical WSL environment reference
  - deeper build and test workflow rationale
  - codebase layout
  - developer-facing maintenance guidance
- `docs/development/source_guide.md`
  - runtime walkthrough
  - source file responsibilities
  - code-level orientation
- `docs/development/parallel_agent_memory_retriever_plan.md`
  - master roadmap
  - phase breakdown
  - experiments
  - report structure
- `docs/plans/*.md`
  - dated execution plans and implementation records

If a change belongs to one of the categories above, the matching canonical document must be updated instead of creating a new overlapping file.

## Required Workflow

All non-trivial work must follow this sequence:

1. Understand the request.
2. Map the request to the current phase or next approved phase.
3. Read the relevant canonical docs.
4. Decide whether a design/spec update is required.
5. Decide whether a dated implementation plan is required.
6. Implement in small, coherent changes.
7. Verify with the appropriate commands or tests.
8. Update canonical docs and references before closing the task.
9. Close only when code, docs, and plans agree.

Do not skip the documentation alignment step.

## When a Design or Spec Update Is Required

A contributor must update the relevant development document before or during implementation if the task changes any of the following:

- project scope
- algorithm behavior
- binary data format
- dataset selection policy
- benchmark methodology
- CLI contract
- WSL or build workflow
- codebase structure
- source-level behavior that affects onboarding or maintenance

Typical mapping:

- fresh-clone onboarding, command-first usage flows, troubleshooting -> `docs/usage/`
- benchmark interpretation, report mapping, conclusion wording -> `docs/analysis/`
- scope or algorithm change -> `project_specification.md`
- dataset, binary format, benchmark, generator behavior -> `data_pipeline_and_benchmarks.md`
- environment, scripts, layout, build or test flow -> `developer_guide.md`
- new executable flow, source responsibilities, major runtime path change -> `source_guide.md`

Do not postpone these updates to a later task.

## Planning Rules

## When a Dated Plan Is Required

A dated plan in `docs/plans/` is required when the task is:

- multi-step
- multi-file
- phase-defining
- architecture-affecting
- benchmark-affecting
- refactoring that changes repo structure
- implementation work expected to take more than one coherent change

A dated plan is not required for:

- a simple typo fix
- a single broken link
- a one-line clarification that does not change behavior
- a pure read-only explanation request

## Plan Location and Naming

Implementation plans must live in:

```text
docs/plans/
```

Use this naming style:

```text
YYYY-MM-DD-short-topic-name.md
```

## Minimum Plan Contents

A non-trivial plan must include:

- objective
- scope
- architecture summary
- files to create or modify
- acceptance criteria
- verification commands
- assumptions and defaults

If implementation deviates from the original plan, the plan must be updated or the deviation must be explicitly documented in the final plan file.

## Code Change Rules

## Scope Discipline

Contributors must:

- stay within the approved phase or approved task boundary
- avoid silent scope expansion
- avoid unrelated refactors
- make the smallest coherent change that satisfies the task

Contributors must not:

- pull Phase N+1 logic into the current phase without approval
- add speculative infrastructure that is not yet needed
- duplicate logic that already belongs in a shared layer

## Structural Boundaries

The repository must keep these boundaries clear:

- `include/`
  - shared public headers used across binaries and tests
- `src/`
  - shared implementations and main retriever entrypoints
- `tools/`
  - helper executables and tool-only helpers
- `tests/`
  - executable checks and test utilities
- `scripts/`
  - POSIX shell workflow helpers
- `docs/development/`
  - canonical technical references
- `docs/usage/`
  - canonical operational how-to docs
- `docs/plans/`
  - dated implementation and planning records

Do not blur these boundaries unless the change is explicitly a repo-structure refactor.

## Shared Logic Rules

Contributors must prefer extending the existing shared layer over duplicating logic in executable entrypoints.

Examples:

- shared retriever-facing code belongs in `retriever_core`
- MPI lifecycle logic must remain centralized
- dataset format and shard logic must not be redefined in multiple places
- CLI contract changes must be reflected in both implementation and tests

## Documentation Rules

## Canonical-Only Rule

Do not create a new Markdown file for a topic that already has a canonical home.

Before creating a doc, contributors must ask:

1. Does this topic belong in `docs/usage/` as a user-facing operational guide?
2. Does this topic already belong in one of the canonical development guides?
3. Is this a dated execution artifact that belongs in `docs/plans/` instead?
4. Is a new file truly necessary, or should an existing canonical file be extended?

If the answer is not clearly "new canonical area", do not create a new file.

## Documentation Synchronization Rule

Documentation must be updated in the same task when:

- code behavior changes
- public CLI behavior changes
- source structure changes
- plan scope changes
- verification flow changes
- dataset contracts change

Documentation is not a cleanup phase after coding. It is part of the implementation itself.

## Cross-Reference Rule

Whenever a document path changes, contributors must update:

- `README.md`
- links inside the affected canonical development docs
- references in active plan files when practical
- any visible index or navigation section that points at the moved file

Do not leave the old and new versions side by side unless there is a deliberate migration plan.

## Source Guide Update Rule

If a task changes any of the following, `docs/development/source_guide.md` must be updated:

- runtime flow from a `main` entrypoint
- the responsibility of a source file
- the set of build targets
- the role of a shared component
- the expected control flow of a tool or test

## Developer Guide Update Rule

If a task changes any of the following, `docs/development/developer_guide.md` must be updated:

- WSL setup
- build commands
- test commands
- smoke commands
- script responsibilities
- codebase layout

## Verification Rules

## No Completion Claim Without Verification

Do not claim a task is complete until the appropriate verification has been run, or until the missing verification is explicitly called out.

Verification should match the type of change:

- documentation-only change
  - verify links, paths, and structure
- build-system or code change
  - configure, build, and run relevant tests
- CLI change
  - run the actual executable paths
- MPI path change
  - run the relevant `mpirun` smoke path
- dataset/tooling change
  - run generator or inspection commands as appropriate

## Required Verification Mindset

Contributors must report:

- what was verified
- how it was verified
- what was not verified
- why any missing verification remains

Do not hide unverified areas behind broad completion language.

## Documentation Refactor Verification

When refactoring docs, contributors must verify at minimum:

- the intended files exist
- obsolete files are removed or intentionally retained
- `README.md` indexes the correct files
- no important canonical reference still points to a deleted file

## Phase Awareness Rules

This repository is organized around explicit phases. Every non-trivial task must respect that structure.

Contributors must:

- identify the phase affected by the task
- avoid implementing future-phase logic without approval
- record future work in docs or plans instead of silently coding ahead

If a task intentionally expands phase scope, that decision must be reflected in:

- the relevant canonical development doc
- the relevant dated plan
- the final task summary

## Anti-Chaos Rules

The following are prohibited unless explicitly justified by the task:

- duplicate docs for the same topic
- duplicate code paths for the same contract
- leaving both old and new docs active without a migration note
- adding temporary files and not cleaning them up
- changing code without updating matching docs
- changing docs without checking whether implementation or plans now disagree
- large opportunistic refactors unrelated to the approved task
- hidden scope expansion

If a cleanup is necessary but out of scope, document it as follow-up work instead of folding it silently into the current task.

## Definition of Done

A non-trivial task is complete only when all of the following are true:

1. The implementation satisfies the approved scope.
2. The relevant verification has been run, or the missing verification has been stated clearly.
3. The canonical development docs are aligned with the final behavior.
4. The dated plan, if one exists, reflects what was actually implemented.
5. No critical path still points at obsolete filenames, obsolete contracts, or duplicate documentation.

If any of these are false, the task is not done.

## Working Defaults

Unless the current task explicitly says otherwise, contributors should assume:

- WSL2 + Ubuntu 24.04 + OpenMPI is the canonical environment
- `~/work/Parallel-Retrieval-Engine-for-RAG` is the canonical WSL repo path
- `/mnt/e/data` is the canonical external dataset root
- generated local artifacts belong under `build/`, `data/`, or `results/`
- canonical technical references belong in `docs/development/`
- dated execution artifacts belong in `docs/plans/`

## Practical Checklist

Before closing a non-trivial task, confirm:

- I read the relevant canonical docs first.
- I mapped the task to the right phase.
- I created or updated a dated plan if the task required one.
- I changed only the scope that was approved.
- I verified the change at the right level.
- I updated the correct canonical development doc.
- I updated `README.md` or visible indexes if paths changed.
- I removed or absorbed obsolete files instead of leaving duplicate sources of truth.

If any item above is false, do not close the task yet.
