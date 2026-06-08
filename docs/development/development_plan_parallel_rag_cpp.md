# Development Plan: Parallel Retrieval Engine for RAG in C/C++

## 1. Tổng quan project

Tên project gợi ý:

> **Parallel Retrieval Engine for RAG in C/C++**

Mục tiêu chính của project là xây dựng một hệ thống RAG đơn giản, trong đó phần quan trọng nhất là **retrieval engine song song được tự cài đặt bằng C/C++**.

Pipeline tổng thể:

```text
Documents
→ Chunking
→ Embedding
→ Vector storage
→ Serial retrieval baseline
→ Parallel retrieval engine
→ Top-k context
→ LLM generation
→ Demo RAG
→ Benchmark report
```

Nguyên tắc chia scope:

```text
Tự code:
- Những phần thể hiện rõ parallel computing
- Những phần có thể benchmark serial vs parallel
- Những phần liên quan trực tiếp đến retrieval engine

Dùng thư viện:
- Những phần không phải trọng tâm parallel
- Những phần quá lớn hoặc không đáng tự cài đặt
- Embedding model, LLM, tokenizer, parser, HTTP, JSON
```

---

## Phase 0 — Chốt scope và kiến trúc tổng thể

### Làm gì?

Ở phase này, cần xác định rõ project sẽ làm đến đâu và không làm đến đâu.

Các điểm cần chốt:

```text
- Dataset dùng để test RAG
- Embedding dimension, ví dụ 384 hoặc 768
- Top-k retrieval, ví dụ top-5 hoặc top-10
- Parallel framework: OpenMP, pthread hoặc std::thread
- Cách gọi LLM: llama.cpp, Ollama, API, hoặc mock answer
- Format lưu embedding: CSV, binary, JSONL
```

### Vì sao cần phase này?

Nếu không chốt scope sớm, project rất dễ bị loãng. Có thể mất quá nhiều thời gian vào LLM, tokenizer, PDF parser, web UI… trong khi phần quan trọng nhất là **parallel retrieval**.

### Hoàn thành phase này khi đạt được gì?

Cần có:

```text
- Sơ đồ architecture tổng thể
- Danh sách module sẽ tự code
- Danh sách module dùng thư viện
- Metric sẽ dùng để đánh giá
- Dataset thử nghiệm ban đầu
```

Output đề xuất:

```text
docs/project_scope.md
```

---

## Phase 1 — Dựng codebase C/C++

### Làm gì?

Tạo cấu trúc project rõ ràng:

```text
rag-parallel-cpp/
├── CMakeLists.txt
├── src/
│   ├── main.cpp
│   ├── vector_store.cpp
│   ├── retrieval_serial.cpp
│   ├── retrieval_parallel.cpp
│   ├── topk.cpp
│   └── benchmark.cpp
├── include/
│   ├── vector_store.h
│   ├── retrieval.h
│   ├── topk.h
│   └── benchmark.h
├── data/
├── scripts/
├── docs/
└── README.md
```

Setup các thành phần nền tảng:

```text
- Build bằng CMake
- Compiler flags cho optimization
- OpenMP hoặc pthread
- Logging đơn giản
- CLI arguments đơn giản
```

Ví dụ CLI sau này:

```bash
./rag_search --query query.bin --vectors docs.bin --topk 5 --threads 8
```

### Vì sao cần phase này?

Phase này giúp project có nền tảng sạch. Sau này khi thêm serial retrieval, parallel retrieval, benchmark, RAG demo thì không bị rối.

### Hoàn thành phase này khi đạt được gì?

Cần đạt:

```text
- Build được project bằng CMake
- Chạy được chương trình C++ đầu tiên
- Có cấu trúc module rõ ràng
- Có README hướng dẫn build/run
```

Demo tối thiểu:

```bash
mkdir build
cd build
cmake ..
make
./rag_parallel_demo
```

Kết quả mong muốn:

```text
Project initialized successfully.
```

---

## Phase 2 — Data preparation và chunking

### Làm gì?

Chuẩn bị dữ liệu đầu vào cho RAG.

Có thể dùng dataset dạng text đơn giản trước:

```text
- File .txt
- Nhiều document nhỏ
- Hoặc một tập paragraph
```

Viết module chunking đơn giản:

```text
Document → nhiều chunk nhỏ
```

Mỗi chunk nên có metadata:

```text
chunk_id
document_id
chunk_text
source_file
```

Ví dụ output:

```json
{
  "chunk_id": 15,
  "doc_id": "doc_03",
  "text": "Parallel computing is a type of computation...",
  "source": "parallel_intro.txt"
}
```

### Vì sao cần phase này?

RAG không retrieve cả document dài, mà thường retrieve các chunk nhỏ. Nếu không có chunking, phần retrieval sẽ không giống RAG thật.

Tuy nhiên, chunking không phải trọng tâm parallel, nên chỉ cần làm đơn giản, không cần quá phức tạp.

### Hoàn thành phase này khi đạt được gì?

Cần có:

```text
- Module đọc document text
- Module chia chunk
- File chunks.jsonl hoặc chunks.txt
- Mỗi chunk có ID rõ ràng
```

Demo tối thiểu:

```bash
./prepare_chunks --input data/raw --output data/chunks.jsonl
```

Kết quả mong muốn:

```text
Loaded 20 documents.
Generated 1,250 chunks.
Saved to data/chunks.jsonl.
```

---

## Phase 3 — Embedding pipeline

### Làm gì?

Tạo embedding cho từng chunk.

Phần này **không nên tự code model embedding**. Nên dùng thư viện hoặc script ngoài.

Pipeline đề xuất:

```text
chunks.jsonl
→ Python script / ONNX / API / sentence-transformer
→ embeddings.bin
→ metadata.jsonl
```

Trong C++, chỉ cần đọc embedding đã được tạo sẵn.

Format đơn giản:

```text
embeddings.bin:
[num_vectors][dimension][float float float...]

metadata.jsonl:
chunk_id, doc_id, text, source
```

### Vì sao cần phase này?

Retrieval engine cần vector để tính similarity. Đây là input chính cho phần parallel computing.

Embedding model không phải trọng tâm, nên dùng thư viện là hợp lý.

### Hoàn thành phase này khi đạt được gì?

Cần có:

```text
- File embedding vectors
- File metadata mapping vector_id → chunk_text
- C++ đọc được embedding vào memory
- Kiểm tra đúng số vector và dimension
```

Demo tối thiểu:

```bash
./load_vectors --vectors data/embeddings.bin
```

Kết quả mong muốn:

```text
Loaded 1250 vectors.
Dimension: 384.
Memory usage: 1.83 MB.
```

---

## Phase 4 — Serial retrieval baseline

### Làm gì?

Tự code bản retrieval tuần tự.

Luồng xử lý:

```text
Input query embedding
→ tính similarity với từng document vector
→ chọn top-k chunk tốt nhất
→ trả về chunk_id + score
```

Similarity có thể dùng:

```text
- Dot product
- Cosine similarity
```

Với cosine similarity, nên normalize vector trước để lúc search chỉ cần dot product.

### Vì sao cần phase này?

Serial baseline cực kỳ quan trọng. Cần nó để so sánh với bản parallel.

Không có serial baseline thì không chứng minh được parallel nhanh hơn bao nhiêu.

### Hoàn thành phase này khi đạt được gì?

Cần có:

```text
- Module retrieval_serial
- Tính đúng similarity
- Trả về top-k đúng
- Chạy được với một query embedding
```

Metric cần có:

```text
- Latency của serial search
- Top-k result
- Số vector đã scan
```

Demo tối thiểu:

```bash
./search_serial --query data/query.bin --vectors data/embeddings.bin --topk 5
```

Kết quả mong muốn:

```text
Top-5 results:
1. chunk_102 | score = 0.812
2. chunk_087 | score = 0.795
3. chunk_911 | score = 0.774
...

Latency: 42.5 ms
```

---

## Phase 5 — Parallel retrieval engine

### Làm gì?

Đây là phase quan trọng nhất.

Viết bản retrieval song song:

```text
- Chia vector database thành nhiều phần
- Mỗi thread xử lý một phần
- Mỗi thread tự giữ local top-k
- Merge local top-k thành global top-k
```

Mô hình xử lý:

```text
Thread 1 → vectors 0 đến 9999 → local top-k
Thread 2 → vectors 10000 đến 19999 → local top-k
Thread 3 → vectors 20000 đến 29999 → local top-k
...
Merge → global top-k
```

Không nên để nhiều thread cùng ghi vào một heap chung, vì sẽ bị lock và chậm.

### Vì sao cần phase này?

Đây là phần thể hiện rõ nhất kiến thức parallel computing:

```text
- Data parallelism
- Work partitioning
- Thread-local computation
- Synchronization reduction
- Top-k merge
- Speedup measurement
```

Đây nên là phần chính của project.

### Hoàn thành phase này khi đạt được gì?

Cần có:

```text
- Module retrieval_parallel
- Cho phép chọn số thread
- Kết quả top-k giống bản serial
- Có đo latency
```

Metric bắt buộc:

```text
Correctness:
- Parallel top-k phải giống serial top-k

Performance:
- Có speedup khi tăng số thread
```

Target hợp lý ban đầu:

```text
Dataset: >= 10,000 chunks
Embedding dim: 384
Top-k: 5

4 threads: speedup >= 2.5x so với serial
8 threads: speedup >= 4x so với serial
```

Demo tối thiểu:

```bash
./search_parallel   --query data/query.bin   --vectors data/embeddings.bin   --topk 5   --threads 8
```

Kết quả mong muốn:

```text
Top-5 results matched serial baseline.

Serial latency: 80.0 ms
Parallel latency: 18.5 ms
Speedup: 4.32x
Threads: 8
```

---

## Phase 6 — Benchmark và performance analysis

### Làm gì?

Ở phase này, không thêm tính năng RAG mới, mà tập trung đo đạc.

Benchmark với nhiều cấu hình:

```text
- Số vector: 1k, 10k, 50k, 100k
- Dimension: 384, 768
- Top-k: 5, 10, 20
- Threads: 1, 2, 4, 8, 16
```

Cần đo:

```text
- Latency
- Throughput
- Speedup
- Efficiency
- Memory usage
- Correctness so với serial
```

Công thức:

```text
Speedup = T_serial / T_parallel

Efficiency = Speedup / number_of_threads
```

### Vì sao cần phase này?

Project parallel computing không chỉ cần “chạy được”, mà phải chứng minh được:

```text
- Chạy nhanh hơn thật
- Nhanh hơn bao nhiêu
- Khi nào tăng thread không còn hiệu quả
- Bottleneck nằm ở đâu
```

Phần này rất quan trọng cho report và presentation.

### Hoàn thành phase này khi đạt được gì?

Cần có:

```text
- Module benchmark
- Xuất kết quả ra CSV
- Có bảng so sánh serial vs parallel
- Có biểu đồ speedup hoặc efficiency
```

Demo tối thiểu:

```bash
./benchmark   --vectors data/embeddings.bin   --queries data/queries.bin   --topk 5   --threads 1,2,4,8
```

Output mong muốn:

```text
benchmark_results.csv
```

Ví dụ bảng:

| Threads | Latency | Speedup | Efficiency |
|---:|---:|---:|---:|
| 1 | 80.0 ms | 1.00x | 100% |
| 2 | 43.0 ms | 1.86x | 93% |
| 4 | 24.0 ms | 3.33x | 83% |
| 8 | 18.5 ms | 4.32x | 54% |

---

## Phase 7 — RAG integration

### Làm gì?

Nối retrieval engine vào pipeline RAG thật.

Luồng demo:

```text
User question
→ tạo query embedding
→ gọi parallel retrieval engine
→ lấy top-k chunks
→ ghép context
→ gửi vào LLM
→ nhận answer
```

Prompt có thể dạng:

```text
You are a helpful assistant.
Use the following context to answer the question.

Context:
{top_k_chunks}

Question:
{user_question}

Answer:
```

Phần LLM có thể dùng:

```text
- Ollama
- llama.cpp server
- OpenAI API
- hoặc mock LLM nếu project tập trung retrieval
```

### Vì sao cần phase này?

Đến phase này, project không chỉ là vector search benchmark nữa, mà trở thành một hệ thống RAG hoàn chỉnh.

Tuy nhiên, phần RAG chỉ nên là demo sản phẩm. Phần đánh giá chính vẫn là parallel retrieval.

### Hoàn thành phase này khi đạt được gì?

Cần có:

```text
- Nhập câu hỏi từ CLI
- Tạo query embedding
- Retrieve top-k bằng parallel engine
- Hiển thị retrieved chunks
- Sinh câu trả lời bằng LLM
```

Demo tối thiểu:

```bash
./rag_demo --question "What is parallel computing?" --topk 5 --threads 8
```

Kết quả mong muốn:

```text
Question:
What is parallel computing?

Retrieved chunks:
1. chunk_12 | score = 0.84
2. chunk_41 | score = 0.79
...

Answer:
Parallel computing is a method of computation where multiple processors...
```

---

## Phase 8 — So sánh với thư viện baseline

### Làm gì?

Dùng FAISS hoặc hnswlib làm baseline.

Mục tiêu không phải thay thế code tự viết, mà để trả lời câu hỏi:

```text
Implementation from scratch của mình nhanh/chậm hơn thư viện như thế nào?
```

Có thể so sánh:

```text
- Your serial exact search
- Your parallel exact search
- FAISS exact search
- FAISS approximate search nếu muốn
```

### Vì sao cần phase này?

So sánh với thư viện giúp project đáng tin hơn.

Có thể trình bày rõ:

```text
- Project tự code để học parallel computing
- FAISS/hnswlib được dùng làm reference baseline
- Kết quả cho thấy thư viện production tối ưu hơn, nhưng code tự viết thể hiện rõ parallel design
```

### Hoàn thành phase này khi đạt được gì?

Cần có:

```text
- Một bảng so sánh performance
- Một đoạn phân tích vì sao có chênh lệch
- Kết luận điểm mạnh/yếu của implementation
```

Metric nên có:

```text
- Latency
- Speedup
- Recall@K
- Memory usage
```

---

## Phase 9 — Final demo và report

### Làm gì?

Đóng gói project để trình bày.

Cần chuẩn bị:

```text
- Demo script
- README hoàn chỉnh
- Architecture diagram
- Benchmark table
- Performance chart
- Explanation về parallel strategy
- Limitation và future work
```

Demo nên có 2 phần:

### Demo 1: RAG chạy được

```text
User nhập câu hỏi
→ hệ thống retrieve context
→ LLM trả lời
```

### Demo 2: Parallel benchmark

```text
Chạy cùng một query với 1, 2, 4, 8 threads
→ show latency giảm
→ show speedup
```

### Vì sao cần phase này?

Project không chỉ cần code chạy được, mà còn cần trình bày rõ:

```text
- Tự code phần nào
- Phần nào dùng thư viện
- Parallel nằm ở đâu
- Vì sao thiết kế đó hợp lý
- Performance cải thiện như thế nào
```

### Hoàn thành phase này khi đạt được gì?

Cần có:

```text
- Demo chạy end-to-end
- Benchmark có số liệu
- README đủ để người khác build/run
- Report giải thích rõ parallel design
- Slide hoặc tài liệu trình bày
```

Demo cuối cùng nên chạy được bằng vài command đơn giản:

```bash
./prepare_chunks
./generate_embeddings
./benchmark
./rag_demo --question "..." --threads 8
```

---

## Tóm tắt các phase

| Phase | Tên phase | Kết quả cần đạt |
|---:|---|---|
| 0 | Chốt scope & architecture | Có tài liệu scope, module, metric |
| 1 | Dựng codebase | Build được C++ project |
| 2 | Data & chunking | Tạo được chunks từ document |
| 3 | Embedding pipeline | Có embeddings và C++ load được |
| 4 | Serial retrieval | Có baseline tuần tự |
| 5 | Parallel retrieval | Có engine song song, top-k đúng |
| 6 | Benchmark | Có latency, speedup, efficiency |
| 7 | RAG integration | Demo hỏi đáp chạy được |
| 8 | Library baseline | So sánh với FAISS/hnswlib |
| 9 | Final demo & report | Demo + report hoàn chỉnh |

---

## Thứ tự ưu tiên

Nếu thời gian ít, nên ưu tiên:

```text
Must-have:
1. Codebase
2. Embedding loader
3. Serial retrieval
4. Parallel retrieval
5. Benchmark
6. RAG demo đơn giản

Nice-to-have:
7. FAISS comparison
8. Hybrid search BM25 + dense
9. Web UI
10. GPU version
```

Phần cốt lõi để project được đánh giá tốt:

> **Serial retrieval baseline → parallel retrieval engine → benchmark chứng minh speedup → RAG demo sử dụng engine đó.**

---

## Scope tự code và dùng thư viện

### Nên tự code

```text
- Chunking đơn giản
- Vector storage
- Binary embedding loader
- Serial exact search
- Parallel exact search
- Thread-local top-k
- Top-k merge
- Benchmark module
- CSV result export
```

### Nên dùng thư viện

```text
- Embedding model
- LLM generation
- Tokenizer
- PDF/DOCX parser
- JSON parser
- HTTP client
- FAISS/hnswlib làm baseline, không làm phần chính
```

---

## Metric đánh giá cuối project

| Metric | Ý nghĩa |
|---|---|
| Latency | Một query mất bao lâu |
| Throughput | Xử lý được bao nhiêu query/giây |
| Speedup | Parallel nhanh hơn serial bao nhiêu lần |
| Efficiency | Dùng thread có hiệu quả không |
| Correctness | Top-k parallel có giống serial không |
| Recall@K | Kết quả retrieval có đúng không |
| Memory usage | Bộ nhớ dùng cho embedding/index |

Công thức:

```text
Speedup = T_serial / T_parallel

Efficiency = Speedup / number_of_threads
```

---

## Kết luận

Project nên tập trung vào:

> **C/C++ RAG system with a from-scratch parallel vector retrieval engine.**

Trong đó:

```text
Tự code phần lõi:
- Vector search
- Parallel retrieval
- Top-k merge
- Benchmark

Dùng thư viện cho phần phụ trợ:
- Embedding
- LLM
- Parser
- API
```

Đây là scope vừa đủ để có một demo RAG hoàn chỉnh, đồng thời vẫn thể hiện rõ kiến thức parallel computing.
