# Phase 0: Scope, Architecture, Dataset & Parallel Algorithm

## Project: Parallel Retrieval Engine for RAG in C/C++

Phase 0 dùng để chốt phạm vi project trước khi bắt đầu code.  
Mục tiêu quan trọng nhất là đảm bảo project tập trung vào **parallel computing**, không bị loãng sang deploy model, train model, tokenizer hay giao diện.

---

## 1. Mục tiêu Phase 0

Project sẽ xây dựng một hệ thống RAG đơn giản, trong đó:

```text
LLM generation: dùng API
Embedding model: dùng API
Retrieval engine: tự code bằng C/C++
Parallel implementation: dùng OpenMP
```

Điểm cần nhấn mạnh:

> OpenMP chỉ là công cụ triển khai. Thuật toán retrieval phải có tính song song tự nhiên ngay cả trước khi thêm OpenMP.

---

## 2. Scope tổng thể

### 2.1. Không làm

Các phần sau **không tự code** trong project:

```text
- Không tự train model
- Không tự deploy LLM
- Không tự code transformer inference
- Không tự code embedding model
- Không tự code tokenizer
- Không tự code PDF/DOCX parser phức tạp
```

Lý do:

```text
- Các phần này không phải trọng tâm parallel computing.
- Tốn nhiều thời gian nhưng không trực tiếp chứng minh speedup.
- Có thể dùng API hoặc thư viện có sẵn.
```

### 2.2. Có làm

Các phần sau sẽ tự code:

```text
- Vector storage
- Binary embedding loader
- Serial exact vector retrieval
- Parallel exact vector retrieval
- Thread-local top-k
- Global top-k merge
- Benchmark module
- CSV result exporter
```

Đây là các phần thể hiện rõ kiến thức:

```text
- Data parallelism
- Work partitioning
- Thread-local computation
- Synchronization reduction
- Top-k merge
- Speedup measurement
```

---

## 3. Kiến trúc tổng thể

Pipeline toàn hệ thống:

```text
Raw documents
→ Chunking
→ Call Embedding API
→ Save embeddings.bin + metadata.jsonl
→ C++ vector retrieval engine
→ Top-k chunks
→ Call LLM API
→ Answer
```

Có thể chia hệ thống thành 2 lớp:

### 3.1. RAG API pipeline

Lớp này dùng để tạo dữ liệu và chạy demo RAG.

Nhiệm vụ:

```text
- Đọc document
- Chia document thành chunk
- Gọi Embedding API cho từng chunk
- Lưu embedding xuống file
- Nhận câu hỏi từ user
- Gọi Embedding API cho query
- Gửi top-k context vào LLM API
- Nhận câu trả lời
```

Phần này có thể viết bằng:

```text
- Python
- hoặc C++ đơn giản với HTTP client
```

Khuyến nghị: dùng Python cho phần API pipeline để tiết kiệm thời gian.

### 3.2. C++ parallel retrieval engine

Đây là phần lõi của project.

Input:

```text
- Query embedding
- Document embeddings
- Top-k
- Number of threads
```

Output:

```text
- Top-k chunk IDs
- Similarity scores
- Retrieval latency
```

C++ engine không cần biết LLM là gì. Nó chỉ cần làm tốt một việc:

> Nhận query vector và tìm top-k document vectors gần nhất càng nhanh càng tốt.

---

## 4. Quyết định dùng API

### 4.1. Embedding API

Embedding API dùng để biến text thành vector.

Ví dụ có thể dùng:

```text
- OpenAI Embeddings API
- Cohere Embed API
- Jina Embeddings API
- Voyage AI Embeddings API
```

Phase đầu chỉ nên chọn **một provider cố định**.

Lý do:

```text
- Tránh phải re-embed dataset nhiều lần
- Tránh thay đổi dimension giữa các model
- Giữ benchmark ổn định
```

### 4.2. LLM API

LLM API dùng để sinh câu trả lời cuối cùng từ top-k chunks.

Ví dụ có thể dùng:

```text
- OpenAI API
- Anthropic API
- Gemini API
- Groq API
- OpenRouter API
```

Trong project này, LLM API chỉ đóng vai trò demo.  
Phần đánh giá chính vẫn là retrieval engine.

---

## 5. Không tính thời gian API vào benchmark

Đây là quyết định rất quan trọng.

Khi benchmark parallel retrieval, không được tính:

```text
- Thời gian gọi Embedding API
- Thời gian gọi LLM API
- Network latency
- API rate limit delay
- Server-side latency
```

Chỉ đo:

```text
- Thời gian C++ retrieval engine tính similarity
- Thời gian top-k local
- Thời gian merge top-k
```

Khuyến nghị benchmark:

```text
Offline:
- Gọi API tạo embedding chunks
- Gọi API tạo query embeddings
- Lưu xuống file

Online benchmark:
- Load embeddings
- Chạy serial retrieval
- Chạy parallel retrieval
- So sánh latency và speedup
```

---

## 6. Chứng minh thuật toán có tính parallel

### 6.1. Bài toán retrieval

Giả sử có:

```text
N document vectors
Mỗi vector có dimension D
Một query vector q
```

Cần tính:

```text
score[i] = dot(q, doc_vector[i])
```

với mọi:

```text
i = 0 → N - 1
```

Điểm quan trọng:

```text
score[0] không phụ thuộc score[1]
score[1] không phụ thuộc score[2]
score[i] không phụ thuộc score[j]
```

Vì vậy, việc tính similarity giữa query và từng document vector là một bài toán **data parallelism**.

### 6.2. Thuật toán parallel độc lập với OpenMP

Trước khi dùng OpenMP, thuật toán có thể mô tả như sau:

```text
1. Chia N vectors thành P partitions.

2. Mỗi partition xử lý độc lập:
   - Tính similarity cho các vector trong partition.
   - Giữ local top-k.

3. Sau khi tất cả partitions xử lý xong:
   - Merge P local top-k lists.
   - Lấy global top-k.

4. Trả về global top-k.
```

Pseudo-code:

```text
parallel_retrieval(query, vectors, top_k, num_partitions):

    partitions = split(vectors, num_partitions)

    for each partition in partitions:
        local_topk[partition] = search_partition(query, partition, top_k)

    global_topk = merge(local_topk, top_k)

    return global_topk
```

Nếu chưa dùng OpenMP, các partition vẫn có thể chạy tuần tự:

```text
Partition 1 → chạy xong
Partition 2 → chạy xong
Partition 3 → chạy xong
...
Merge
```

Khi thêm OpenMP, chỉ thay phần loop xử lý partition bằng parallel loop.

### 6.3. Vai trò của OpenMP

OpenMP không tạo ra tính parallel của thuật toán.  
OpenMP chỉ giúp hiện thực hóa chiến lược parallel đó trên nhiều thread.

Ý tưởng triển khai:

```cpp
#pragma omp parallel for
for (int p = 0; p < num_partitions; ++p) {
    local_topk[p] = search_partition(query, vectors, partitions[p], top_k);
}
```

Câu nên đưa vào report:

> Although OpenMP is used in the implementation, the retrieval algorithm is inherently parallel because similarity scores between the query vector and document vectors are independent. The vector database is partitioned into independent blocks, each block computes its own local top-k results, and the final result is obtained by merging local top-k lists into a global top-k list.

---

## 7. Retrieval design

### 7.1. Retrieval type

Phase đầu nên chọn:

```text
Exact dense vector search
```

Không nên làm ngay:

```text
- HNSW
- IVF
- Product Quantization
- Approximate nearest neighbor search
```

Lý do:

```text
- Exact search dễ kiểm tra correctness.
- Dễ so sánh serial và parallel.
- Dễ chứng minh speedup.
- Dễ giải thích trong report.
```

### 7.2. Similarity function

Nên dùng:

```text
Cosine similarity
```

Nhưng để tối ưu, nên normalize vector trước.

Nếu query vector và document vectors đã được normalize:

```text
cosine(q, x) = dot(q, x)
```

Khi đó search chỉ cần tính dot product:

```text
score = q[0] * x[0] + q[1] * x[1] + ... + q[D-1] * x[D-1]
```

### 7.3. Parallel strategy

Chiến lược chính:

```text
Parallel theo document vectors
```

Không ưu tiên parallel theo dimension ở phase đầu.

Lý do:

```text
- Chia việc đơn giản
- Ít synchronization
- Mỗi thread xử lý một vùng vector riêng
- Mỗi thread có local top-k riêng
- Merge cuối cùng đơn giản
```

Ví dụ:

```text
Thread 1 → vectors 0 đến 9999
Thread 2 → vectors 10000 đến 19999
Thread 3 → vectors 20000 đến 29999
Thread 4 → vectors 30000 đến 39999
```

### 7.4. Thread-local top-k

Không nên để nhiều thread cùng ghi vào một global heap.

Thiết kế không tốt:

```text
Thread 1, 2, 3, 4 cùng update global top-k
→ cần lock
→ lock contention
→ chậm
```

Thiết kế tốt hơn:

```text
Thread 1 → local top-k
Thread 2 → local top-k
Thread 3 → local top-k
Thread 4 → local top-k
Merge local top-k → global top-k
```

Lợi ích:

```text
- Giảm synchronization
- Giảm lock contention
- Dễ debug
- Dễ so sánh kết quả với serial
```

---

## 8. File format quyết định ở Phase 0

### 8.1. embeddings.bin

Đề xuất binary format:

```text
int32 num_vectors
int32 dimension
float32 vector_0[dimension]
float32 vector_1[dimension]
...
float32 vector_n[dimension]
```

Ưu điểm:

```text
- Load nhanh
- Nhẹ hơn CSV/JSON
- Hợp với C/C++
- Dễ dùng cho benchmark
```

### 8.2. metadata.jsonl

Mỗi dòng là một JSON object:

```json
{
  "vector_id": 0,
  "chunk_id": "doc_001_chunk_000",
  "doc_id": "doc_001",
  "text": "Parallel computing is a type of computation...",
  "source": "parallel_intro.txt"
}
```

Dùng để map:

```text
vector_id → chunk text
```

### 8.3. queries.bin

Để benchmark, nên precompute query embeddings:

```text
int32 num_queries
int32 dimension
float32 query_0[dimension]
float32 query_1[dimension]
...
```

Lý do:

```text
- Không cần gọi API trong lúc benchmark
- Kết quả đo ổn định hơn
- Có thể benchmark throughput nhiều query
```

---

## 9. Dataset khả thi

Nên chia dataset thành 3 nhóm:

```text
1. Dataset cho demo RAG
2. Dataset cho benchmark parallel
3. Dataset cho retrieval evaluation
```

Một dataset có thể dùng cho nhiều mục đích, nhưng không bắt buộc.

### 9.1. SQuAD

**Phù hợp cho:**

```text
- Demo RAG tiếng Anh
- Kiểm tra end-to-end pipeline
- So sánh câu trả lời với ground truth
```

**Điểm mạnh:**

```text
- Dễ dùng
- Có question-answer rõ ràng
- Có context sẵn
- Phù hợp demo đầu tiên
```

**Điểm yếu:**

```text
- Corpus không quá lớn
- Không đủ mạnh để stress benchmark parallel ở quy mô lớn
```

**Khuyến nghị:**

```text
Rất nên dùng nếu demo bằng tiếng Anh.
```

### 9.2. UIT-ViQuAD / ViQuAD 2.0

**Phù hợp cho:**

```text
- Demo RAG tiếng Việt
- Hỏi đáp tiếng Việt
- Trình bày với giảng viên/người nghe Việt Nam
```

**Điểm mạnh:**

```text
- Tiếng Việt
- Có question-answer
- Có context/passages
- Dễ trình bày
```

**Điểm yếu:**

```text
- Corpus không quá lớn
- Benchmark parallel chưa đủ căng nếu chỉ dùng nguyên bản
```

**Khuyến nghị:**

```text
Rất nên dùng nếu muốn demo tiếng Việt.
```

### 9.3. SciFact

**Phù hợp cho:**

```text
- Retrieval evaluation
- Evidence retrieval
- Demo dạng claim checking
```

**Điểm mạnh:**

```text
- Có corpus và claim rõ ràng
- Có thể đánh giá retrieval tốt hơn demo tự do
- Domain khoa học giúp project có vẻ nghiên cứu hơn
```

**Điểm yếu:**

```text
- Corpus nhỏ
- Nội dung khoa học có thể khó demo cho người xem phổ thông
```

**Khuyến nghị:**

```text
Nên dùng làm dataset phụ hoặc evaluation dataset.
```

### 9.4. BEIR subsets

**Phù hợp cho:**

```text
- Retrieval evaluation chuẩn hơn
- Đo Recall@K
- Đo nDCG@K nếu có thời gian
```

Có thể chọn subset nhỏ:

```text
- SciFact
- FiQA
- NFCorpus
- TREC-COVID
```

**Điểm mạnh:**

```text
- Có corpus, query và qrels
- Hợp với retrieval engine
- Dễ viết phần đánh giá Recall@K
```

**Điểm yếu:**

```text
- Format phức tạp hơn SQuAD
- Cần viết converter
- Có thể mất thời gian xử lý ban đầu
```

**Khuyến nghị:**

```text
Nên dùng sau khi demo chính đã chạy.
```

### 9.5. MS MARCO Passage Ranking

**Phù hợp cho:**

```text
- Benchmark parallel ở quy mô lớn
- Stress test vector search
- Đánh giá latency khi tăng số lượng vectors
```

Không nên dùng full dataset ngay từ đầu. Nên sample các mốc:

```text
- 10k passages
- 50k passages
- 100k passages
- 500k passages nếu đủ RAM và budget API
```

**Điểm mạnh:**

```text
- Corpus lớn
- Rất hợp để chứng minh speedup
- Query tự nhiên
```

**Điểm yếu:**

```text
- Full dataset quá lớn
- Embedding bằng API có thể tốn tiền
- Cần sampling cẩn thận
```

**Khuyến nghị:**

```text
Nên dùng cho benchmark scale.
```

### 9.6. HotpotQA

**Phù hợp cho:**

```text
- RAG nâng cao
- Multi-hop retrieval
- Demo sau khi pipeline cơ bản đã ổn định
```

**Điểm mạnh:**

```text
- Câu hỏi phức tạp hơn SQuAD
- Có supporting facts
- RAG demo trông thông minh hơn
```

**Điểm yếu:**

```text
- Khó hơn SQuAD
- Retrieval sai một evidence là answer dễ sai
- Không nên dùng ở phase đầu
```

**Khuyến nghị:**

```text
Để phase sau, không dùng ngay Phase 0/1.
```

### 9.7. Vietnamese Wikipedia corpus

**Phù hợp cho:**

```text
- Benchmark retrieval tiếng Việt
- Scale corpus lớn
- Demo tự tạo câu hỏi tiếng Việt
```

**Điểm mạnh:**

```text
- Tiếng Việt
- Có thể scale lớn hơn UIT-ViQuAD
- Hợp để benchmark với corpus tiếng Việt
```

**Điểm yếu:**

```text
- Không có sẵn question-answer chuẩn
- Không có qrels chuẩn
- Khó đánh giá Recall@K nếu không tự tạo ground truth
```

**Khuyến nghị:**

```text
Nên dùng để scale benchmark tiếng Việt, không nên dùng làm dataset QA chính.
```

---

## 10. Đề xuất dataset cuối cùng

### Option A: Demo tiếng Việt

```text
Main demo dataset:
- UIT-ViQuAD / ViQuAD 2.0

Benchmark dataset:
- MS MARCO sampled subset
- hoặc Vietnamese Wikipedia corpus nếu muốn benchmark tiếng Việt

Optional evaluation:
- BEIR/SciFact
```

Ưu điểm:

```text
- Dễ trình bày bằng tiếng Việt
- Gần với người nghe Việt Nam
- Có thể demo hỏi đáp tự nhiên bằng tiếng Việt
```

### Option B: Demo tiếng Anh

```text
Main demo dataset:
- SQuAD

Benchmark dataset:
- MS MARCO sampled subset

Optional evaluation:
- BEIR/SciFact
```

Ưu điểm:

```text
- Dataset phổ biến
- Dễ viết report academic
- Nhiều tài liệu tham khảo
```

### Khuyến nghị cá nhân

Nếu project trình bày ở lớp tại Việt Nam:

```text
Main demo:
- UIT-ViQuAD

Benchmark:
- MS MARCO subset 10k, 50k, 100k

Evaluation phụ:
- SciFact hoặc BEIR/SciFact
```

Nếu muốn report nhìn academic hơn:

```text
Main demo:
- SQuAD

Benchmark:
- MS MARCO subset

Evaluation phụ:
- BEIR/SciFact
```

---

## 11. Metric cần chốt trong Phase 0

### 11.1. Correctness

```text
Parallel top-k phải giống serial top-k
```

Cách kiểm tra:

```text
- Chạy cùng query
- Chạy serial retrieval
- Chạy parallel retrieval
- So sánh danh sách top-k chunk_id và score
```

### 11.2. Performance

Cần đo:

```text
- Latency
- Throughput
- Speedup
- Efficiency
```

Công thức:

```text
Speedup = T_serial / T_parallel

Efficiency = Speedup / number_of_threads
```

Ví dụ benchmark table:

| Threads | Latency | Speedup | Efficiency |
|---:|---:|---:|---:|
| 1 | 80.0 ms | 1.00x | 100% |
| 2 | 43.0 ms | 1.86x | 93% |
| 4 | 24.0 ms | 3.33x | 83% |
| 8 | 18.5 ms | 4.32x | 54% |

### 11.3. Retrieval quality

Nếu dataset có ground truth hoặc qrels, đo thêm:

```text
- Recall@K
- Precision@K
- MRR@K
- nDCG@K nếu có thời gian
```

Nếu không có ground truth, ít nhất cần show:

```text
- Top-k retrieved chunks
- Similarity scores
- LLM answer dựa trên context
```

---

## 12. Deliverables của Phase 0

Khi kết thúc Phase 0, cần có các tài liệu:

```text
docs/phase0_scope.md
docs/architecture.md
docs/dataset_decision.md
docs/benchmark_plan.md
```

Có thể gộp thành một file nếu project nhỏ:

```text
docs/phase0_scope.md
```

---

## 13. Acceptance Criteria cho Phase 0

Phase 0 được coi là hoàn thành khi có đủ các quyết định sau:

### Architecture

```text
- RAG dùng API
- Retrieval engine tự code bằng C/C++
- OpenMP dùng để triển khai parallel retrieval
- API latency không được tính vào benchmark retrieval
```

### Algorithm

```text
- Exact dense vector search
- Similarity bằng dot product trên normalized vectors
- Data parallel over document vectors
- Thread-local top-k
- Global top-k merge
```

### Dataset

```text
- Main demo dataset: SQuAD hoặc UIT-ViQuAD
- Benchmark dataset: MS MARCO sampled subset
- Optional evaluation dataset: SciFact hoặc BEIR subset
```

### File format

```text
- embeddings.bin
- queries.bin
- metadata.jsonl
- benchmark_results.csv
```

### Metrics

```text
Correctness:
- Parallel top-k giống serial top-k

Performance:
- Latency
- Throughput
- Speedup
- Efficiency

Retrieval quality:
- Recall@K nếu có qrels
```

---

## 14. Phase 0 final decision đề xuất

Cấu hình đề xuất:

```text
LLM:
- Gọi API, không tự deploy

Embedding:
- Gọi API, precompute embeddings offline

C++ core:
- Exact dense retrieval engine
- Serial baseline
- OpenMP parallel version
- Thread-local top-k
- Top-k merge

Main demo dataset:
- UIT-ViQuAD nếu muốn tiếng Việt
- SQuAD nếu muốn tiếng Anh

Benchmark dataset:
- MS MARCO sampled subset: 10k, 50k, 100k passages

Optional evaluation:
- BEIR/SciFact
```

---

## 15. References

- OpenMP: https://www.openmp.org/
- OpenAI Embeddings Guide: https://developers.openai.com/api/docs/guides/embeddings
- Cohere Embed API: https://docs.cohere.com/reference/embed
- SQuAD: https://rajpurkar.github.io/SQuAD-explorer/
- UIT-ViQuAD / Vietnamese datasets: https://github.com/kietnv/VietnameseDatasets
- SciFact: https://github.com/allenai/scifact
- BEIR paper: https://arxiv.org/abs/2104.08663
- BEIR FiQA dataset: https://huggingface.co/datasets/BeIR/fiqa
- MS MARCO: https://microsoft.github.io/msmarco/
- HotpotQA: https://huggingface.co/datasets/hotpotqa/hotpot_qa
- Vietnamese Wikipedia corpus: https://github.com/undertheseanlp/corpus.viwiki
