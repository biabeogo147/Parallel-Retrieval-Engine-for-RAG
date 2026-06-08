# Phase 1: Codebase Setup for Parallel Retrieval Engine

## Project: Parallel Retrieval Engine for RAG in C/C++

Phase 1 là phase dựng nền codebase C/C++ cho project.  
Mục tiêu của phase này không phải là cài thuật toán retrieval hoàn chỉnh, mà là tạo một bộ khung sạch, dễ mở rộng, dễ build, dễ test, và sẵn sàng cho các phase sau.

---

## 1. Mục tiêu chính của Phase 1

Sau Phase 1, project cần có nền tảng như sau:

```text
- Build được bằng CMake
- Có cấu trúc thư mục rõ ràng
- Có các module placeholder cho vector store, retrieval, top-k, benchmark
- Có OpenMP setup thành công
- Có CLI đơn giản
- Có demo chạy được
- Có README hướng dẫn build/run
```

Phase này chưa cần:

```text
- Retrieval thật
- Embedding thật
- RAG end-to-end thật
- Benchmark performance thật
```

Nhưng cần có đủ bộ khung để sau này chỉ việc cài thêm logic vào từng module.

---

## 2. Vai trò của Phase 1

Phase 1 nên được hiểu là:

> Dựng bộ khung C/C++ project đủ sạch để các phase sau chỉ việc “cắm module vào”, không phải sửa lung tung lại codebase.

Nếu Phase 1 làm tốt, các phase sau sẽ dễ phát triển hơn:

```text
Phase 2: Thêm data preparation và chunking
Phase 3: Thêm embedding loader
Phase 4: Thêm serial retrieval
Phase 5: Thêm parallel retrieval
Phase 6: Thêm benchmark
Phase 7: Tích hợp RAG demo
```

---

## 3. Cấu trúc thư mục đề xuất

Cấu trúc project:

```text
rag-parallel-cpp/
├── CMakeLists.txt
├── README.md
├── .gitignore
│
├── include/
│   ├── vector_store.h
│   ├── retrieval.h
│   ├── topk.h
│   ├── benchmark.h
│   ├── config.h
│   └── utils.h
│
├── src/
│   ├── main.cpp
│   ├── vector_store.cpp
│   ├── retrieval_serial.cpp
│   ├── retrieval_parallel.cpp
│   ├── topk.cpp
│   ├── benchmark.cpp
│   └── utils.cpp
│
├── app/
│   ├── rag_demo.cpp
│   ├── search_serial.cpp
│   ├── search_parallel.cpp
│   └── benchmark_app.cpp
│
├── scripts/
│   ├── prepare_chunks.py
│   ├── generate_embeddings.py
│   └── convert_embeddings.py
│
├── data/
│   ├── raw/
│   ├── processed/
│   ├── embeddings/
│   └── queries/
│
├── results/
│   ├── benchmark_results.csv
│   └── logs/
│
├── docs/
│   ├── phase0_scope.md
│   ├── phase1_codebase.md
│   └── architecture.md
│
└── tests/
    ├── test_vector_store.cpp
    ├── test_topk.cpp
    └── test_retrieval.cpp
```

---

## 4. Giải thích từng thư mục

### 4.1. `include/`

Chứa các header file.

Ví dụ:

```text
vector_store.h
retrieval.h
topk.h
benchmark.h
```

Mục đích:

```text
- Định nghĩa interface
- Giúp module tách biệt
- Giúp app không cần biết chi tiết implementation
```

Ví dụ sau này `retrieval.h` có thể expose:

```cpp
std::vector<SearchResult> search_serial(...);
std::vector<SearchResult> search_parallel(...);
```

---

### 4.2. `src/`

Chứa implementation chính.

Ví dụ:

```text
vector_store.cpp
retrieval_serial.cpp
retrieval_parallel.cpp
topk.cpp
benchmark.cpp
```

Mục đích:

```text
- Code lõi nằm ở đây
- Không trộn code lõi với demo app
- Dễ test từng module
- Dễ tái sử dụng ở nhiều executable khác nhau
```

---

### 4.3. `app/`

Chứa các executable khác nhau.

Ví dụ:

```text
search_serial.cpp
search_parallel.cpp
benchmark_app.cpp
rag_demo.cpp
```

Mục đích:

```text
- Mỗi app phục vụ một mục tiêu riêng
- Dễ chạy demo
- Dễ benchmark
```

Sau này có thể build ra:

```text
search_serial
search_parallel
benchmark
rag_demo
```

---

### 4.4. `scripts/`

Chứa script phụ trợ, chủ yếu bằng Python.

Ví dụ:

```text
prepare_chunks.py
generate_embeddings.py
convert_embeddings.py
```

Mục đích:

```text
- Chuẩn bị dữ liệu
- Gọi Embedding API
- Convert dữ liệu sang format C++ đọc được
```

Vì project dùng API cho embedding và LLM, phần script nên dùng Python để phát triển nhanh hơn.

---

### 4.5. `data/`

Chứa dữ liệu.

```text
raw/          dữ liệu gốc
processed/    chunks.jsonl, metadata.jsonl
embeddings/   embeddings.bin
queries/      queries.bin
```

Không nên commit file dữ liệu lớn lên Git.

---

### 4.6. `results/`

Chứa output benchmark.

```text
benchmark_results.csv
logs/
```

Mục đích:

```text
- Lưu kết quả đo latency
- Lưu bảng speedup
- Lưu log demo
```

---

### 4.7. `tests/`

Chứa test cho từng module.

Ở Phase 1, test chưa cần phức tạp.  
Nhưng nên có skeleton từ đầu để sau này kiểm tra correctness dễ hơn.

---

## 5. Các module cần tạo ở Phase 1

## 5.1. `VectorStore`

Module này quản lý vector embeddings trong RAM.

Phase 1 chưa cần load file thật, nhưng nên định nghĩa interface.

Vai trò:

```text
- Lưu num_vectors
- Lưu dimension
- Lưu mảng vector
- Cung cấp hàm access vector theo index
```

Interface dự kiến:

```cpp
class VectorStore {
public:
    bool load_from_binary(const std::string& path);

    int num_vectors() const;
    int dimension() const;

    const float* get_vector(int index) const;

private:
    int num_vectors_;
    int dimension_;
    std::vector<float> vectors_;
};
```

### Vì sao cần?

Retrieval engine không nên tự quản lý file hay format dữ liệu.  
Nó chỉ cần nhận `VectorStore` và search.

---

## 5.2. `SearchResult`

Nên có struct chung cho kết quả search.

```cpp
struct SearchResult {
    int vector_id;
    float score;
};
```

### Vì sao cần?

Serial retrieval, parallel retrieval, top-k merge và benchmark đều cần dùng cùng một kiểu kết quả.

---

## 5.3. `retrieval_serial`

Module này dành cho bản tuần tự.

Phase 1 chỉ cần placeholder.

Interface dự kiến:

```cpp
std::vector<SearchResult> search_serial(
    const VectorStore& store,
    const std::vector<float>& query,
    int top_k
);
```

### Vì sao cần?

Bản serial sẽ là baseline cho mọi so sánh sau này.

---

## 5.4. `retrieval_parallel`

Module này dành cho bản song song.

Interface dự kiến:

```cpp
std::vector<SearchResult> search_parallel(
    const VectorStore& store,
    const std::vector<float>& query,
    int top_k,
    int num_threads
);
```

### Vì sao cần?

Đây là module chính của project.  
Phase 1 chỉ cần dựng chỗ để sau này cài thuật toán vào.

---

## 5.5. `topk`

Module này xử lý chọn top-k.

Interface dự kiến:

```cpp
void update_topk(
    std::vector<SearchResult>& topk,
    SearchResult candidate,
    int k
);

std::vector<SearchResult> merge_topk(
    const std::vector<std::vector<SearchResult>>& local_topks,
    int k
);
```

### Vì sao cần?

Top-k là phần rất quan trọng trong parallel retrieval.

Thiết kế sau này:

```text
Mỗi thread có local top-k
→ cuối cùng gọi merge_topk
→ ra global top-k
```

---

## 5.6. `benchmark`

Module này đo thời gian.

Interface dự kiến:

```cpp
class Timer {
public:
    void start();
    double stop_ms();
};
```

Hoặc đơn giản hơn:

```cpp
double measure_latency_ms(std::function<void()> fn);
```

### Vì sao cần?

Parallel computing project bắt buộc phải có benchmark rõ ràng.  
Từ Phase 1 nên có timer sẵn để Phase 4, Phase 5 và Phase 6 dùng luôn.

---

## 5.7. `config`

Module này lưu config chung.

Ví dụ:

```cpp
struct SearchConfig {
    int top_k = 5;
    int num_threads = 1;
    std::string vector_path;
    std::string query_path;
};
```

### Vì sao cần?

Tránh việc mỗi app tự parse biến riêng lẻ một cách lộn xộn.

---

## 6. Build system với CMake

Nên dùng CMake vì:

```text
- Dễ build nhiều executable
- Dễ bật OpenMP
- Dễ chạy trên Linux, macOS, Windows/WSL
- Dễ quản lý include/src/app
```

Phase 1 cần CMake làm được:

```text
- Build library core
- Build app demo
- Link OpenMP
- Bật C++17 hoặc C++20
```

Target đề xuất:

```text
rag_core          static library
rag_demo          executable
search_serial     executable
search_parallel   executable
benchmark_app     executable
```

Tư duy build:

```text
src/*.cpp → rag_core
app/*.cpp → executable
executable link với rag_core
```

---

## 7. OpenMP setup trong Phase 1

Phase 1 cần kiểm tra được OpenMP chạy thật.

Chưa cần parallel retrieval, chỉ cần demo nhỏ:

```cpp
#pragma omp parallel
{
    int tid = omp_get_thread_num();
    int nthreads = omp_get_num_threads();

    #pragma omp critical
    {
        std::cout << "Hello from thread "
                  << tid << " / " << nthreads << std::endl;
    }
}
```

Mục tiêu:

```text
- Compiler nhận OpenMP
- Program chạy nhiều thread
- CMake link OpenMP thành công
```

Demo mong muốn:

```text
OpenMP enabled.
Hello from thread 0 / 8
Hello from thread 1 / 8
Hello from thread 2 / 8
...
```

---

## 8. CLI tối thiểu cần có

Ngay từ Phase 1 nên có CLI đơn giản.

Ví dụ:

```bash
./rag_demo --help
```

Output:

```text
Parallel Retrieval Engine for RAG

Options:
  --vectors <path>      Path to embeddings.bin
  --query <path>        Path to query.bin
  --topk <int>          Number of results
  --threads <int>       Number of OpenMP threads
  --mode <string>       serial | parallel | benchmark
```

Phase 1 chưa cần tất cả option chạy thật, nhưng nên parse được.

Ví dụ:

```bash
./rag_demo --mode info --threads 8
```

Output:

```text
Mode: info
Threads: 8
OpenMP: enabled
Project initialized successfully.
```

---

## 9. Demo tối thiểu của Phase 1

### Demo 1: Build thành công

```bash
mkdir build
cd build
cmake ..
make
```

Hoặc:

```bash
cmake -S . -B build
cmake --build build --config Release
```

---

### Demo 2: Chạy app info

```bash
./rag_demo --mode info
```

Output mong muốn:

```text
Parallel Retrieval Engine for RAG
Build: Debug
OpenMP: enabled
Project initialized successfully.
```

---

### Demo 3: Chạy OpenMP test

```bash
./rag_demo --mode omp_test --threads 4
```

Output mong muốn:

```text
Running OpenMP test with 4 threads.

Hello from thread 0 / 4
Hello from thread 1 / 4
Hello from thread 2 / 4
Hello from thread 3 / 4
```

---

### Demo 4: Chạy dummy retrieval

Có thể tạo vector giả trong code:

```text
vectors:
v0 = [1, 0, 0]
v1 = [0, 1, 0]
v2 = [0, 0, 1]

query = [1, 0, 0]
```

Kết quả mong muốn:

```text
Top-1 result:
vector_id = 0
score = 1.0
```

Ở Phase 1, dummy retrieval chỉ để test flow.  
Retrieval thật sẽ làm ở Phase 4 và Phase 5.

---

## 10. Coding convention nên chốt ngay

## 10.1. C++ standard

Dùng:

```text
C++17
```

Lý do:

```text
- Đủ hiện đại
- Compiler hỗ trợ tốt
- Không cần C++20 nếu project chưa cần
```

---

## 10.2. Naming convention

Gợi ý:

```text
ClassName
function_name
variable_name
CONSTANT_NAME
```

Ví dụ:

```cpp
class VectorStore;
float compute_dot_product(...);
int num_vectors;
```

---

## 10.3. Error handling

Không nên để lỗi im lặng.

Ví dụ khi load file thất bại:

```text
Error: failed to open embeddings file: data/embeddings.bin
```

Khi dimension không khớp:

```text
Error: query dimension 384 does not match vector dimension 768
```

---

## 10.4. Logging đơn giản

Phase 1 chưa cần thư viện logging.

Chỉ cần:

```cpp
std::cout << "[INFO] Loaded vectors." << std::endl;
std::cerr << "[ERROR] Failed to open file." << std::endl;
```

---

## 11. Git và `.gitignore`

Nên khởi tạo Git từ Phase 1.

`.gitignore` nên loại:

```text
build/
*.o
*.exe
*.out
*.bin
*.csv
__pycache__/
.env
data/raw/
data/embeddings/
results/
```

Lý do:

```text
- Không commit file build
- Không commit file embedding lớn
- Không commit API key
- Không commit dataset nặng
```

Nên commit:

```text
- Source code
- Header file
- CMakeLists.txt
- README
- Docs
- Script nhỏ
```

Không nên commit:

```text
- embeddings.bin
- API key
- dataset lớn
- benchmark output quá nặng
```

---

## 12. README tối thiểu cho Phase 1

README cần có ít nhất:

```text
# Parallel Retrieval Engine for RAG in C/C++

## Requirements
- C++17 compiler
- CMake >= 3.16
- OpenMP

## Build
mkdir build
cd build
cmake ..
cmake --build .

## Run
./rag_demo --mode info
./rag_demo --mode omp_test --threads 4

## Project Structure
Giải thích ngắn các thư mục.

## Current Phase
Phase 1: Codebase setup.
```

---

## 13. Phase 1 chưa cần làm gì?

Để tránh quá scope, Phase 1 chưa cần:

```text
- Load embeddings.bin thật
- Gọi Embedding API
- Gọi LLM API
- Implement retrieval tối ưu
- Benchmark nhiều thread thật
- Làm RAG end-to-end
- Làm FAISS baseline
- Làm UI
```

Nếu làm quá nhiều ở Phase 1, project sẽ dễ bị rối.

---

## 14. Acceptance Criteria cho Phase 1

Phase 1 được coi là hoàn thành khi đạt đủ các điều kiện sau:

### 14.1. Codebase

```text
- Có cấu trúc thư mục rõ ràng
- Có CMakeLists.txt
- Có README.md
- Có .gitignore
```

### 14.2. Build

```text
- Build được project bằng CMake
- Có ít nhất một executable chạy được
- Dùng C++17
- Link được OpenMP
```

### 14.3. Module skeleton

```text
- vector_store.h/.cpp
- retrieval.h
- retrieval_serial.cpp
- retrieval_parallel.cpp
- topk.h/.cpp
- benchmark.h/.cpp
```

### 14.4. CLI

```text
- Chạy được ./rag_demo --mode info
- Chạy được ./rag_demo --mode omp_test --threads N
```

### 14.5. OpenMP

```text
- In được số thread
- Chứng minh chương trình chạy multi-thread
```

### 14.6. Dummy demo

```text
- Có thể chạy một dummy search nhỏ
- Trả về kết quả top-k giả hoặc hard-coded
```

### 14.7. Documentation

```text
- README có hướng dẫn build/run
- docs/phase1_codebase.md mô tả cấu trúc project
```

---

## 15. Output cuối Phase 1

Cuối Phase 1, repo nên đạt trạng thái:

```text
Build được.
Chạy được.
OpenMP hoạt động.
Module skeleton đã sẵn sàng.
Có CLI cơ bản.
Có README.
```

Command demo cuối Phase 1:

```bash
cmake -S . -B build
cmake --build build

./build/rag_demo --mode info
./build/rag_demo --mode omp_test --threads 4
./build/rag_demo --mode dummy_search
```

Output kỳ vọng:

```text
Parallel Retrieval Engine for RAG
OpenMP: enabled
Project initialized successfully.

Running OpenMP test with 4 threads.
Hello from thread 0 / 4
Hello from thread 1 / 4
Hello from thread 2 / 4
Hello from thread 3 / 4

Running dummy search.
Top-1 result: vector_id = 0, score = 1.0
```

---

## 16. Kết luận Phase 1

Phase 1 không phải để làm thuật toán khó.  
Phase 1 là để đảm bảo project có một cái khung chuẩn:

```text
CMake + C++17 + OpenMP + module skeleton + CLI + README
```

Sau Phase 1, project sẽ sẵn sàng bước sang Phase 2:

```text
Data preparation và chunking
```

Và các phase sau sẽ không phải sửa lại nền móng nữa.
