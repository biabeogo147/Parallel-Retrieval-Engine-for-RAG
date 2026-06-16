#!/usr/bin/env python3

from __future__ import annotations

import argparse
from pathlib import Path
import time


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Run a FAISS IndexFlatIP exact top-k comparison over the repository binary datasets."
    )
    parser.add_argument("--vectors", type=Path, required=True)
    parser.add_argument("--queries", type=Path, required=True)
    parser.add_argument("--topk", type=int, required=True)
    parser.add_argument("--threads", type=int, required=True)
    parser.add_argument("--output-topk", type=Path, required=True)
    parser.add_argument("--output-metrics", type=Path, required=True)
    parser.add_argument("--dataset-name", default="synthetic")
    return parser.parse_args()


def main() -> int:
    args = parse_args()

    if args.threads < 1:
        print("Error: threads must be at least 1")
        return 1

    try:
        import faiss

        from phase8_common import (
            read_binary_dataset,
            validate_retrieval_inputs,
            write_phase8_run_metrics_csv,
            write_topk_csv,
        )

        memory_dataset = read_binary_dataset(args.vectors)
        query_dataset = read_binary_dataset(args.queries)
        validate_retrieval_inputs(memory_dataset.header, query_dataset.header, args.topk)

        memory_matrix = memory_dataset.values
        query_matrix = query_dataset.values

        faiss.omp_set_num_threads(args.threads)

        build_start = time.perf_counter()
        index = faiss.IndexFlatIP(int(memory_dataset.header.dimension))
        index.add(memory_matrix)
        build_time = time.perf_counter() - build_start

        compute_start = time.perf_counter()
        scores, indices = index.search(query_matrix, args.topk)
        compute_time = time.perf_counter() - compute_start

        write_topk_csv(args.output_topk, indices, scores)
        write_phase8_run_metrics_csv(
            args.output_metrics,
            args.dataset_name,
            memory_dataset.header.num_vectors,
            memory_dataset.header.dimension,
            query_dataset.header.num_vectors,
            args.topk,
            args.threads,
            build_time,
            compute_time,
            compute_time,
        )

        print(f"Wrote {args.output_topk}")
        print(f"Wrote {args.output_metrics}")
        return 0
    except Exception as exc:  # noqa: BLE001
        print(f"Error: {exc}")
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
