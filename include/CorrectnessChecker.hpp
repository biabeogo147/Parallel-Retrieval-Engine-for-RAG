#pragma once

#include <cstdint>
#include <string>
#include <vector>

namespace retriever {

struct TopKCsvRow {
    std::uint64_t query_id = 0;
    std::uint64_t rank_position = 0;
    std::uint64_t memory_id = 0;
    float score = 0.0f;
};

struct QueryCorrectnessResult {
    std::uint64_t query_id = 0;
    int k = 0;
    bool matched = false;
    int matched_ids = 0;
    float max_score_diff = 0.0f;
    std::string status;
};

class CorrectnessChecker {
public:
    static std::vector<QueryCorrectnessResult> compare(
        const std::vector<TopKCsvRow>& sequential_rows,
        const std::vector<TopKCsvRow>& parallel_rows,
        double epsilon);
};

}  // namespace retriever
