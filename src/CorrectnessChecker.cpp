#include "CorrectnessChecker.hpp"

#include <algorithm>
#include <cmath>
#include <stdexcept>
#include <string>

namespace retriever {
namespace {

struct QuerySpan {
    std::uint64_t query_id = 0;
    std::size_t begin = 0;
    std::size_t count = 0;
};

struct ValidatedRows {
    std::vector<TopKCsvRow> rows;
    std::vector<QuerySpan> queries;
    int k = 0;
};

bool row_less(const TopKCsvRow& left, const TopKCsvRow& right) noexcept {
    if (left.query_id != right.query_id) {
        return left.query_id < right.query_id;
    }

    return left.rank_position < right.rank_position;
}

ValidatedRows validate_rows(
    const std::vector<TopKCsvRow>& input_rows,
    const std::string& source_name) {
    ValidatedRows validated;
    validated.rows = input_rows;
    std::sort(validated.rows.begin(), validated.rows.end(), row_less);

    std::size_t index = 0;
    while (index < validated.rows.size()) {
        const auto query_id = validated.rows[index].query_id;
        const auto begin = index;
        std::uint64_t expected_rank = 1;

        while (index < validated.rows.size() && validated.rows[index].query_id == query_id) {
            const auto& row = validated.rows[index];
            if (row.rank_position != expected_rank) {
                const bool is_duplicate =
                    index > begin &&
                    row.rank_position == validated.rows[index - 1].rank_position;
                if (is_duplicate) {
                    throw std::runtime_error(
                        source_name +
                        " contains duplicate rank_position for query_id " +
                        std::to_string(query_id));
                }

                throw std::runtime_error(
                    source_name +
                    " rank_position must be contiguous starting at 1 for query_id " +
                    std::to_string(query_id));
            }

            ++expected_rank;
            ++index;
        }

        const auto count = static_cast<int>(expected_rank - 1);
        if (validated.k == 0) {
            validated.k = count;
        } else if (validated.k != count) {
            throw std::runtime_error(
                source_name +
                " has inconsistent k across queries");
        }

        validated.queries.push_back(QuerySpan{
            query_id,
            begin,
            static_cast<std::size_t>(count),
        });
    }

    return validated;
}

}  // namespace

std::vector<QueryCorrectnessResult> CorrectnessChecker::compare(
    const std::vector<TopKCsvRow>& sequential_rows,
    const std::vector<TopKCsvRow>& parallel_rows,
    const double epsilon) {
    if (epsilon < 0.0) {
        throw std::runtime_error("epsilon must be non-negative");
    }

    const auto sequential = validate_rows(sequential_rows, "sequential input");
    const auto parallel = validate_rows(parallel_rows, "parallel input");

    if (sequential.queries.size() != parallel.queries.size()) {
        throw std::runtime_error("query_id sets do not match between sequential and parallel inputs");
    }

    if (sequential.k != parallel.k) {
        throw std::runtime_error("k differs between sequential and parallel inputs");
    }

    std::vector<QueryCorrectnessResult> results;
    results.reserve(sequential.queries.size());

    for (std::size_t query_index = 0; query_index < sequential.queries.size(); ++query_index) {
        const auto& sequential_query = sequential.queries[query_index];
        const auto& parallel_query = parallel.queries[query_index];

        if (sequential_query.query_id != parallel_query.query_id) {
            throw std::runtime_error("query_id sets do not match between sequential and parallel inputs");
        }

        if (sequential_query.count != parallel_query.count) {
            throw std::runtime_error(
                "k differs for query_id " + std::to_string(sequential_query.query_id));
        }

        int matched_ids = 0;
        float max_score_diff = 0.0f;

        for (std::size_t rank_offset = 0; rank_offset < sequential_query.count; ++rank_offset) {
            const auto& sequential_row = sequential.rows[sequential_query.begin + rank_offset];
            const auto& parallel_row = parallel.rows[parallel_query.begin + rank_offset];

            if (sequential_row.rank_position != parallel_row.rank_position) {
                throw std::runtime_error(
                    "rank_position mismatch for query_id " +
                    std::to_string(sequential_query.query_id));
            }

            if (sequential_row.memory_id == parallel_row.memory_id) {
                ++matched_ids;
            }

            const auto score_diff = std::fabs(sequential_row.score - parallel_row.score);
            if (score_diff > max_score_diff) {
                max_score_diff = score_diff;
            }
        }

        const bool matched =
            matched_ids == sequential.k &&
            static_cast<double>(max_score_diff) <= epsilon;

        QueryCorrectnessResult result;
        result.query_id = sequential_query.query_id;
        result.k = sequential.k;
        result.matched = matched;
        result.matched_ids = matched_ids;
        result.max_score_diff = max_score_diff;
        result.status = matched ? "PASS" : "FAIL";
        results.push_back(std::move(result));
    }

    return results;
}

}  // namespace retriever
