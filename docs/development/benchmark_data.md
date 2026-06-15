# Benchmark Data Strategy

## Guiding Principle

The project needs two different data categories:

1. Controlled vector benchmarks for exact speedup and correctness.
2. Real-text corpora for realism, demos, and future preprocessing experiments.

These should not be mixed into a single benchmark story.

## Storage Assumption

The host machine stores datasets under:

```text
E:\data
```

Inside WSL2, the same location is available at:

```text
/mnt/e/data
```

## Final Dataset Choices

### 1. Primary Benchmark Dataset: Synthetic Normalized Vectors

Use a local generator to create:

- `memory_vectors.bin`
- `query_vectors.bin`

Why this is the primary benchmark:

1. `N`, `D`, and `Q` are fully controllable.
2. Correctness is easy to isolate from text preprocessing noise.
3. Speedup and load-balance measurements stay focused on the retrieval kernel.
4. It lets us tune runtime to the target 2-3 minute window.

### 2. Large Real-Text Workload: MS MARCO v1.1

Observed local dataset facts:

- path: `E:\data\ms_marco\v1.1`
- queries in train split: `82,326`
- total flattened passages in train split: `676,193`
- average passages per query: `8.21`

Recommended role:

- Use this as a large workload corpus after the basic pipeline is stable.
- Flatten each passage into one memory record.
- Use query text as the query side.

Important note:

MS MARCO v1.1 is not the cleanest global-memory benchmark because its passage lists are query-associated. It is excellent for workload size, but not ideal as the single source of semantic correctness claims.

### 3. Vietnamese Demo Corpus: UIT-ViQuAD2.0

Observed local dataset facts:

- path: `E:\data\UIT-ViQuAD2.0\data`
- train rows: `28,454`
- unique train contexts: `4,101`
- validation rows: `3,814`
- train impossible questions: `9,216`

Recommended role:

1. Use unique `context` strings as memory items.
2. Use `question` as query text.
3. Filter `is_impossible = false` for positive retrieval demos.
4. Keep impossible questions as optional negative-case tests.

Why it is valuable:

1. Vietnamese language support matches the project's likely demo audience.
2. The corpus is small enough to preprocess quickly.
3. The impossible-question field gives a clean negative-test extension.

### 4. Clean English QA Corpus: SQuAD

Observed local dataset facts:

- path: `E:\data\squad\plain_text`
- train rows: `87,599`
- unique train contexts: `18,891`
- validation rows: `10,570`

Recommended role:

1. Use unique `context` strings as memory items.
2. Use `question` as query text.
3. Use this as a clean English reference corpus for demos or smoke tests.

Why it is not the primary benchmark:

It is cleaner than MS MARCO, but much smaller than the synthetic target sizes required for parallel speedup evaluation.

### 5. Deferred Domain Corpus: Vietnamese Legal QA

Observed local dataset facts:

- path: `E:\data\vietnamese-legal-qa\data`
- documents: `9,715`
- near-unique article texts: `9,582`
- generated QA pairs: `29,145`
- average article length: about `2,279` characters

Recommended role:

- Keep this for a later domain-specific demo.
- Do not use it in the first benchmark wave because it introduces chunking decisions too early.

## Dataset Selection Summary

| Dataset | Use now | Role |
| --- | --- | --- |
| Synthetic generator | Yes | Main correctness, runtime, granularity, and speedup benchmark |
| MS MARCO v1.1 | Yes, after core pipeline works | Large real-text workload benchmark |
| UIT-ViQuAD2.0 | Yes | Main Vietnamese demo corpus |
| SQuAD | Yes | Clean English demo and smoke corpus |
| Vietnamese Legal QA | Later | Domain-specific extension |
| MS MARCO v2.1 | Later | Scale-up experiment after v1 is stable |

## Conversion Rules for Real-Text Corpora

### General Rule

The retriever always consumes vectors, not raw text. Text datasets therefore need a preprocessing layer that outputs:

1. `memory_vectors.bin`
2. `query_vectors.bin`
3. `metadata.tsv`

### SQuAD and UIT-ViQuAD2.0

- `memory_id` = stable integer assigned to each unique context
- `memory_text` = context text
- `query_id` = stable integer assigned to each question
- `query_text` = question text

### MS MARCO v1.1

- `memory_id` = stable integer assigned to each flattened passage row
- `memory_text` = passage text
- `query_id` = source query id
- `query_text` = source query

For Phase 0 through Phase 4, deduplication is not required. Simplicity matters more than corpus purity.

## Initial Benchmark Matrix

### Synthetic Runs

- `D = 384`
- `k = 10`
- `Q = 100` for runtime tuning
- `Q = 500` for standard benchmark runs
- `N in {100k, 200k, 500k, 1M, 2M}`
- `5M` is a stretch goal

### Real-Text Runs

- UIT-ViQuAD2.0: use all unique contexts for demo and qualitative retrieval
- SQuAD: use all unique contexts for smoke and cross-language sanity checks
- MS MARCO v1.1: start with subsets, then scale toward the full flattened train passages

## What Counts as Ground Truth

For this project:

1. Retrieval correctness means sequential and parallel outputs match on the same vector inputs.
2. It does not require proving that a text dataset's annotated answer is the globally best semantic neighbor.

That distinction keeps the report honest and technically clean.
