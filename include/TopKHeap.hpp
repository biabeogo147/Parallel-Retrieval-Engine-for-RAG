#pragma once

#include <cstddef>
#include <cstdint>
#include <vector>

namespace retriever {

struct RetrievalCandidate {
    std::uint64_t memory_id = 0;
    float score = 0.0f;
};

bool candidate_is_better(
    const RetrievalCandidate& left,
    const RetrievalCandidate& right) noexcept;

bool candidate_is_worse(
    const RetrievalCandidate& left,
    const RetrievalCandidate& right) noexcept;

class TopKHeap {
public:
    explicit TopKHeap(int limit);

    void push(std::uint64_t memory_id, float score);
    void push(const RetrievalCandidate& candidate);

    std::vector<RetrievalCandidate> sorted_results() const;
    std::size_t size() const noexcept;
    int limit() const noexcept;

private:
    void sift_up(std::size_t index);
    void sift_down(std::size_t index);

    int limit_ = 0;
    std::vector<RetrievalCandidate> heap_;
};

}  // namespace retriever
