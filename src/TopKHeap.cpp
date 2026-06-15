#include "TopKHeap.hpp"

#include <algorithm>
#include <stdexcept>

namespace retriever {

bool candidate_is_better(
    const RetrievalCandidate& left,
    const RetrievalCandidate& right) noexcept {
    if (left.score != right.score) {
        return left.score > right.score;
    }

    return left.memory_id < right.memory_id;
}

bool candidate_is_worse(
    const RetrievalCandidate& left,
    const RetrievalCandidate& right) noexcept {
    if (left.score != right.score) {
        return left.score < right.score;
    }

    return left.memory_id > right.memory_id;
}

TopKHeap::TopKHeap(const int limit) : limit_(limit) {
    if (limit_ < 1) {
        throw std::runtime_error("topk must be at least 1");
    }
}

void TopKHeap::push(const std::uint64_t memory_id, const float score) {
    push(RetrievalCandidate{memory_id, score});
}

void TopKHeap::push(const RetrievalCandidate& candidate) {
    if (heap_.size() < static_cast<std::size_t>(limit_)) {
        heap_.push_back(candidate);
        sift_up(heap_.size() - 1);
        return;
    }

    if (!heap_.empty() && candidate_is_better(candidate, heap_.front())) {
        heap_.front() = candidate;
        sift_down(0);
    }
}

std::vector<RetrievalCandidate> TopKHeap::sorted_results() const {
    auto results = heap_;
    std::sort(results.begin(), results.end(), candidate_is_better);
    return results;
}

std::size_t TopKHeap::size() const noexcept {
    return heap_.size();
}

int TopKHeap::limit() const noexcept {
    return limit_;
}

void TopKHeap::sift_up(std::size_t index) {
    while (index > 0) {
        const auto parent = (index - 1) / 2;
        if (!candidate_is_worse(heap_[index], heap_[parent])) {
            break;
        }

        std::swap(heap_[index], heap_[parent]);
        index = parent;
    }
}

void TopKHeap::sift_down(std::size_t index) {
    while (true) {
        const auto left = index * 2 + 1;
        const auto right = left + 1;
        auto worst = index;

        if (left < heap_.size() && candidate_is_worse(heap_[left], heap_[worst])) {
            worst = left;
        }

        if (right < heap_.size() && candidate_is_worse(heap_[right], heap_[worst])) {
            worst = right;
        }

        if (worst == index) {
            return;
        }

        std::swap(heap_[index], heap_[worst]);
        index = worst;
    }
}

}  // namespace retriever
