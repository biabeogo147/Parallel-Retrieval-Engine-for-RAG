#!/usr/bin/env python3

from __future__ import annotations

import argparse
from pathlib import Path


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Convert local SQuAD parquet files into normalized binary vectors using all-MiniLM-L6-v2."
    )
    parser.add_argument("--input-dir", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument("--model", required=True)
    parser.add_argument("--queries-limit", type=int, default=100)
    parser.add_argument("--batch-size", type=int, default=32)
    return parser.parse_args()


def first_matching_file(input_dir: Path, pattern: str, label: str) -> Path:
    matches = sorted(input_dir.glob(pattern))
    if not matches:
        raise RuntimeError(f"missing {label} parquet file under {input_dir}")
    return matches[0]


def main() -> int:
    args = parse_args()

    if args.queries_limit < 1:
        print("Error: queries-limit must be at least 1")
        return 1
    if args.batch_size < 1:
        print("Error: batch-size must be at least 1")
        return 1

    try:
        import pyarrow.parquet as pq
        from sentence_transformers import SentenceTransformer

        from phase8_common import resolve_existing_dir, write_binary_dataset, write_metadata_tsv

        input_dir = resolve_existing_dir(args.input_dir)
        output_dir = args.output_dir.expanduser()
        train_path = first_matching_file(input_dir, "train-*.parquet", "train")
        validation_path = first_matching_file(input_dir, "validation-*.parquet", "validation")

        train_contexts = pq.read_table(train_path, columns=["context"]).column("context").to_pylist()
        validation_questions = pq.read_table(validation_path, columns=["question"]).column("question").to_pylist()

        unique_contexts: list[str] = []
        seen_contexts: set[str] = set()
        for raw_context in train_contexts:
            if not isinstance(raw_context, str):
                continue
            context = raw_context.strip()
            if not context or context in seen_contexts:
                continue
            seen_contexts.add(context)
            unique_contexts.append(context)

        selected_questions: list[str] = []
        for raw_question in validation_questions:
            if len(selected_questions) >= args.queries_limit:
                break
            if not isinstance(raw_question, str):
                continue
            question = raw_question.strip()
            if question:
                selected_questions.append(question)

        if not unique_contexts:
            raise RuntimeError("no non-empty contexts were found in the train split")
        if not selected_questions:
            raise RuntimeError("no non-empty questions were found in the validation split")

        model = SentenceTransformer(args.model)
        memory_vectors = model.encode(
            unique_contexts,
            batch_size=args.batch_size,
            convert_to_numpy=True,
            normalize_embeddings=True,
            show_progress_bar=False,
        )
        query_vectors = model.encode(
            selected_questions,
            batch_size=args.batch_size,
            convert_to_numpy=True,
            normalize_embeddings=True,
            show_progress_bar=False,
        )

        if memory_vectors.ndim != 2 or query_vectors.ndim != 2:
            raise RuntimeError("embedding model must return 2D arrays")
        if memory_vectors.shape[1] != query_vectors.shape[1]:
            raise RuntimeError("embedding dimensions differ between memory and query outputs")

        write_binary_dataset(output_dir / "vectors.bin", memory_vectors)
        write_binary_dataset(output_dir / "queries.bin", query_vectors)
        write_metadata_tsv(output_dir / "metadata.tsv", unique_contexts)

        print(f"Wrote {output_dir / 'vectors.bin'}")
        print(f"Wrote {output_dir / 'queries.bin'}")
        print(f"Wrote {output_dir / 'metadata.tsv'}")
        print(f"Contexts: {len(unique_contexts)}")
        print(f"Queries: {len(selected_questions)}")
        print(f"Dimension: {memory_vectors.shape[1]}")
        return 0
    except Exception as exc:  # noqa: BLE001
        print(f"Error: {exc}")
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
