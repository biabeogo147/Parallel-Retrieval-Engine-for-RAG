#pragma once

#include "BinaryDataset.hpp"
#include "TopKHeap.hpp"

#include <cstdint>
#include <vector>

namespace retriever {

struct QueryTopKResult {
    std::uint64_t query_id = 0;
    std::vector<RetrievalCandidate> topk;
};

class SequentialRetriever {
public:
    static QueryTopKResult search_local(
        const BinaryDatasetHeader& memory_header,
        const float* memory_values,
        std::uint64_t local_vector_count,
        const BinaryDatasetHeader& query_header,
        const float* query_values,
        std::uint64_t query_id,
        int topk,
        std::uint64_t memory_id_offset = 0);

    static std::vector<QueryTopKResult> search_all(
        const BinaryDatasetContents& memory_dataset,
        const BinaryDatasetContents& query_dataset,
        int topk);
};

}  // namespace retriever
