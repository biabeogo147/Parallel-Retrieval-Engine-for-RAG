# Kế hoạch project: MPI-Based Parallel Long-Term Memory Retriever for AI Agent

## 0. Tóm tắt quyết định project

### Tên project đề xuất

**MPI-Based Parallel Long-Term Memory Retriever for AI Agent**

Tên tiếng Việt:

**Bộ truy hồi bộ nhớ dài hạn song song cho AI Agent bằng C++ và MPI**

### Ý tưởng chính

Project xây dựng một module truy hồi bộ nhớ dài hạn cho AI Agent. Module này không xây dựng toàn bộ chatbot hay toàn bộ hệ thống RAG, mà tập trung sâu vào một thao tác cốt lõi:

> Cho một query embedding, tìm top-k memory embeddings có độ tương đồng cao nhất trong một kho bộ nhớ lớn.

Module này phù hợp với AI Agent vì các agent hiện đại thường cần truy xuất lại thông tin đã lưu trong bộ nhớ dài hạn trước khi trả lời hoặc ra quyết định. Thay vì dùng thư viện có sẵn như FAISS làm lõi của implementation chính, project tự cài đặt exact top-k vector retrieval bằng C++ và song song hóa bằng MPI để thể hiện rõ kiến thức parallel computing, sau đó dùng FAISS như một external baseline để đối chiếu.

### Câu chốt scope

Project tập trung vào **parallel exact top-k vector retrieval** cho long-term memory của AI Agent. Các phần như chunking, embedding model, tokenizer, LLM generation và giao diện người dùng chỉ là phụ trợ hoặc demo, không phải trọng tâm đánh giá.

---

## 1. Mục tiêu project

### 1.1. Mục tiêu kỹ thuật

Project cần đạt các mục tiêu sau:

1. Tự cài đặt vector store ở mức C++.
2. Tự cài đặt sequential exact top-k retrieval làm baseline.
3. Tự cài đặt MPI-based parallel exact top-k retrieval.
4. Đo riêng thời gian tính toán, thời gian truyền thông và tổng thời gian chạy.
5. Kiểm tra correctness bằng cách so sánh kết quả song song với kết quả tuần tự.
6. Kiểm tra granularity và load balancing trên từng tiến trình.
7. Đo speedup khi thay đổi số lượng tiến trình.
8. Xuất kết quả benchmark ra CSV để vẽ biểu đồ trong report.
9. Có external baseline comparison với FAISS exact flat trên synthetic benchmark và một real corpus đã convert.

### 1.2. Mục tiêu học thuật theo đề parallel computing

Project phải trả lời chặt chẽ các câu hỏi sau:

| Nhóm yêu cầu | Cách project trả lời |
|---|---|
| Song song cấp độ nào? | Data-level parallelism trên tập memory vectors; optional task-level parallelism trên query batch |
| Kỹ thuật phân rã nào? | Data decomposition, cụ thể là 1D block decomposition theo chiều số vector N |
| Mapping technique | Mỗi MPI process nhận một shard liên tiếp của memory database |
| Communication strategy | Rank 0 broadcast query; các rank gửi local top-k về rank 0; rank 0 merge global top-k |
| Topology | Logical master-worker/star topology; collective communication có thể được MPI runtime tối ưu dạng tree |
| Blocking/non-blocking | Bản chính dùng blocking MPI_Bcast/MPI_Gather; bản mở rộng có thể dùng non-blocking MPI_Isend/Irecv |
| Load balancing | Đo compute time, communication time, idle time từng rank; điều chỉnh granularity nếu lệch quá 25% |
| Mã giả | Có pseudocode MPI rõ ràng |
| Correctness | So sánh exact top-k parallel với exact top-k sequential |
| Chọn N | Chạy nhiều kích thước N, chọn N sao cho total runtime khoảng 2-3 phút |
| Granularity | Granularity = số vectors/process hoặc số vectors/block |
| Speedup | Chạy với P = 1, 2, 4, 8, ..., X, 2X trên input 2N |

---

## 2. Phạm vi project

### 2.1. Phần bắt buộc tự code bằng C++

Các phần sau nên tự cài đặt:

```text
- Binary vector dataset generator
- Binary vector dataset loader
- MemoryRecord / VectorStore
- Dot product / cosine similarity
- Sequential exact top-k retrieval
- MPI parallel exact top-k retrieval
- Local top-k min-heap
- Global top-k merge
- MPI communication wrapper
- Timer đo compute/communication/total time
- Benchmark runner
- CSV logger
- Correctness checker
- Granularity/load-balance analyzer
```

### 2.2. Phần được phép dùng thư viện hoặc làm đơn giản

Các phần này không phải trọng tâm, có thể dùng thư viện hoặc mock:

```text
- Embedding model
- Tokenizer
- LLM generation
- PDF/DOCX parser
- JSON parser
- Web UI
- FAISS exact flat CPU baseline
```

Trong plan này, FAISS chỉ được dùng ở vai trò:

```text
- External baseline để so sánh với implementation exact retrieval của project
- CPU-only
- Flat exact search với IndexFlatIP
- Không dùng ANN như IVF/PQ/HNSW trong Phase 8 chính
```

### 2.3. Phần không nên làm trong bản chính

Không nên ôm các phần sau vì dễ làm loãng project:

```text
- Full chatbot agent
- Full RAG pipeline production-level
- Knowledge graph reasoning đầy đủ
- HNSW/ANN approximate search làm thuật toán chính
- GPU implementation
- Web interface phức tạp
```

Lý do: đề đang đánh giá parallel computing, nên cần tập trung vào phần có thể đo speedup, communication, granularity và correctness.

---

## 3. Định nghĩa bài toán

### 3.1. Input

Project nhận các input chính:

```text
N: số lượng memory vectors
D: số chiều embedding, ví dụ 384 hoặc 768
Q: số lượng query vectors
k: số kết quả top-k cần lấy
P: số MPI processes
V: memory embedding matrix kích thước N x D
Q_emb: query embedding matrix kích thước Q x D
```

Mỗi memory record gồm:

```text
memory_id: int
embedding: float[D]
metadata: text hoặc id tham chiếu tới chunk/memory
```

### 3.2. Output

Với mỗi query vector `q`, output là danh sách:

```text
Top-k = [(memory_id_1, score_1), ..., (memory_id_k, score_k)]
```

Trong đó score có thể là dot product hoặc cosine similarity.

### 3.3. Hàm similarity

Nếu vectors đã được normalize, cosine similarity có thể tính bằng dot product:

```text
score(q, v_i) = q · v_i = sum(q[j] * v_i[j]) với j = 0..D-1
```

### 3.4. Độ phức tạp tuần tự

Với exact retrieval:

```text
Cost = O(Q * N * D)
```

Đây là lý do bài toán phù hợp để song song hóa theo dữ liệu khi N lớn.

---

## 4. Thiết kế thuật toán tuần tự

### 4.1. Vai trò

Sequential retriever là baseline để:

1. Kiểm tra correctness của bản song song.
2. Tính speedup.
3. Làm ground truth vì đây là exact search.

### 4.2. Thuật toán tuần tự

```text
For each query q:
    Initialize min-heap H of size k
    For i = 0 to N - 1:
        score = dot(q, V[i])
        If H has less than k items:
            push (i, score) into H
        Else if score > H.min_score:
            pop min item
            push (i, score)
    Sort H descending by score
    Return H as top-k result
```

### 4.3. Tiêu chí đúng

Bản tuần tự phải đảm bảo:

```text
- Tính đúng dot product
- Trả về đúng k phần tử
- Kết quả được sắp xếp giảm dần theo score
- Nếu score bằng nhau, tie-break bằng memory_id để deterministic
```

---

## 5. Thiết kế thuật toán song song

## 5.1. Song song cấp độ nào?

Project sử dụng **data-level parallelism** làm chiến lược chính.

Tập memory embeddings gồm N vectors được chia thành P phần. Mỗi MPI process xử lý một phần dữ liệu. Với mỗi query, mọi process đều tính similarity trên shard cục bộ của mình, tạo local top-k, sau đó rank 0 merge các local top-k thành global top-k.

Có thể bổ sung task-level parallelism ở mức query batch, nhưng phần chính của report nên ghi rõ:

```text
Primary parallelism: data parallelism over memory vectors
Secondary optional parallelism: task parallelism over query batch
```

## 5.2. Kỹ thuật phân rã

Project sử dụng:

```text
Data decomposition
```

Cụ thể:

```text
1D block decomposition theo chiều N của ma trận embedding V kích thước N x D
```

Không chọn 2D decomposition vì nếu chia cả chiều D, mỗi process chỉ tính được một phần dot product. Sau đó hệ thống phải reduce partial scores giữa các process trước khi top-k, làm tăng communication và phức tạp thuật toán.

## 5.3. Mapping technique

Chọn mapping:

```text
1D contiguous block mapping
```

Với:

```text
N = số memory vectors
P = số MPI processes
rank = id của process, từ 0 đến P-1
```

Công thức chia đều:

```text
base = N / P
remainder = N % P

if rank < remainder:
    local_N = base + 1
    start = rank * local_N
else:
    local_N = base
    start = rank * base + remainder

end = start + local_N
```

Mỗi process chỉ xử lý các vector:

```text
V[start], V[start + 1], ..., V[end - 1]
```

## 5.4. Communication strategy

Project dùng communication pattern sau:

```text
1. Rank 0 đọc query batch hoặc sinh query batch.
2. Rank 0 broadcast query vector hoặc query batch cho tất cả ranks.
3. Mỗi rank tính local top-k trên shard của mình.
4. Mỗi rank gửi local top-k candidates về rank 0.
5. Rank 0 merge P local top-k lists thành global top-k.
6. Rank 0 ghi kết quả và benchmark metrics.
```

Communication primitives đề xuất:

```text
- MPI_Bcast: gửi query vector/query batch từ rank 0 tới mọi rank
- MPI_Gather hoặc MPI_Gatherv: thu local top-k candidates từ mọi rank
- MPI_Reduce hoặc MPI_Gather: thu timing metrics
```

## 5.5. Topology

Topology logic:

```text
Master-worker / star topology
```

Trong đó:

```text
Rank 0 = master/coordinator
Rank 1..P-1 = worker processes
```

Ghi chú: mặc dù logic là master-worker, các collective như MPI_Bcast có thể được MPI runtime tối ưu nội bộ thành tree-based communication. Trong report có thể viết:

```text
The logical topology is master-worker, while MPI collectives may internally use tree-based algorithms depending on the MPI implementation.
```

## 5.6. Blocking và non-blocking

Bản chính nên dùng blocking để dễ kiểm soát và debug:

```text
- MPI_Bcast
- MPI_Gather / MPI_Gatherv
```

Bản mở rộng nếu còn thời gian:

```text
- MPI_Isend / MPI_Irecv để gửi local top-k bất đồng bộ
- MPI_Ibcast để broadcast query batch bất đồng bộ
```

Trong report có thể nói:

```text
The main implementation uses blocking collective communication for correctness and reproducibility. Non-blocking communication is considered as an optimization to overlap communication with computation in future work or an optional experiment.
```

---

## 6. Mã giả thuật toán song song

```text
Input:
    V: memory embedding matrix with N vectors
    Q: query batch with num_queries vectors
    D: embedding dimension
    k: number of nearest memory records
    P: number of MPI processes

Output:
    Global top-k memory records for each query

Algorithm:

1. MPI_Init()
2. Get rank and world_size P
3. Rank 0 loads configuration
4. All ranks compute their local shard range using 1D block decomposition
5. Each rank loads or receives its local shard V_local
6. Rank 0 loads query batch Q

7. For each query q in Q:

    7.1 Start communication timer
    7.2 Rank 0 broadcasts q to all ranks using MPI_Bcast
    7.3 Stop communication timer

    7.4 Start compute timer
    7.5 Each rank initializes local min-heap H_local of size k
    7.6 For each vector v_i in V_local:
            score = dot(q, v_i)
            update H_local with (global_memory_id, score)
    7.7 Sort H_local by descending score
    7.8 Stop compute timer

    7.9 Start communication timer
    7.10 Each rank sends H_local to rank 0 using MPI_Gather/Gatherv
    7.11 Stop communication timer

    7.12 If rank == 0:
            Merge all local top-k lists
            Keep only global top-k items
            Save global result

8. Gather timing metrics from all ranks
9. Rank 0 writes benchmark CSV files
10. MPI_Finalize()
```

---

## 7. Kiểm tra correctness

### 7.1. Nguyên tắc

Vì thuật toán là exact search, kết quả song song phải giống kết quả tuần tự.

### 7.2. Cách kiểm tra

Với mỗi query:

```text
sequential_result = sequential_search(q, V, k)
parallel_result = parallel_search(q, V, k)
```

So sánh:

```text
- Top-k memory_id phải giống nhau
- Score sai khác không quá epsilon
- Thứ tự kết quả phải giống nhau sau khi áp dụng tie-break rule
```

Epsilon đề xuất:

```text
epsilon = 1e-5 hoặc 1e-4
```

### 7.3. Tie-break rule

Để tránh sai khác do các score bằng nhau, định nghĩa rule cố định:

```text
Nếu score_a > score_b: a đứng trước b
Nếu score_a == score_b: memory_id nhỏ hơn đứng trước
```

### 7.4. Output correctness CSV

File:

```text
results/correctness.csv
```

Schema:

```csv
query_id,k,matched,matched_ids,max_score_diff,status
0,10,true,10,0.000001,PASS
1,10,true,10,0.000002,PASS
```

---

## 8. Granularity và load balancing

### 8.1. Định nghĩa granularity

Vì project song song hóa dựa trên dữ liệu, granularity được định nghĩa là:

```text
Granularity = số memory vectors trên mỗi process
```

Với 1D block decomposition:

```text
granularity ≈ N / P
```

Nếu dùng block-cyclic hoặc dynamic block assignment:

```text
granularity = số memory vectors trên mỗi block nhỏ
```

### 8.2. Các timing cần đo

Mỗi process cần đo:

```text
compute_time_i
communication_time_i
total_time_i
active_time_i = compute_time_i + communication_time_i
idle_time_i = global_total_time - active_time_i
local_N_i
```

### 8.3. Công thức kiểm tra mất cân bằng tải

Với hai process bất kỳ a và b:

```text
idle_diff_ratio = abs(idle_time_a - idle_time_b) / max(idle_time_a, idle_time_b)
```

Nếu:

```text
idle_diff_ratio > 25%
```

thì xem là mất cân bằng tải theo yêu cầu đề.

### 8.4. Cách điều chỉnh nếu mất cân bằng

Nếu mất cân bằng tải, thử các phương án:

1. Chuyển từ 1D contiguous block sang block-cyclic decomposition.
2. Chia shard lớn thành nhiều block nhỏ hơn.
3. Dùng dynamic scheduling kiểu master cấp block cho worker.
4. Giảm kích thước block nếu workload không đều.
5. Tăng kích thước block nếu communication overhead quá lớn.

Tuy nhiên, với dense vector retrieval, mỗi vector có cùng dimension D nên chi phí dot product gần như bằng nhau. Vì vậy static 1D block decomposition thường đã cân bằng tốt.

---

## 9. Kế hoạch thực nghiệm

## 9.1. Thông số cố định ban đầu

Đề xuất cấu hình mặc định:

```text
D = 384 hoặc 768
k = 10
Q = 100, 500 hoặc 1000 queries
P = số nhân vật lý CPU khi chạy experiment chọn N và granularity
```

Ví dụ nếu có 3 máy, mỗi máy 4 nhân:

```text
P = 12 MPI processes
```

## 9.2. Experiment 1: chọn kích thước N

### Mục tiêu

Tìm kích thước dữ liệu N sao cho thời gian chạy toàn bộ chương trình khoảng 2-3 phút.

### Cách chạy

Giữ cố định:

```text
P = số nhân vật lý CPU
D = 384 hoặc 768
Q = cố định
k = 10
```

Thay đổi:

```text
N = 100,000
N = 200,000
N = 500,000
N = 1,000,000
N = 2,000,000
N = 5,000,000
```

### Output CSV

File:

```text
results/runtime_by_N.csv
```

Schema:

```csv
N,D,Q,k,P,compute_time,total_communication_time,total_time
100000,384,100,10,12,12.4,0.8,13.2
200000,384,100,10,12,24.8,1.1,25.9
```

### Biểu đồ

Vẽ biểu đồ:

```text
X-axis: N
Y-axis: runtime seconds
Line 1: compute-only time
Line 2: total time including communication
```

### Kết luận cần viết

Chọn N sao cho:

```text
120 seconds <= total_time <= 180 seconds
```

Nếu không đạt đúng khoảng này, chọn N gần nhất và giải thích theo giới hạn phần cứng.

---

## 9.3. Experiment 2: correctness

### Mục tiêu

Chứng minh chương trình song song trả về đúng lời giải của bài toán exact top-k retrieval.

### Cách chạy

Với input size đã chọn:

```text
N = N_selected
P = số nhân vật lý CPU
```

Chạy:

```text
1. sequential_retriever
2. parallel_retriever
3. verify_results
```

### Output

```text
results/sequential_topk.csv
results/parallel_topk.csv
results/correctness.csv
```

### Điều kiện pass

```text
- 100% query có top-k IDs giống nhau
- max_score_diff <= epsilon
```

---

## 9.4. Experiment 3: granularity/load balancing

### Mục tiêu

Kiểm tra tính mịn của bài toán và xác định hệ thống có cân bằng tải hay không.

### Cách chạy

Giữ cố định:

```text
N = N_selected
P = số nhân vật lý CPU
D = fixed
Q = fixed
k = fixed
```

Mỗi process xuất timing:

```text
rank, local_N, compute_time, communication_time, total_time, idle_time
```

### Output CSV

File:

```text
results/granularity.csv
```

Schema:

```csv
rank,local_N,compute_time,communication_time,active_time,global_total_time,idle_time
0,83334,35.2,1.8,37.0,37.5,0.5
1,83334,35.4,1.7,37.1,37.5,0.4
```

### Biểu đồ

Vẽ stacked bar chart:

```text
X-axis: process rank
Y-axis: time seconds
Bar segment 1: compute time
Bar segment 2: communication time
```

### Kết luận cần viết

Nếu idle time giữa hai process bất kỳ lệch không quá 25%:

```text
Hệ thống cân bằng tải tốt.
```

Nếu lệch quá 25%:

```text
Hệ thống chưa cân bằng tải. Cần điều chỉnh granularity bằng block-cyclic hoặc dynamic block assignment.
```

---

## 9.5. Experiment 4: speedup

### Mục tiêu

Đánh giá độ tăng tốc khi thay đổi số lượng processes.

### Cách chạy

Chọn input:

```text
N_speedup = 2 * N_selected
```

Thay đổi số process:

```text
P = 1, 2, 4, 8, ..., X, 2X
```

Trong đó:

```text
X = tổng số nhân vật lý CPU
```

Ví dụ nếu X = 12:

```text
P = 1, 2, 4, 8, 12, 24
```

### Output CSV

File:

```text
results/speedup.csv
```

Schema:

```csv
N,D,Q,k,P,compute_time,communication_time,total_time,compute_speedup,total_speedup,compute_efficiency,total_efficiency
2000000,384,100,10,1,240.0,0.0,240.0,1.00,1.00,1.00,1.00
2000000,384,100,10,2,122.0,2.0,124.0,1.97,1.94,0.98,0.97
```

### Công thức

```text
compute_speedup(P) = compute_time(1) / compute_time(P)
total_speedup(P) = total_time(1) / total_time(P)
compute_efficiency(P) = compute_speedup(P) / P
total_efficiency(P) = total_speedup(P) / P
```

### Biểu đồ

Cần vẽ ít nhất 2 biểu đồ:

```text
1. Runtime vs number of processes
   - Line 1: compute-only time
   - Line 2: total time including communication

2. Speedup vs number of processes
   - Line 1: compute-only speedup
   - Line 2: total speedup including communication
```

### Kết luận cần viết

Phân tích:

```text
- Khi P tăng, compute time giảm như thế nào?
- Communication overhead bắt đầu ảnh hưởng ở P nào?
- Khi dùng P = 2X có còn speedup tốt không?
- Có hiện tượng oversubscription khi P > số nhân vật lý không?
```

---

## 10. Cấu trúc codebase đề xuất

```text
parallel-agent-memory-retriever/
├── CMakeLists.txt
├── README.md
├── docs/
│   ├── development/
│   │   ├── project_specification.md
│   │   ├── data_pipeline_and_benchmarks.md
│   │   ├── developer_guide.md
│   │   ├── source_guide.md
│   │   └── parallel_agent_memory_retriever_plan.md
│   └── plans/
├── include/
│   ├── Config.hpp
│   ├── MemoryRecord.hpp
│   ├── VectorStore.hpp
│   ├── BinaryDataset.hpp
│   ├── TopKHeap.hpp
│   ├── SequentialRetriever.hpp
│   ├── ParallelRetriever.hpp
│   ├── MpiUtils.hpp
│   ├── Timer.hpp
│   ├── Metrics.hpp
│   └── CsvWriter.hpp
├── src/
│   ├── Config.cpp
│   ├── VectorStore.cpp
│   ├── BinaryDataset.cpp
│   ├── TopKHeap.cpp
│   ├── SequentialRetriever.cpp
│   ├── ParallelRetriever.cpp
│   ├── MpiUtils.cpp
│   ├── Timer.cpp
│   ├── Metrics.cpp
│   ├── CsvWriter.cpp
│   ├── main_sequential.cpp
│   ├── main_parallel.cpp
│   └── main_benchmark.cpp
├── tools/
│   ├── generate_vectors.cpp
│   ├── generate_queries.cpp
│   ├── verify_results.cpp
│   └── inspect_dataset.cpp
├── scripts/
│   ├── build.sh
│   ├── run_select_N.sh
│   ├── run_correctness.sh
│   ├── run_granularity.sh
│   ├── run_speedup.sh
│   ├── run_faiss_comparison.sh
│   ├── faiss_compare.py
│   ├── prepare_squad_minilm.py
│   └── plot_results.py
├── data/
│   ├── memory_vectors.bin
│   └── query_vectors.bin
├── .cache/
│   └── real_corpora/
│       └── squad_minilm/
│           ├── vectors.bin
│           ├── queries.bin
│           └── metadata.tsv
└── results/
    ├── runtime_by_N.csv
    ├── correctness.csv
    ├── granularity.csv
    ├── speedup.csv
    ├── faiss/
    │   ├── synthetic_topk.csv
    │   ├── synthetic_run_metrics.csv
    │   ├── synthetic_correctness.csv
    │   ├── squad_topk.csv
    │   ├── squad_run_metrics.csv
    │   ├── squad_correctness.csv
    │   └── comparison.csv
    └── figures/
```

---

## 11. Module design chi tiết

### 11.1. Config

Nhiệm vụ:

```text
- Parse command-line arguments
- Lưu N, D, Q, k, file paths, mode benchmark
```

CLI đề xuất:

```bash
./parallel_retriever \
  --vectors data/memory_vectors.bin \
  --queries data/query_vectors.bin \
  --N 1000000 \
  --D 384 \
  --Q 100 \
  --topk 10 \
  --output results/parallel_topk.csv
```

### 11.2. BinaryDataset

Nhiệm vụ:

```text
- Ghi vector dataset dạng binary
- Đọc vector dataset dạng binary
- Cho phép mỗi MPI rank đọc đúng shard của mình
```

Format đề xuất:

```text
Header:
    int64 num_vectors
    int32 dimension
Data:
    float vectors[num_vectors][dimension]
```

### 11.3. VectorStore

Nhiệm vụ:

```text
- Quản lý local vectors trong memory
- Trả về pointer tới vector thứ i
- Hỗ trợ normalize nếu cần
```

### 11.4. TopKHeap

Nhiệm vụ:

```text
- Duy trì min-heap kích thước k
- Insert candidate nếu score đủ lớn
- Sort kết quả giảm dần theo score
- Tie-break bằng memory_id
```

### 11.5. SequentialRetriever

Nhiệm vụ:

```text
- Scan toàn bộ vectors
- Tính dot product
- Trả về top-k chính xác
```

### 11.6. ParallelRetriever

Nhiệm vụ:

```text
- Nhận query từ rank 0
- Tính local top-k
- Gửi local top-k về rank 0
- Rank 0 merge global top-k
```

### 11.7. MpiUtils

Nhiệm vụ:

```text
- Wrapper cho MPI_Init/MPI_Finalize
- Broadcast vector
- Gather top-k candidates
- Gather metrics
- Error handling
```

### 11.8. Timer và Metrics

Nhiệm vụ:

```text
- Đo wall-clock time bằng MPI_Wtime hoặc std::chrono
- Tách compute_time và communication_time
- Tính active_time, idle_time, speedup, efficiency
```

---

## 12. Kế hoạch triển khai theo phase

## Phase 0 — Chốt đặc tả project

### Việc cần làm

```text
- Chốt tên project
- Chốt scope: exact top-k memory retrieval
- Chốt MPI là framework chính
- Chốt D, k, Q mặc định
- Chốt format binary dataset
- Chốt output CSV cần sinh
```

### Deliverables

```text
docs/development/project_specification.md
docs/development/data_pipeline_and_benchmarks.md
```

### Acceptance criteria

```text
- Có sơ đồ pipeline
- Có bảng trả lời yêu cầu đề
- Có định nghĩa input/output rõ ràng
```

---

## Phase 1 — Dựng codebase C++/MPI

### Việc cần làm

```text
- Tạo CMakeLists.txt
- Tạo include/src/tools/scripts/results
- Build được chương trình MPI tối thiểu
- Viết Config parser đơn giản
- Viết logging cơ bản
```

### Deliverables

```text
CMakeLists.txt
src/main_parallel.cpp
src/main_sequential.cpp
README.md bản đầu
```

### Acceptance criteria

```text
mpirun -np 4 ./parallel_retriever --help
```

Chạy được và in ra usage.

---

## Phase 2 — Dataset generator và loader

### Việc cần làm

```text
- Viết tool generate_vectors.cpp
- Viết tool generate_queries.cpp
- Viết BinaryDataset reader/writer
- Hỗ trợ đọc local shard theo rank
```

### Deliverables

```text
tools/generate_vectors.cpp
tools/generate_queries.cpp
include/BinaryDataset.hpp
src/BinaryDataset.cpp
```

### Acceptance criteria

```bash
./generate_vectors --N 100000 --D 384 --output data/memory_vectors.bin
./generate_queries --Q 100 --D 384 --output data/query_vectors.bin
./inspect_dataset --input data/memory_vectors.bin
```

Kết quả phải đọc đúng:

```text
num_vectors = 100000
dimension = 384
```

---

## Phase 3 — Sequential exact retrieval

### Việc cần làm

```text
- Viết dot product function
- Viết TopKHeap
- Viết SequentialRetriever
- Xuất top-k ra CSV
```

### Deliverables

```text
include/TopKHeap.hpp
src/TopKHeap.cpp
include/SequentialRetriever.hpp
src/SequentialRetriever.cpp
src/main_sequential.cpp
```

### Acceptance criteria

```bash
./sequential_retriever \
  --vectors data/memory_vectors.bin \
  --queries data/query_vectors.bin \
  --topk 10 \
  --output results/sequential_topk.csv
```

Output có đúng Q * k dòng kết quả.

---

## Phase 4 — MPI parallel retrieval bản blocking

### Việc cần làm

```text
- Mỗi rank xác định shard [start, end)
- Mỗi rank load local shard
- Rank 0 broadcast query
- Mỗi rank tính local top-k
- Gather local top-k về rank 0
- Rank 0 merge global top-k
- Xuất parallel_topk.csv
```

### Deliverables

```text
include/ParallelRetriever.hpp
src/ParallelRetriever.cpp
include/MpiUtils.hpp
src/MpiUtils.cpp
src/main_parallel.cpp
```

### Acceptance criteria

```bash
mpirun -np 4 ./parallel_retriever \
  --vectors data/memory_vectors.bin \
  --queries data/query_vectors.bin \
  --topk 10 \
  --output results/parallel_topk.csv
```

Chạy xong không lỗi, output có đúng Q * k dòng.

---

## Phase 5 — Correctness checker

### Việc cần làm

```text
- Đọc sequential_topk.csv
- Đọc parallel_topk.csv
- So sánh query_id, rank_in_topk, memory_id, score
- Tính max_score_diff
- Xuất correctness.csv
```

### Deliverables

```text
tools/verify_results.cpp
results/correctness.csv
```

### Acceptance criteria

```bash
./verify_results \
  --sequential results/sequential_topk.csv \
  --parallel results/parallel_topk.csv \
  --epsilon 1e-5 \
  --output results/correctness.csv
```

Kết quả:

```text
All queries PASS
```

---

## Phase 6 — Benchmark instrumentation

### Việc cần làm

```text
- Đo compute_time từng rank
- Đo communication_time từng rank
- Đo total_time
- Gather metrics về rank 0
- Xuất runtime_by_N.csv, granularity.csv, speedup.csv
```

### Deliverables

```text
include/Timer.hpp
src/Timer.cpp
include/Metrics.hpp
src/Metrics.cpp
include/CsvWriter.hpp
src/CsvWriter.cpp
```

### Acceptance criteria

Mỗi lần chạy sinh được CSV có các cột bắt buộc.

---

## Phase 7 — Experiment scripts

### Việc cần làm

```text
- Viết run_select_N.sh
- Viết run_correctness.sh
- Viết run_granularity.sh
- Viết run_speedup.sh
- Viết plot_results.py
```

### Deliverables

```text
scripts/run_select_N.sh
scripts/run_correctness.sh
scripts/run_granularity.sh
scripts/run_speedup.sh
scripts/plot_results.py
```

### Acceptance criteria

Chạy một command có thể sinh toàn bộ CSV và figure:

```bash
bash scripts/run_all_experiments.sh
```

---

## Phase 8 — FAISS external baseline comparison

### Việc cần làm

```text
- Viết scripts/faiss_compare.py để đọc vectors.bin và queries.bin theo binary contract hiện tại
- Dùng FAISS IndexFlatIP trên CPU với input normalized, row-major, float32
- Đo riêng build_time = IndexFlatIP.add(...) và compute_time = IndexFlatIP.search(...)
- Khóa total_time của FAISS trong Phase 8 bằng compute_time để không trộn cold-start index build vào canonical speed comparison
- Ghi top-k CSV của FAISS và run-metrics CSV của FAISS
- Tái sử dụng verify_results để so sánh sequential output với FAISS output trên synthetic dataset
- Viết scripts/prepare_squad_minilm.py để convert SQuAD thành vectors.bin, queries.bin, metadata.tsv
- Dùng sentence-transformers/all-MiniLM-L6-v2 làm embedding model cố định cho SQuAD path
- Chốt SQuAD path: unique context từ train split làm memory side, question từ validation split làm query side
- Chốt queries-limit mặc định = 100 và dimension mặc định = 384 cho real-corpus path
- Chốt thread policy: faiss.omp_set_num_threads(P_SELECTED) với P_SELECTED lấy từ benchmark manifest hiện tại
- Viết scripts/run_faiss_comparison.sh để orchestration sequential / parallel / FAISS và sinh comparison.csv
```

### Contract cần khóa

```text
- Synthetic path tái sử dụng nguyên binary format Phase 2; không tạo format vector thứ hai
- Correctness policy:
  * dùng lại verify_results
  * epsilon = 1e-5
  * FAISS phải match exact sequential output trên cùng vector input
- Fair timing policy:
  * không tính text loading, text embedding generation, binary file loading, CSV writing vào benchmark window
  * build_time = thời gian IndexFlatIP.add(...)
  * compute_time = thời gian IndexFlatIP.search(...)
  * total_time của FAISS trong Phase 8 = compute_time
- Run-metrics schema:
  * dataset_name,N,D,Q,k,threads,build_time,compute_time,total_time
- Comparison schema:
  * dataset_name,N,D,Q,k,parallel_workers,faiss_threads,parallel_compute_time,parallel_communication_time,parallel_total_time,faiss_build_time,faiss_compute_time,faiss_total_time,total_ratio,correctness_status,max_score_diff
- Phase 6-7 contracts không đổi:
  * speedup.csv vẫn dùng sequential baseline thật
  * runtime_by_N.csv và granularity.csv giữ nguyên nghĩa
  * FAISS comparison là experiment riêng
```

### Deliverables

```text
scripts/faiss_compare.py
scripts/prepare_squad_minilm.py
scripts/run_faiss_comparison.sh
results/faiss/synthetic_topk.csv
results/faiss/synthetic_run_metrics.csv
results/faiss/synthetic_correctness.csv
results/faiss/squad_topk.csv
results/faiss/squad_run_metrics.csv
results/faiss/squad_correctness.csv
results/faiss/comparison.csv
```

### Acceptance criteria

```bash
python3 scripts/faiss_compare.py \
  --vectors data/memory_vectors.bin \
  --queries data/query_vectors.bin \
  --topk 10 \
  --threads "$P_SELECTED" \
  --output-topk results/faiss/synthetic_topk.csv \
  --output-metrics results/faiss/synthetic_run_metrics.csv

./build/release/verify_results \
  --sequential results/sequential_topk.csv \
  --parallel results/faiss/synthetic_topk.csv \
  --epsilon 1e-5 \
  --output results/faiss/synthetic_correctness.csv

python3 scripts/prepare_squad_minilm.py \
  --input-dir /mnt/e/data/squad/plain_text \
  --output-dir .cache/real_corpora/squad_minilm \
  --model sentence-transformers/all-MiniLM-L6-v2 \
  --queries-limit 100

bash scripts/run_faiss_comparison.sh
```

Kết quả cần đạt:

```text
- Không còn reference dư về Phase 8 demo cũ trong master plan
- results/faiss/synthetic_correctness.csv phải PASS cho toàn bộ query
- SQuAD conversion sinh ra normalized binary datasets tương thích retriever hiện tại
- results/faiss/comparison.csv có đủ 2 row canonical: synthetic và squad_minilm
```

---

## Phase 9 — Report và final package

### Việc cần làm

```text
- Viết report 10-20 trang
- Chèn architecture diagram
- Chèn pseudocode
- Chèn biểu đồ runtime theo N
- Chèn biểu đồ granularity
- Chèn biểu đồ speedup
- Viết discussion về communication overhead và load balancing
```

### Deliverables

```text
report/report.pdf
README.md hoàn chỉnh
results/figures/*.png
```

### Acceptance criteria

Report trả lời đủ toàn bộ yêu cầu đề.

---

### Future work / appendix direction

```text
- metadata.tsv + memory_text demo cho qualitative retrieval
- CLI nhỏ để xem top-k memory text cho một query cụ thể
- Optional ghép retrieved context thành prompt cho LLM hoặc mock LLM
```

---

## 13. Dòng lệnh chạy benchmark và FAISS baseline

### Build

```bash
cd ~/work/Parallel-Retrieval-Engine-for-RAG
bash scripts/configure_release.sh
cmake --build build/release
```

### Generate synthetic dataset

```bash
./build/release/generate_vectors --N 1000000 --D 384 --output data/memory_vectors.bin
./build/release/generate_queries --Q 100 --D 384 --output data/query_vectors.bin
```

### Sequential baseline

```bash
./build/release/sequential_retriever \
  --vectors data/memory_vectors.bin \
  --queries data/query_vectors.bin \
  --topk 10 \
  --output results/sequential_topk.csv
```

### Parallel retrieval

```bash
mpirun -np 12 ./build/release/parallel_retriever \
  --vectors data/memory_vectors.bin \
  --queries data/query_vectors.bin \
  --topk 10 \
  --output results/parallel_topk.csv \
  --metrics results/granularity.csv \
  --run-metrics results/parallel_run_metrics.csv
```

### Verify correctness

```bash
./build/release/verify_results \
  --sequential results/sequential_topk.csv \
  --parallel results/parallel_topk.csv \
  --epsilon 1e-5 \
  --output results/correctness.csv
```

### Run speedup benchmark

```bash
bash scripts/run_speedup.sh
```

### Run FAISS synthetic comparison

```bash
python3 scripts/faiss_compare.py \
  --vectors data/memory_vectors.bin \
  --queries data/query_vectors.bin \
  --topk 10 \
  --threads 12 \
  --output-topk results/faiss/synthetic_topk.csv \
  --output-metrics results/faiss/synthetic_run_metrics.csv

./build/release/verify_results \
  --sequential results/sequential_topk.csv \
  --parallel results/faiss/synthetic_topk.csv \
  --epsilon 1e-5 \
  --output results/faiss/synthetic_correctness.csv
```

### Prepare SQuAD + MiniLM real-corpus dataset

```bash
python3 scripts/prepare_squad_minilm.py \
  --input-dir /mnt/e/data/squad/plain_text \
  --output-dir .cache/real_corpora/squad_minilm \
  --model sentence-transformers/all-MiniLM-L6-v2 \
  --queries-limit 100
```

### Run full FAISS comparison workflow

```bash
bash scripts/run_faiss_comparison.sh
```

---

## 14. Report outline 10-20 trang

Đề xuất cấu trúc report:

| Trang | Nội dung |
|---:|---|
| 1 | Introduction: AI Agent, long-term memory, retrieval bottleneck |
| 2 | Problem Definition: exact top-k vector retrieval |
| 3 | Sequential Baseline |
| 4 | Parallelization Level and Decomposition |
| 5 | Process Mapping: 1D block decomposition |
| 6 | Communication Strategy and Topology |
| 7 | Load Balancing and Granularity |
| 8 | Parallel Pseudocode |
| 9 | Implementation Details in C++/MPI |
| 10 | Correctness Verification Method |
| 11 | Experiment Setup |
| 12 | Runtime by Input Size and Selection of N |
| 13 | Granularity and Per-process Timing Results |
| 14 | Speedup Experiment Setup |
| 15 | Speedup Results |
| 16 | External Baseline with FAISS: fairness policy, exact-match correctness, and synthetic comparison |
| 17 | External Baseline with FAISS on SQuAD + MiniLM |
| 18 | Discussion: communication overhead, scalability, external-baseline interpretation, bottlenecks |
| 19 | Conclusion and Future Work |

Nếu cần gọn hơn, có thể gộp trang 14-15 hoặc 16-17 hoặc 18-19 để giữ trong 15 trang.

---

## 15. Checklist đánh giá theo yêu cầu đề

### 15.1. Checklist lý thuyết

```text
[ ] Nêu rõ song song cấp độ dữ liệu
[ ] Giải thích vì sao không chọn task-only parallelism
[ ] Nêu data decomposition
[ ] Giải thích 1D block decomposition
[ ] Nêu công thức mapping start/end cho mỗi rank
[ ] Giải thích communication bằng MPI_Bcast và MPI_Gather
[ ] Nêu topology master-worker/star
[ ] Nêu blocking communication là bản chính
[ ] Nêu non-blocking là optional optimization
[ ] Nêu load balancing strategy
[ ] Có mã giả thuật toán song song
```

### 15.2. Checklist code

```text
[ ] Code C++ >= 1000 dòng
[ ] Build bằng CMake
[ ] Có MPI
[ ] Có sequential retriever
[ ] Có parallel retriever
[ ] Có top-k heap tự code
[ ] Có binary dataset loader
[ ] Có correctness checker
[ ] Có benchmark CSV export
[ ] Có scripts chạy experiment
```

### 15.3. Checklist kết quả

```text
[ ] Có biểu đồ runtime theo N
[ ] Có 2 đường: compute-only và total including communication
[ ] Chọn được N để runtime khoảng 2-3 phút
[ ] Có biểu đồ granularity theo từng process
[ ] Mỗi process có compute time và communication time chung một cột stacked
[ ] Có kết luận load balance có/không
[ ] Có speedup với input 2N
[ ] Có P = 1,2,4,8,...,X,2X
[ ] Có runtime chart theo P
[ ] Có speedup chart theo P
[ ] Có correctness result PASS
```

---

## 16. Rủi ro và cách xử lý

| Rủi ro | Nguyên nhân | Cách xử lý |
|---|---|---|
| Runtime không đạt 2-3 phút | N hoặc Q quá nhỏ | Tăng N hoặc Q |
| Runtime quá lâu | N quá lớn | Giảm N hoặc Q |
| Parallel không nhanh hơn nhiều | Communication overhead hoặc memory bandwidth bottleneck | Tăng N, tăng Q, dùng query batch |
| Kết quả parallel lệch sequential | Floating-point tie hoặc merge sai | Thêm tie-break rule, dùng epsilon |
| FAISS không match exact output | Input không normalized hoặc output ordering khác | Giữ float32 normalized row-major và tái dùng verify_results với deterministic tie-break |
| FAISS comparison không công bằng | Trộn text embedding hoặc binary load vào benchmark window | Chốt fairness policy: build/search riêng, loại text preprocessing, dataset load, CSV writing khỏi timing chính |
| Load imbalance | Chia dữ liệu không đều hoặc I/O không đều | Dùng balanced block formula hoặc block-cyclic |
| MPI gather local top-k phức tạp | Struct gửi qua MPI khó debug | Pack candidate thành array float/int đơn giản |
| SQuAD preprocessing quá nặng hoặc khó tái lập | Dependency Python/embedding model chưa khóa | Chốt all-MiniLM-L6-v2, queries-limit mặc định 100, và workflow WSL-first qua prepare_squad_minilm.py |
| Code không đủ 1000 dòng | Scope quá nhỏ | Bổ sung baseline scripts, real-corpus conversion, comparison.csv, và doc/report analysis layer |
| Report bị hỏi RAG ở đâu | Retrieval không gắn với hệ sinh thái thực tế | Nhấn mạnh project tập trung retrieval kernel và có external FAISS baseline thay vì full agent demo |

---

## 17. Quyết định thiết kế cuối cùng

Các quyết định nên ghi cố định trong report:

```text
1. Project không xây full AI Agent, chỉ xây một module memory retrieval.
2. Retrieval dùng exact top-k search để dễ kiểm tra correctness.
3. Song song hóa chính là data parallelism.
4. Phân rã dữ liệu theo 1D block decomposition trên số memory vectors N.
5. Mỗi MPI process giữ một shard của memory database.
6. Rank 0 broadcast query, các rank tính local top-k, rank 0 gather và merge global top-k.
7. Bản chính dùng blocking MPI collectives để dễ tái lập kết quả.
8. Load balancing được kiểm tra bằng per-rank compute/communication/idle time.
9. Speedup được đo bằng cả compute-only time và total time including communication.
10. FAISS exact flat CPU được dùng làm external baseline, không phải lõi implementation.
11. Phase 8 benchmark lại trên synthetic benchmark và một real corpus đã convert là SQuAD + all-MiniLM-L6-v2.
12. FAISS comparison không thay thế sequential baseline trong speedup.csv; nó là experiment riêng để đối chiếu với một thư viện thực tế.
13. Demo metadata/memory_text nếu có chỉ nên để ở future work hoặc appendix, không còn là numbered phase chính.
```

---

## 18. Kết luận kế hoạch

Project này phù hợp với yêu cầu đề vì có bài toán tính toán lớn, song song hóa rõ ràng, communication đo được, correctness kiểm tra được, speedup biểu diễn được bằng thực nghiệm, và còn có external baseline với FAISS để đối chiếu với một thư viện retrieval thực tế mà không làm loãng phần parallel computing cốt lõi.

Câu mô tả ngắn nên dùng khi trình bày với giảng viên:

> Em xây dựng một module truy hồi bộ nhớ dài hạn cho AI Agent bằng C++ và MPI. Module này thực hiện exact top-k vector retrieval trên tập memory embeddings lớn. Em song song hóa theo dữ liệu bằng cách chia memory database thành nhiều shard cho các MPI processes. Mỗi process tính local top-k trên shard của mình, sau đó rank 0 thu thập và merge thành global top-k. Project sẽ đánh giá correctness bằng sequential exact baseline, chọn N để runtime đạt khoảng 2-3 phút, kiểm tra granularity/load balancing bằng biểu đồ compute/communication time từng process, đo speedup khi thay đổi số lượng processes, và so sánh thêm với FAISS exact flat như một external baseline trên synthetic benchmark và một real corpus đã convert.

