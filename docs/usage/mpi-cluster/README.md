# MPI Cluster Setup

This bundle explains how to prepare and operate a three-node physical MPI cluster for this repository.

It is the operational extension of the existing single-machine WSL workflow. Use it when you want to run `parallel_retriever` across three physical computers instead of one local development machine.

## Audience And Scope

Use this bundle when:

- you want one head node plus two worker nodes
- every node can provide an Ubuntu 24.04 shell
- you want to start from a fresh machine that does not yet have a local repo checkout
- you want to run manual multi-node MPI retrieval commands

This bundle does not add cluster-aware benchmark automation. The current shell automation under `scripts/` remains single-machine oriented. Multi-node runs in this guide are manual and verification-focused.

## Reading Order

1. Pick exactly one bootstrap guide for each physical node:
   - [node-bootstrap-wsl.md](node-bootstrap-wsl.md)
   - [node-bootstrap-ubuntu.md](node-bootstrap-ubuntu.md)
   - [node-bootstrap-macos-multipass.md](node-bootstrap-macos-multipass.md)
2. Follow [cluster-assembly-and-validation.md](cluster-assembly-and-validation.md) from the head node after all three nodes are ready.
3. Use [cluster-runbook.md](cluster-runbook.md) for repeatable day-to-day cluster runs.
4. If anything fails, use [troubleshooting.md](troubleshooting.md).

## Canonical Topology

This guide standardizes on the following example topology:

```text
rag-head      -> head node, rank 0 launch point, authoritative shared-data owner
rag-worker1   -> worker node
rag-worker2   -> worker node
```

The role split is:

- `rag-head`
  - launches `mpirun`
  - stores the authoritative shared dataset copy
  - runs `sequential_retriever` for comparison
  - runs `verify_results`
- `rag-worker1` and `rag-worker2`
  - receive synchronized local copies of the runtime datasets
  - participate in remote MPI launches

## Shared Operating Rules

All platform variants in this bundle follow the same cluster rules:

- Every node must provide an Ubuntu 24.04 user shell.
- Use the same Linux username on all three nodes whenever possible.
- Use the same repo path on all three nodes:
  - `~/work/Parallel-Retrieval-Engine-for-RAG`
- Use the same binary paths on all three nodes:
  - `~/work/Parallel-Retrieval-Engine-for-RAG/build/debug/...`
  - `~/work/Parallel-Retrieval-Engine-for-RAG/build/release/...`
- Use repo-local runtime datasets under:
  - `~/work/Parallel-Retrieval-Engine-for-RAG/data/`
- Use repo-local outputs under:
  - `~/work/Parallel-Retrieval-Engine-for-RAG/results/`

The examples in this bundle assume the Linux username `rag`. If you choose another username, replace `rag` consistently in SSH, `rsync`, and path examples.

## Data Model

The cluster docs lock this workflow:

- authoritative shared copy
  - stored on the head node or on a shared storage location controlled by the head node
  - this guide uses `~/cluster-shared/parallel-rag-data/` on `rag-head`
- local runtime copy
  - synchronized into `data/` on each node before an MPI run
  - these local files are what `parallel_retriever` actually reads

This split keeps operational management simple:

- one place to create or refresh the canonical datasets
- one local fast path per node for actual retrieval

## Host Versus Guest Commands

This bundle always labels commands by where they run:

- `PowerShell`
  - Windows host commands
- `zsh`
  - macOS host commands
- `Bash`
  - commands inside the Ubuntu shell on the cluster node

Unless a section says otherwise, repo commands use:

```bash
cd ~/work/Parallel-Retrieval-Engine-for-RAG
```

## Example Support Files

This bundle also provides copyable examples:

- [examples/hosts.example](examples/hosts.example)
- [examples/ssh_config.example](examples/ssh_config.example)

Copy these into a repo-local untracked working area such as `.cache/cluster/` and then replace the example IPs, usernames, and slot counts with the values for your environment.

Treat them differently:

- `hosts.example`
  - template for the OpenMPI hostfile that `mpirun` will read
- `ssh_config.example`
  - convenience template for human SSH usage from the head node
  - if you want alias-based SSH globally, merge the relevant host stanzas into `~/.ssh/config`

## Recommended Deep References

When you need the deeper technical contracts behind the operational steps, continue here:

- [../../development/project_specification.md](../../development/project_specification.md)
- [../../development/data_pipeline_and_benchmarks.md](../../development/data_pipeline_and_benchmarks.md)
- [../../development/developer_guide.md](../../development/developer_guide.md)
- [../../development/source_guide.md](../../development/source_guide.md)

## Important Constraint For WSL Nodes

WSL nodes are supported in this guide, but they are not as unattended as native Ubuntu nodes. Treat them as operator-managed workers:

- use mirrored networking for LAN reachability
- enable `ssh` inside the Ubuntu guest
- launch the WSL distro before cluster work
- keep the Ubuntu guest running during the MPI job window

If you need always-on cluster workers with the least operational friction, prefer native Ubuntu nodes first.
