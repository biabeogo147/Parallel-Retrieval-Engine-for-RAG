#!/usr/bin/env python3

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
import os
import struct


MAGIC = b"PMRAGV1\x00"
VERSION = 1
FLAG_NORMALIZED = 1 << 0
FLAG_ROW_MAJOR = 1 << 1
HEADER_STRUCT = struct.Struct("<8sIIQII")


@dataclass
class BinaryDatasetHeader:
    magic: bytes
    version: int
    flags: int
    num_vectors: int
    dimension: int
    reserved0: int


@dataclass
class BinaryDatasetContents:
    header: BinaryDatasetHeader
    values: object


def _import_numpy():
    import numpy as np

    return np


def read_binary_dataset(path: Path) -> BinaryDatasetContents:
    np = _import_numpy()
    actual_size = path.stat().st_size
    if actual_size < HEADER_STRUCT.size:
        raise RuntimeError(f"truncated dataset header: {path}")

    with path.open("rb") as handle:
        raw_header = handle.read(HEADER_STRUCT.size)
        magic, version, flags, num_vectors, dimension, reserved0 = HEADER_STRUCT.unpack(raw_header)
        header = BinaryDatasetHeader(
            magic=magic,
            version=version,
            flags=flags,
            num_vectors=num_vectors,
            dimension=dimension,
            reserved0=reserved0,
        )

        validate_header(header)

        expected_values = num_vectors * dimension
        expected_size = HEADER_STRUCT.size + expected_values * 4
        if actual_size < expected_size:
            raise RuntimeError(f"truncated dataset payload: {path}")
        if actual_size > expected_size:
            raise RuntimeError(f"dataset payload size is inconsistent with header metadata: {path}")

        values = np.fromfile(handle, dtype="<f4", count=expected_values)
        if values.size != expected_values:
            raise RuntimeError(f"truncated dataset payload: {path}")

    values = values.astype(np.float32, copy=False).reshape((num_vectors, dimension))
    return BinaryDatasetContents(header=header, values=values)


def validate_header(header: BinaryDatasetHeader) -> None:
    if header.magic != MAGIC:
        raise RuntimeError("invalid dataset magic")
    if header.version != VERSION:
        raise RuntimeError("invalid dataset version")
    if header.dimension <= 0:
        raise RuntimeError("dataset dimension must be positive")


def validate_retrieval_inputs(
    memory_header: BinaryDatasetHeader,
    query_header: BinaryDatasetHeader,
    topk: int,
) -> None:
    if (memory_header.flags & FLAG_NORMALIZED) == 0:
        raise RuntimeError("memory dataset must set the normalized flag")
    if (query_header.flags & FLAG_NORMALIZED) == 0:
        raise RuntimeError("query dataset must set the normalized flag")
    if (memory_header.flags & FLAG_ROW_MAJOR) == 0:
        raise RuntimeError("memory dataset must set the row-major flag")
    if (query_header.flags & FLAG_ROW_MAJOR) == 0:
        raise RuntimeError("query dataset must set the row-major flag")
    if memory_header.dimension != query_header.dimension:
        raise RuntimeError("dimension mismatch between memory and query datasets")
    if topk < 1:
        raise RuntimeError("topk must be at least 1")
    if topk > memory_header.num_vectors:
        raise RuntimeError("topk must not exceed the number of memory vectors")


def write_binary_dataset(path: Path, vectors: object) -> None:
    np = _import_numpy()
    array = np.asarray(vectors, dtype=np.float32, order="C")
    if array.ndim != 2:
        raise RuntimeError("binary dataset payload must be a 2D float32 matrix")
    if array.shape[1] <= 0:
        raise RuntimeError("binary dataset dimension must be positive")

    header = HEADER_STRUCT.pack(
        MAGIC,
        VERSION,
        FLAG_NORMALIZED | FLAG_ROW_MAJOR,
        int(array.shape[0]),
        int(array.shape[1]),
        0,
    )

    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("wb") as handle:
        handle.write(header)
        array.tofile(handle)


def write_topk_csv(path: Path, indices: object, scores: object) -> None:
    np = _import_numpy()
    indices_array = np.asarray(indices)
    scores_array = np.asarray(scores)
    if indices_array.shape != scores_array.shape:
        raise RuntimeError("indices and scores must have the same shape")
    if indices_array.ndim != 2:
        raise RuntimeError("top-k outputs must be 2D arrays")

    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as handle:
        handle.write("query_id,rank_position,memory_id,score\n")
        for query_id in range(indices_array.shape[0]):
            pairs: list[tuple[int, float]] = []
            for rank_index in range(indices_array.shape[1]):
                memory_id = int(indices_array[query_id, rank_index])
                if memory_id < 0:
                    raise RuntimeError("FAISS returned an invalid memory_id")
                pairs.append((memory_id, float(scores_array[query_id, rank_index])))

            pairs.sort(key=lambda item: (-item[1], item[0]))
            for rank_position, (memory_id, score) in enumerate(pairs, start=1):
                handle.write(f"{query_id},{rank_position},{memory_id},{score:.8f}\n")


def write_phase8_run_metrics_csv(
    path: Path,
    dataset_name: str,
    n: int,
    d: int,
    q: int,
    k: int,
    threads: int,
    build_time: float,
    compute_time: float,
    total_time: float,
) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as handle:
        handle.write("dataset_name,N,D,Q,k,threads,build_time,compute_time,total_time\n")
        handle.write(
            f"{dataset_name},{n},{d},{q},{k},{threads},{build_time:.8f},{compute_time:.8f},{total_time:.8f}\n"
        )


def write_metadata_tsv(path: Path, memory_texts: list[str]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as handle:
        handle.write("memory_id\tmemory_text\n")
        for memory_id, text in enumerate(memory_texts):
            sanitized = text.replace("\t", " ").replace("\r", " ").replace("\n", "\\n")
            handle.write(f"{memory_id}\t{sanitized}\n")


def ensure_file_exists(path: Path, label: str) -> None:
    if not path.exists():
        raise RuntimeError(f"missing {label}: {path}")


def ensure_directory_exists(path: Path, label: str) -> None:
    if not path.is_dir():
        raise RuntimeError(f"missing {label}: {path}")


def resolve_existing_file(path: Path) -> Path:
    resolved = path.expanduser()
    if not resolved.exists():
        raise RuntimeError(f"missing file: {resolved}")
    return resolved


def resolve_existing_dir(path: Path) -> Path:
    resolved = path.expanduser()
    if not resolved.is_dir():
        raise RuntimeError(f"missing directory: {resolved}")
    return resolved
