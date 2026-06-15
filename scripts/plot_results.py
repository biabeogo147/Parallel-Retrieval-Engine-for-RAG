#!/usr/bin/env python3

import argparse
import csv
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt


def read_rows(path: Path) -> list[dict[str, str]]:
    with path.open("r", newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


def plot_runtime_by_n(results_dir: Path, figures_dir: Path) -> None:
    rows = read_rows(results_dir / "runtime_by_N.csv")
    x_values = [int(row["N"]) for row in rows]
    compute = [float(row["compute_time"]) for row in rows]
    total = [float(row["total_time"]) for row in rows]

    fig, ax = plt.subplots(figsize=(8, 5))
    ax.plot(x_values, compute, marker="o", label="compute_time")
    ax.plot(x_values, total, marker="s", label="total_time")
    ax.set_xlabel("N")
    ax.set_ylabel("Seconds")
    ax.set_title("Runtime by N")
    ax.legend()
    ax.grid(True, alpha=0.3)
    fig.tight_layout()
    fig.savefig(figures_dir / "runtime_by_N.png", dpi=150)
    plt.close(fig)


def plot_granularity(results_dir: Path, figures_dir: Path) -> None:
    rows = read_rows(results_dir / "granularity.csv")
    ranks = [int(row["rank"]) for row in rows]
    compute = [float(row["compute_time"]) for row in rows]
    communication = [float(row["communication_time"]) for row in rows]

    fig, ax = plt.subplots(figsize=(8, 5))
    ax.bar(ranks, compute, label="compute_time")
    ax.bar(ranks, communication, bottom=compute, label="communication_time")
    ax.set_xlabel("Rank")
    ax.set_ylabel("Seconds")
    ax.set_title("Granularity / Load Balancing")
    ax.legend()
    fig.tight_layout()
    fig.savefig(figures_dir / "granularity.png", dpi=150)
    plt.close(fig)


def plot_speedup_runtime(results_dir: Path, figures_dir: Path) -> None:
    rows = read_rows(results_dir / "speedup.csv")
    processes = [int(row["P"]) for row in rows]
    compute = [float(row["compute_time"]) for row in rows]
    total = [float(row["total_time"]) for row in rows]

    fig, ax = plt.subplots(figsize=(8, 5))
    ax.plot(processes, compute, marker="o", label="compute_time")
    ax.plot(processes, total, marker="s", label="total_time")
    ax.set_xlabel("Processes")
    ax.set_ylabel("Seconds")
    ax.set_title("Runtime vs Number of Processes")
    ax.legend()
    ax.grid(True, alpha=0.3)
    fig.tight_layout()
    fig.savefig(figures_dir / "speedup_runtime.png", dpi=150)
    plt.close(fig)


def plot_speedup_curves(results_dir: Path, figures_dir: Path) -> None:
    rows = read_rows(results_dir / "speedup.csv")
    processes = [int(row["P"]) for row in rows]
    compute = [float(row["compute_speedup"]) for row in rows]
    total = [float(row["total_speedup"]) for row in rows]

    fig, ax = plt.subplots(figsize=(8, 5))
    ax.plot(processes, compute, marker="o", label="compute_speedup")
    ax.plot(processes, total, marker="s", label="total_speedup")
    ax.set_xlabel("Processes")
    ax.set_ylabel("Speedup")
    ax.set_title("Speedup Curves")
    ax.legend()
    ax.grid(True, alpha=0.3)
    fig.tight_layout()
    fig.savefig(figures_dir / "speedup_curves.png", dpi=150)
    plt.close(fig)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--results-dir", type=Path, required=True)
    args = parser.parse_args()

    results_dir = args.results_dir
    figures_dir = results_dir / "figures"
    figures_dir.mkdir(parents=True, exist_ok=True)

    plot_runtime_by_n(results_dir, figures_dir)
    plot_granularity(results_dir, figures_dir)
    plot_speedup_runtime(results_dir, figures_dir)
    plot_speedup_curves(results_dir, figures_dir)


if __name__ == "__main__":
    main()
