# 2026-06-23 Two-Node Runbook Documentation Refactor

## Objective

Refactor the MPI cluster documentation so the validated `rag-head + rag-worker1` process is recorded in its own dedicated end-to-end runbook instead of being embedded across the generic cluster guides.

## Scope

Included:

- create one dedicated two-node runbook under `docs/usage/mpi-cluster/`
- move the concrete validated `local WSL head + 192.168.1.199 worker` process into that document
- trim the generic cluster guides back to general-purpose roles
- update the usage indexes and README pointers so readers can discover the new document quickly

Excluded:

- changing the benchmark code or MPI runtime behavior
- deleting the generic cluster guides
- changing CSV schemas or benchmark contracts

## Architecture Summary

The documentation split after this refactor is:

- generic cluster docs
  - `docs/usage/mpi-cluster/README.md`
  - `docs/usage/mpi-cluster/cluster-assembly-and-validation.md`
  - `docs/usage/mpi-cluster/cluster-runbook.md`
  - remain topology-agnostic and reusable
- concrete validated case doc
  - `docs/usage/mpi-cluster/two-node-runbook-local-plus-199.md`
  - records the exact operator workflow that was already executed successfully on this repo

## Files Modified

- `README.md`
- `docs/usage/README.md`
- `docs/usage/mpi-cluster/README.md`
- `docs/usage/mpi-cluster/cluster-assembly-and-validation.md`
- `docs/usage/mpi-cluster/cluster-runbook.md`
- `docs/development/developer_guide.md`
- `docs/plans/2026-06-23-two-node-runbook-doc-refactor.md`

Created:

- `docs/usage/mpi-cluster/two-node-runbook-local-plus-199.md`

## Implementation Summary

### 1. Created the dedicated two-node runbook

Added a new operational document that records, in one place:

- Windows host mirrored-networking setup
- Hyper-V firewall inbound allow step
- WSL head-node normalization as `rag-head`
- Ubuntu server worker normalization as `rag-worker1`
- repo clone/build on both nodes
- `/etc/hosts`, SSH key, and hostfile setup
- exact MPI smoke commands
- exact synthetic smoke commands
- exact canonical benchmark commands
- final verification checklist
- optional result-copy-back step for a Windows-mounted workspace

### 2. Simplified the generic cluster docs

Removed the case-specific material that had been embedded into:

- `cluster-assembly-and-validation.md`
- `cluster-runbook.md`

and replaced it with clear pointers to the new dedicated runbook.

### 3. Updated discovery paths

Added direct pointers to the new runbook from:

- `README.md`
- `docs/usage/README.md`
- `docs/usage/mpi-cluster/README.md`
- `docs/development/developer_guide.md`

## Acceptance Criteria

- the validated two-node process now exists in one end-to-end document
- the generic cluster docs no longer act as the main home for the concrete `local + 192.168.1.199` workflow
- the usage indexes clearly point readers to the new dedicated runbook
- the updated doc-role split matches the user request:
  - generic docs stay generic
  - the validated two-node process lives in its own runbook

## Verification Commands

Discovery and path checks:

```powershell
rg -n "two-node-runbook-local-plus-199" README.md docs/usage docs/development docs/plans
```

Role-split sanity checks:

```powershell
Get-Content -Raw docs\usage\mpi-cluster\two-node-runbook-local-plus-199.md
Get-Content -Raw docs\usage\mpi-cluster\cluster-assembly-and-validation.md
Get-Content -Raw docs\usage\mpi-cluster\cluster-runbook.md
```

## Assumptions And Defaults

- the validated two-node run remains:
  - local WSL head node
  - one Ubuntu server worker at `192.168.1.199`
- the generic cluster guides still remain necessary for broader `head + workers` use
- the new runbook is allowed to be more concrete and more repetitive than the generic guides because reproducibility is its primary goal
