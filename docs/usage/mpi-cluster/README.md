# MPI Cluster Setup

This bundle explains how to prepare and operate physical MPI clusters for this repository.

It is the operational extension of the existing single-machine WSL workflow. Use it when you want to run `parallel_retriever` across three physical computers instead of one local development machine.

## Audience And Scope

Use this bundle when:

- you want one head node plus two worker nodes
- or you want to branch into a separate validated two-node runbook from the same entrypoint
- every node can provide an Ubuntu 24.04 shell
- you want to start from a fresh machine that does not yet have a local repo checkout
- you want to run manual multi-node MPI retrieval commands

The generic cluster guides in this folder remain manual and verification-focused. The repository now also provides one dedicated automation wrapper for the validated `rag-head + rag-worker1` case:

- `scripts/run_cluster_two_node_bundle.sh`
- `scripts/run_cluster_postprocess.sh`

Use those scripts only through the dedicated two-node runbook, not as a claim that the generic `head + workers` cluster flow is fully automated.

## Reading Order

1. Pick exactly one bootstrap guide for each physical node:
   - [node-bootstrap-wsl.md](node-bootstrap-wsl.md)
   - [node-bootstrap-ubuntu.md](node-bootstrap-ubuntu.md)
   - [node-bootstrap-macos-multipass.md](node-bootstrap-macos-multipass.md)
2. If you want the exact validated `rag-head + rag-worker1` workflow from start to finish, use [two-node-runbook-local-plus-199.md](two-node-runbook-local-plus-199.md).
3. If you want the generic `head + 2 workers` flow, follow [cluster-assembly-and-validation.md](cluster-assembly-and-validation.md) from the head node after all nodes are ready.
4. Use [cluster-runbook.md](cluster-runbook.md) for repeatable day-to-day generic cluster runs.
5. If anything fails, use [troubleshooting.md](troubleshooting.md).

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
- The recommended Linux username for this bundle is `rag`.
- Use the same repo path on all three nodes:
  - `~/work/Parallel-Retrieval-Engine-for-RAG`
- Use the same binary paths on all three nodes:
  - `~/work/Parallel-Retrieval-Engine-for-RAG/build/debug/...`
  - `~/work/Parallel-Retrieval-Engine-for-RAG/build/release/...`
- Use repo-local runtime datasets under:
  - `~/work/Parallel-Retrieval-Engine-for-RAG/data/`
- Use repo-local outputs under:
  - `~/work/Parallel-Retrieval-Engine-for-RAG/results/`

The examples in this bundle assume the Linux username `rag`. The node bootstrap guides now include explicit steps to create that user. If you choose another username instead, replace `rag` consistently in SSH, `rsync`, and path examples.

For Windows + WSL2 and macOS + Multipass nodes, `rag` is the Linux user inside the Ubuntu guest, not the Windows or macOS host login account.

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
- [examples/two_node_bundle.env.example](examples/two_node_bundle.env.example)

Copy these into a repo-local untracked working area such as `.cache/cluster/` and then replace the example IPs, usernames, and slot counts with the values for your environment.

If you do not want to adapt the generic examples yourself, use [two-node-runbook-local-plus-199.md](two-node-runbook-local-plus-199.md) instead. That document already records a real operator flow with concrete values and exact commands.

Treat them differently:

- `hosts.example`
  - template for the OpenMPI hostfile that `mpirun` will read
- `ssh_config.example`
  - convenience template for human SSH usage from the head node
  - if you want alias-based SSH globally, merge the relevant host stanzas into `~/.ssh/config`
- `two_node_bundle.env.example`
  - shell-sourced operator config for the dedicated validated two-node bundle wrapper
  - copy it into `.cache/cluster/`, then replace the real hostfile path, worker host, and any benchmark overrides you want to use

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
