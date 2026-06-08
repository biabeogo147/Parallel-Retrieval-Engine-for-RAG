# Phase 2: Data Preparation & Chunking

## Project: Parallel Retrieval Engine for RAG in C/C++

Phase 2 là phase chuẩn bị dữ liệu và chunking.  
Mục tiêu là biến dataset thô thành một corpus chuẩn, sạch, có ID rõ ràng, có metadata đầy đủ và sẵn sàng để gọi Embedding API ở Phase 3.

---

## 1. Mục tiêu chính của Phase 2

Sau Phase 2, project cần có:

```text
- Dataset thô đã được tải / đặt vào data/raw/
- Script đọc dataset
- Script chuẩn hóa document
- Script chia document thành chunks
- File chunks.jsonl
- File metadata.jsonl
- File corpus_stats.json
```

Output quan trọng nhất:

```text
data/processed/chunks.jsonl
data/processed/metadata.jsonl
data/processed/corpus_stats.json
```

Trong đó:

```text
chunks.jsonl      → dùng để gọi Embedding API ở Phase 3
metadata.jsonl    → dùng để map vector_id với text/source
corpus_stats.json → thống kê corpus để report
```

Phase này chưa làm:

```text
- Embedding
- Vector search
- Retrieval
- Benchmark
- RAG end-to-end
```

---

## 2. Vai trò của Phase 2 trong toàn project

Pipeline tổng thể:

```text
Raw documents
→ Chunking
→ Embedding
→ Vector storage
→ Retrieval
→ RAG answer
```

Phase 2 nằm ở đoạn:

```text
Raw documents
→ Chunking
```

Nếu Phase 2 làm không tốt, các phase sau sẽ bị ảnh hưởng:

```text
Chunk quá dài    → embedding kém, context khó dùng
Chunk quá ngắn   → mất ngữ nghĩa
ID không rõ      → không map được retrieval result về text
Metadata thiếu   → demo RAG khó giải thích
Corpus quá nhỏ   → benchmark parallel không rõ speedup
```

---

## 3. Input và output của Phase 2

## 3.1. Input

Input là dataset thô.

Ví dụ:

```text
data/raw/
├── squad/
├── viquad/
├── msmarco_sample/
└── scifact/
```

Mỗi dataset có format khác nhau:

```text
SQuAD       → JSON
ViQuAD      → JSON
MS MARCO    → TSV / JSONL
SciFact     → JSONL
Wikipedia   → text / JSON / parquet
```

Phase 2 cần convert tất cả về một format chuẩn nội bộ.

---

## 3.2. Output chuẩn

Output nên là JSONL, tức là mỗi dòng là một JSON object.

Ví dụ `chunks.jsonl`:

```json
{"chunk_id":"doc_000001_chunk_000","doc_id":"doc_000001","text":"Parallel computing is a type of computation...","source":"squad","start_char":0,"end_char":512}
{"chunk_id":"doc_000001_chunk_001","doc_id":"doc_000001","text":"There are several forms of parallelism...","source":"squad","start_char":400,"end_char":920}
```

Ví dụ `metadata.jsonl`:

```json
{"vector_id":0,"chunk_id":"doc_000001_chunk_000","doc_id":"doc_000001","source":"squad","text":"Parallel computing is a type of computation..."}
{"vector_id":1,"chunk_id":"doc_000001_chunk_001","doc_id":"doc_000001","source":"squad","text":"There are several forms of parallelism..."}
```

Ở Phase 2 chưa có vector thật, nhưng nên gán trước `vector_id` theo thứ tự chunk.

---

## 4. Format document chuẩn nội bộ

Trước khi chunking, nên convert mọi dataset về dạng document chuẩn:

```json
{
  "doc_id": "doc_000001",
  "title": "Parallel Computing",
  "text": "Full document text here...",
  "source": "squad",
  "metadata": {
    "original_id": "abc123",
    "url": "",
    "split": "train"
  }
}
```

Lý do cần format chuẩn:

```text
- Dataset nào cũng xử lý giống nhau sau bước convert
- Chunking script không cần biết dataset gốc là SQuAD, ViQuAD hay MS MARCO
- Dễ thêm dataset mới
```

Nên có file trung gian:

```text
data/processed/documents.jsonl
```

Pipeline Phase 2 nên là:

```text
raw dataset
→ documents.jsonl
→ chunks.jsonl
→ metadata.jsonl
→ corpus_stats.json
```

---

## 5. Các bước cụ thể trong Phase 2

## Step 1 — Tải hoặc đặt dataset vào `data/raw/`

Ví dụ:

```text
data/raw/squad/
data/raw/viquad/
data/raw/msmarco_sample/
```

Ở bước này chưa xử lý gì nhiều, chỉ cần đảm bảo dataset nằm đúng chỗ.

Kết quả cần có:

```text
data/raw/<dataset_name>/...
```

---

## Step 2 — Viết dataset converter

Mỗi dataset có thể cần một converter riêng.

Ví dụ:

```text
scripts/convert_squad.py
scripts/convert_viquad.py
scripts/convert_msmarco.py
scripts/convert_scifact.py
```

Mục tiêu của converter:

```text
Dataset gốc → documents.jsonl
```

Ví dụ command:

```bash
python scripts/convert_squad.py \
  --input data/raw/squad/train-v1.1.json \
  --output data/processed/documents.jsonl
```

Output mong muốn:

```text
Loaded 536 articles.
Generated 18896 documents.
Saved to data/processed/documents.jsonl.
```

---

## Step 3 — Làm sạch text cơ bản

Nên làm cleaning nhẹ, không quá phức tạp.

Các bước cleaning nên có:

```text
- Strip khoảng trắng đầu/cuối
- Normalize nhiều khoảng trắng liên tiếp thành một dấu cách
- Bỏ document rỗng
- Bỏ document quá ngắn
- Giữ nguyên tiếng Việt có dấu
- Giữ nguyên punctuation
```

Không nên cleaning quá mạnh:

```text
- Không xóa dấu tiếng Việt
- Không lowercase toàn bộ nếu không cần
- Không xóa toàn bộ punctuation
- Không stemming/lemmatization
```

Lý do:

```text
Embedding model cần ngữ cảnh tự nhiên.
Cleaning quá mạnh có thể làm text mất nghĩa.
```

---

## Step 4 — Chunking

Đây là bước chính của Phase 2.

Bạn cần chia document dài thành các chunk nhỏ.

### 4.1. Chunk size đề xuất

Vì bạn dùng Embedding API, chunk size nên vừa phải.

Gợi ý ban đầu:

```text
chunk_size_chars = 800 đến 1200 ký tự
chunk_overlap_chars = 100 đến 200 ký tự
```

Hoặc theo word:

```text
chunk_size_words = 150 đến 250 words
chunk_overlap_words = 30 đến 50 words
```

Với tiếng Việt, nếu chưa dùng tokenizer tốt, dùng character-based chunking sẽ đơn giản hơn.

Khuyến nghị cho project:

```text
Phase 2 bản đầu:
- Dùng paragraph-aware character chunking
- chunk_size = 1000 chars
- overlap = 150 chars
```

---

## 6. Các chiến lược chunking

## 6.1. Fixed-size character chunking

Cách đơn giản nhất:

```text
Cứ mỗi 1000 ký tự tạo một chunk
Overlap 150 ký tự giữa hai chunk liên tiếp
```

Ví dụ:

```text
Chunk 0: char 0    → 1000
Chunk 1: char 850  → 1850
Chunk 2: char 1700 → 2700
```

Ưu điểm:

```text
- Dễ code
- Ổn định
- Không cần tokenizer
- Hợp với tiếng Việt và tiếng Anh
```

Nhược điểm:

```text
- Có thể cắt ngang câu
- Chunk đôi khi không tự nhiên
```

---

## 6.2. Paragraph-aware chunking

Cách tốt hơn:

```text
- Tách document thành paragraph
- Gom nhiều paragraph lại cho đến khi gần chunk_size
- Nếu vượt quá chunk_size thì tạo chunk mới
- Có overlap nhẹ giữa các chunk
```

Ưu điểm:

```text
- Chunk tự nhiên hơn
- Ít cắt ngang ý
- RAG answer tốt hơn
```

Nhược điểm:

```text
- Code phức tạp hơn fixed-size một chút
```

Khuyến nghị:

> Nên dùng paragraph-aware chunking làm bản chính.

---

## 6.3. Sentence-aware chunking

Tách theo câu rồi gom câu lại.

Ưu điểm:

```text
- Chunk rất tự nhiên
- Ít mất nghĩa
```

Nhược điểm:

```text
- Cần sentence splitter tốt
- Với tiếng Việt có thể cần thư viện ngoài
- Không cần thiết ở bản đầu
```

Khuyến nghị:

```text
Để sau, không cần Phase 2 bản đầu.
```

---

## 7. Chunk schema nên dùng

Mỗi chunk nên có các field:

```json
{
  "chunk_id": "doc_000001_chunk_000",
  "doc_id": "doc_000001",
  "chunk_index": 0,
  "text": "Chunk text here...",
  "source": "squad",
  "title": "Document title",
  "start_char": 0,
  "end_char": 1000
}
```

Giải thích:

| Field | Ý nghĩa |
|---|---|
| `chunk_id` | ID duy nhất của chunk |
| `doc_id` | ID của document gốc |
| `chunk_index` | Thứ tự chunk trong document |
| `text` | Nội dung chunk |
| `source` | Dataset nguồn |
| `title` | Tiêu đề nếu có |
| `start_char` | Vị trí bắt đầu trong document |
| `end_char` | Vị trí kết thúc trong document |

---

## 8. ID convention

Nên dùng ID ổn định và dễ đọc.

Ví dụ:

```text
doc_000001
doc_000001_chunk_000
doc_000001_chunk_001
doc_000002_chunk_000
```

Tại sao cần ID rõ?

```text
- Dễ debug
- Dễ map result từ vector_id về chunk
- Dễ kiểm tra retrieved chunks
- Dễ viết report
```

`vector_id` nên là số nguyên tăng dần:

```text
vector_id = dòng thứ mấy trong chunks.jsonl
```

Ví dụ:

```text
vector_id 0 → doc_000001_chunk_000
vector_id 1 → doc_000001_chunk_001
vector_id 2 → doc_000002_chunk_000
```

Điều này giúp Phase 3 lưu embedding dễ hơn:

```text
embedding vector thứ i tương ứng metadata dòng i
```

---

## 9. Corpus statistics

Sau khi chunking, nên sinh file:

```text
data/processed/corpus_stats.json
```

Ví dụ:

```json
{
  "dataset": "viquad",
  "num_documents": 5109,
  "num_chunks": 18342,
  "avg_chars_per_chunk": 876.4,
  "min_chars_per_chunk": 120,
  "max_chars_per_chunk": 1000,
  "chunk_size_chars": 1000,
  "chunk_overlap_chars": 150
}
```

Vì sao cần?

```text
- Dùng trong report
- Biết corpus có đủ lớn để benchmark không
- Dễ so sánh các cấu hình chunk_size khác nhau
```

---

## 10. Parallel có nằm ở Phase 2 không?

Có thể, nhưng không nên là trọng tâm chính.

Phase 2 có thể xử lý document song song:

```text
Document 1 → chunking
Document 2 → chunking
Document 3 → chunking
...
```

Vì mỗi document độc lập, bước chunking cũng có thể parallel.

Nhưng trong project này, trọng tâm parallel nên là:

```text
Phase 5 — Parallel retrieval engine
```

Vậy ở Phase 2:

```text
Must-have:
- Chunking đúng, sạch, deterministic

Nice-to-have:
- Parallel preprocessing nếu dataset lớn
```

Nếu muốn nhắc trong report, có thể viết:

> Data preprocessing can also be parallelized because documents are independent. However, this project focuses on retrieval-time parallelism, where the performance impact is more critical for RAG latency.

---

## 11. Scripts nên có trong Phase 2

## 11.1. `prepare_dataset.py`

Script tổng hợp.

```bash
python scripts/prepare_dataset.py \
  --dataset viquad \
  --input data/raw/viquad \
  --output data/processed \
  --chunk-size 1000 \
  --overlap 150
```

Script này có thể gọi các bước:

```text
convert dataset
clean text
chunk documents
write chunks
write metadata
write stats
```

---

## 11.2. `chunk_documents.py`

Script riêng cho chunking.

```bash
python scripts/chunk_documents.py \
  --input data/processed/documents.jsonl \
  --chunks-output data/processed/chunks.jsonl \
  --metadata-output data/processed/metadata.jsonl \
  --chunk-size 1000 \
  --overlap 150
```

---

## 11.3. `inspect_chunks.py`

Script để xem thử vài chunk.

```bash
python scripts/inspect_chunks.py \
  --input data/processed/chunks.jsonl \
  --num-samples 5
```

Output:

```text
chunk_id: doc_000014_chunk_002
chars: 934
text:
...
```

Script này rất hữu ích để kiểm tra chunk có bị xấu không.

---

## 12. Test cần có trong Phase 2

## Test 1 — Không sinh chunk rỗng

```text
Mọi chunk phải có text length > 0
```

## Test 2 — Chunk không vượt quá giới hạn quá nhiều

```text
len(chunk.text) <= chunk_size + tolerance
```

Ví dụ tolerance = 100 nếu paragraph quá dài.

## Test 3 — ID không trùng

```text
chunk_id phải unique
doc_id phải consistent
```

## Test 4 — Metadata khớp chunks

```text
Số dòng metadata.jsonl = số dòng chunks.jsonl
vector_id tăng từ 0 đến num_chunks - 1
```

## Test 5 — Text không bị mất quá nhiều

Có thể kiểm tra đơn giản:

```text
Tổng text chunk không được quá thấp so với tổng text document
```

Vì có overlap nên tổng chunk text có thể lớn hơn text gốc. Nhưng không nên nhỏ bất thường.

---

## 13. Acceptance Criteria cho Phase 2

Phase 2 hoàn thành khi đạt đủ:

### Data

```text
- Có dataset thô trong data/raw/
- Convert được dataset sang documents.jsonl
- Mỗi document có doc_id, text, source
```

### Chunking

```text
- Sinh được chunks.jsonl
- Mỗi chunk có chunk_id, doc_id, text, source
- Không có chunk rỗng
- Chunk size hợp lý
```

### Metadata

```text
- Sinh được metadata.jsonl
- vector_id khớp thứ tự chunk
- Số dòng metadata = số dòng chunks
```

### Statistics

```text
- Sinh được corpus_stats.json
- Có num_documents
- Có num_chunks
- Có avg/min/max chars per chunk
```

### Demo

Chạy được command:

```bash
python scripts/prepare_dataset.py \
  --dataset viquad \
  --input data/raw/viquad \
  --output data/processed \
  --chunk-size 1000 \
  --overlap 150
```

Output kỳ vọng:

```text
Loaded 5109 documents.
Generated 18342 chunks.
Average chunk length: 876 chars.
Saved chunks to data/processed/chunks.jsonl.
Saved metadata to data/processed/metadata.jsonl.
Saved stats to data/processed/corpus_stats.json.
```

---

## 14. Output cuối Phase 2

Cuối Phase 2, repo nên có:

```text
data/processed/
├── documents.jsonl
├── chunks.jsonl
├── metadata.jsonl
└── corpus_stats.json
```

Và scripts:

```text
scripts/
├── prepare_dataset.py
├── convert_squad.py
├── convert_viquad.py
├── convert_msmarco.py
├── convert_scifact.py
├── chunk_documents.py
└── inspect_chunks.py
```

---

## 15. Phase 2 chưa cần làm gì?

Để không quá scope, Phase 2 chưa cần:

```text
- Gọi Embedding API
- Sinh embeddings.bin
- Load vector bằng C++
- Search top-k
- Benchmark speedup
- Gọi LLM API
- Làm giao diện demo
```

Những phần đó thuộc phase sau:

```text
Phase 3 → Embedding pipeline
Phase 4 → Serial retrieval
Phase 5 → Parallel retrieval
Phase 6 → Benchmark
Phase 7 → RAG integration
```

---

## 16. Kết luận Phase 2

Phase 2 nên tập trung vào một câu:

> Biến dataset thô thành một tập chunks sạch, có ID rõ ràng, có metadata đầy đủ, sẵn sàng để embed ở Phase 3.

Cấu hình khuyến nghị ban đầu:

```text
Chunking method:
- Paragraph-aware character chunking

Chunk size:
- 1000 characters

Overlap:
- 150 characters

Output:
- documents.jsonl
- chunks.jsonl
- metadata.jsonl
- corpus_stats.json
```

Sau Phase 2, project sẽ có corpus chuẩn để bước sang Phase 3:

```text
chunks.jsonl
→ call Embedding API
→ embeddings.bin
```
