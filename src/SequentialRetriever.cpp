#include "SequentialRetriever.hpp"

#include <limits>
#include <stdexcept>
#include <string>

namespace retriever {
namespace {

bool has_flag(const BinaryDatasetHeader& header, const std::uint32_t flag) {
    return (header.flags & flag) != 0;
}

std::uint64_t expected_value_count(const BinaryDatasetHeader& header) {
    return header.num_vectors * static_cast<std::uint64_t>(header.dimension);
}

void validate_flags(const BinaryDatasetHeader& header, const std::string& dataset_name) {
    if (!has_flag(header, BinaryDataset::kFlagNormalized)) {
        throw std::runtime_error(dataset_name + " dataset must set the normalized flag");
    }

    if (!has_flag(header, BinaryDataset::kFlagRowMajor)) {
        throw std::runtime_error(dataset_name + " dataset must set the row-major flag");
    }
}

void validate_headers(
    const BinaryDatasetHeader& memory_header,
    const BinaryDatasetHeader& query_header) {
    validate_flags(memory_header, "memory");
    validate_flags(query_header, "query");

    if (memory_header.dimension != query_header.dimension) {
        throw std::runtime_error("dimension mismatch between memory and query datasets");
    }
}

void validate_topk(const int topk) {
    if (topk < 1) {
        throw std::runtime_error("topk must be at least 1");
    }
}

void validate_pointer(
    const float* values,
    const std::uint64_t value_count,
    const std::string& label) {
    if (value_count > 0 && values == nullptr) {
        throw std::runtime_error(label + " buffer must not be null");
    }
}

float dot_product(const float* left, const float* right, const std::uint32_t dimension) {
    float sum = 0.0f;
    for (std::uint32_t index = 0; index < dimension; ++index) {
        sum += left[index] * right[index];
    }
    return sum;
}

std::uint64_t checked_memory_id(
    const std::uint64_t memory_id_offset,
    const std::uint64_t local_index) {
    if (memory_id_offset > std::numeric_limits<std::uint64_t>::max() - local_index) {
        throw std::runtime_error("memory_id overflow while applying shard offset");
    }

    return memory_id_offset + local_index;
}

}  // namespace

QueryTopKResult SequentialRetriever::search_local(
    const BinaryDatasetHeader& memory_header,
    const float* memory_values,
    const std::uint64_t local_vector_count,
    const BinaryDatasetHeader& query_header,
    const float* query_values,
    const std::uint64_t query_id,
    const int topk,
    const std::uint64_t memory_id_offset) {
    validate_headers(memory_header, query_header);
    validate_topk(topk);

    if (local_vector_count > memory_header.num_vectors) {
        throw std::runtime_error("local vector count exceeds memory header metadata");
    }

    const auto dimension = memory_header.dimension;
    validate_pointer(
        memory_values,
        local_vector_count * static_cast<std::uint64_t>(dimension),
        "memory");
    validate_pointer(
        query_values,
        static_cast<std::uint64_t>(query_header.dimension),
        "query");

    TopKHeap heap(topk);

    for (std::uint64_t local_index = 0; local_index < local_vector_count; ++local_index) {
        const auto value_offset = local_index * static_cast<std::uint64_t>(dimension);
        const float score = dot_product(memory_values + value_offset, query_values, dimension);
        heap.push(checked_memory_id(memory_id_offset, local_index), score);
    }

    QueryTopKResult result;
    result.query_id = query_id;
    result.topk = heap.sorted_results();
    return result;
}

std::vector<QueryTopKResult> SequentialRetriever::search_all(
    const BinaryDatasetContents& memory_dataset,
    const BinaryDatasetContents& query_dataset,
    const int topk) {
    validate_headers(memory_dataset.header, query_dataset.header);
    validate_topk(topk);

    const auto memory_value_count = expected_value_count(memory_dataset.header);
    const auto query_value_count = expected_value_count(query_dataset.header);

    if (memory_dataset.values.size() != memory_value_count) {
        throw std::runtime_error("memory dataset payload size does not match header metadata");
    }

    if (query_dataset.values.size() != query_value_count) {
        throw std::runtime_error("query dataset payload size does not match header metadata");
    }

    if (static_cast<std::uint64_t>(topk) > memory_dataset.header.num_vectors) {
        throw std::runtime_error("topk must not exceed the number of memory vectors");
    }

    const auto dimension = memory_dataset.header.dimension;
    std::vector<QueryTopKResult> results;
    results.reserve(static_cast<std::size_t>(query_dataset.header.num_vectors));

    for (std::uint64_t query_id = 0; query_id < query_dataset.header.num_vectors; ++query_id) {
        const auto query_offset = query_id * static_cast<std::uint64_t>(dimension);
        results.push_back(search_local(
            memory_dataset.header,
            memory_dataset.values.data(),
            memory_dataset.header.num_vectors,
            query_dataset.header,
            query_dataset.values.data() + query_offset,
            query_id,
            topk));
    }

    return results;
}

}  // namespace retriever
