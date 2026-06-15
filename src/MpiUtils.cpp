#include "MpiUtils.hpp"

#include <mpi.h>

#include <algorithm>
#include <array>
#include <cstring>
#include <limits>
#include <stdexcept>

namespace retriever {
namespace {

constexpr int kStartupErrorBufferSize = 1024;

void check_mpi(const int code, const char* operation_name) {
    if (code != MPI_SUCCESS) {
        throw std::runtime_error(std::string(operation_name) + " failed");
    }
}

int mpi_rank() {
    int rank = 0;
    check_mpi(MPI_Comm_rank(MPI_COMM_WORLD, &rank), "MPI_Comm_rank");
    return rank;
}

int mpi_size() {
    int size = 1;
    check_mpi(MPI_Comm_size(MPI_COMM_WORLD, &size), "MPI_Comm_size");
    return size;
}

void copy_error_message(
    const std::string& message,
    std::array<char, kStartupErrorBufferSize>& buffer) {
    buffer.fill('\0');
    const auto bytes_to_copy = std::min(message.size(), buffer.size() - 1);
    if (bytes_to_copy > 0) {
        std::memcpy(buffer.data(), message.data(), bytes_to_copy);
    }
}

}  // namespace

void broadcast_query_vector(float* buffer, const std::uint32_t dimension, const int root) {
    if (dimension > 0 && buffer == nullptr) {
        throw std::runtime_error("query broadcast buffer must not be null");
    }

    check_mpi(
        MPI_Bcast(buffer, static_cast<int>(dimension), MPI_FLOAT, root, MPI_COMM_WORLD),
        "MPI_Bcast");
}

void pack_local_candidates_fixed_k(
    const QueryTopKResult& result,
    const int topk,
    std::vector<std::uint64_t>& ids,
    std::vector<float>& scores) {
    if (topk < 1) {
        throw std::runtime_error("topk must be at least 1");
    }

    ids.assign(static_cast<std::size_t>(topk), kSentinelMemoryId);
    scores.assign(
        static_cast<std::size_t>(topk),
        -std::numeric_limits<float>::infinity());

    const auto copied_count = std::min(result.topk.size(), ids.size());
    for (std::size_t index = 0; index < copied_count; ++index) {
        ids[index] = result.topk[index].memory_id;
        scores[index] = result.topk[index].score;
    }
}

void gather_fixed_candidates(
    const std::vector<std::uint64_t>& local_ids,
    const std::vector<float>& local_scores,
    const int root,
    std::vector<std::uint64_t>& gathered_ids,
    std::vector<float>& gathered_scores) {
    if (local_ids.size() != local_scores.size()) {
        throw std::runtime_error("local candidate id and score buffers must have the same size");
    }

    const int rank = mpi_rank();
    const int size = mpi_size();
    const int slot_count = static_cast<int>(local_ids.size());

    if (rank == root) {
        gathered_ids.resize(static_cast<std::size_t>(size) * local_ids.size());
        gathered_scores.resize(static_cast<std::size_t>(size) * local_scores.size());
    } else {
        gathered_ids.clear();
        gathered_scores.clear();
    }

    check_mpi(
        MPI_Gather(
            local_ids.data(),
            slot_count,
            MPI_UINT64_T,
            rank == root ? gathered_ids.data() : nullptr,
            slot_count,
            MPI_UINT64_T,
            root,
            MPI_COMM_WORLD),
        "MPI_Gather(ids)");

    check_mpi(
        MPI_Gather(
            local_scores.data(),
            slot_count,
            MPI_FLOAT,
            rank == root ? gathered_scores.data() : nullptr,
            slot_count,
            MPI_FLOAT,
            root,
            MPI_COMM_WORLD),
        "MPI_Gather(scores)");
}

std::vector<ParallelRankMetrics> gather_rank_metrics(
    const int rank,
    const std::uint64_t local_N,
    const double compute_time,
    const double communication_time,
    const double local_total_time,
    const int root) {
    const int size = mpi_size();

    std::vector<std::uint64_t> gathered_local_n;
    std::vector<double> gathered_compute;
    std::vector<double> gathered_communication;
    std::vector<double> gathered_total;

    if (rank == root) {
        gathered_local_n.resize(static_cast<std::size_t>(size));
        gathered_compute.resize(static_cast<std::size_t>(size));
        gathered_communication.resize(static_cast<std::size_t>(size));
        gathered_total.resize(static_cast<std::size_t>(size));
    }

    check_mpi(
        MPI_Gather(
            const_cast<std::uint64_t*>(&local_N),
            1,
            MPI_UINT64_T,
            rank == root ? gathered_local_n.data() : nullptr,
            1,
            MPI_UINT64_T,
            root,
            MPI_COMM_WORLD),
        "MPI_Gather(local_N)");

    check_mpi(
        MPI_Gather(
            const_cast<double*>(&compute_time),
            1,
            MPI_DOUBLE,
            rank == root ? gathered_compute.data() : nullptr,
            1,
            MPI_DOUBLE,
            root,
            MPI_COMM_WORLD),
        "MPI_Gather(compute_time)");

    check_mpi(
        MPI_Gather(
            const_cast<double*>(&communication_time),
            1,
            MPI_DOUBLE,
            rank == root ? gathered_communication.data() : nullptr,
            1,
            MPI_DOUBLE,
            root,
            MPI_COMM_WORLD),
        "MPI_Gather(communication_time)");

    check_mpi(
        MPI_Gather(
            const_cast<double*>(&local_total_time),
            1,
            MPI_DOUBLE,
            rank == root ? gathered_total.data() : nullptr,
            1,
            MPI_DOUBLE,
            root,
            MPI_COMM_WORLD),
        "MPI_Gather(local_total_time)");

    if (rank != root) {
        return {};
    }

    const auto max_total_it = std::max_element(gathered_total.begin(), gathered_total.end());
    const double global_total_time =
        max_total_it == gathered_total.end() ? 0.0 : *max_total_it;

    std::vector<ParallelRankMetrics> metrics;
    metrics.reserve(static_cast<std::size_t>(size));

    for (int index = 0; index < size; ++index) {
        ParallelRankMetrics metric;
        metric.rank = index;
        metric.local_N = gathered_local_n[static_cast<std::size_t>(index)];
        metric.compute_time = gathered_compute[static_cast<std::size_t>(index)];
        metric.communication_time = gathered_communication[static_cast<std::size_t>(index)];
        metric.active_time = metric.compute_time + metric.communication_time;
        metric.global_total_time = global_total_time;
        metric.idle_time = std::max(0.0, metric.global_total_time - metric.active_time);
        metrics.push_back(metric);
    }

    return metrics;
}

StartupErrorReport gather_startup_errors(
    const bool has_error,
    const std::string& message,
    const int root) {
    const int rank = mpi_rank();
    const int size = mpi_size();
    const int local_flag = has_error ? 1 : 0;
    int any_error = 0;

    check_mpi(
        MPI_Allreduce(&local_flag, &any_error, 1, MPI_INT, MPI_MAX, MPI_COMM_WORLD),
        "MPI_Allreduce(startup error flag)");

    StartupErrorReport report;
    report.any_error = any_error != 0;
    if (!report.any_error) {
        return report;
    }

    std::array<char, kStartupErrorBufferSize> local_buffer{};
    copy_error_message(message, local_buffer);

    std::vector<int> gathered_flags;
    std::vector<char> gathered_buffers;
    if (rank == root) {
        gathered_flags.resize(static_cast<std::size_t>(size));
        gathered_buffers.resize(static_cast<std::size_t>(size) * local_buffer.size());
    }

    check_mpi(
        MPI_Gather(
            const_cast<int*>(&local_flag),
            1,
            MPI_INT,
            rank == root ? gathered_flags.data() : nullptr,
            1,
            MPI_INT,
            root,
            MPI_COMM_WORLD),
        "MPI_Gather(startup error flags)");

    check_mpi(
        MPI_Gather(
            local_buffer.data(),
            static_cast<int>(local_buffer.size()),
            MPI_CHAR,
            rank == root ? gathered_buffers.data() : nullptr,
            static_cast<int>(local_buffer.size()),
            MPI_CHAR,
            root,
            MPI_COMM_WORLD),
        "MPI_Gather(startup error messages)");

    if (rank == root) {
        for (int index = 0; index < size; ++index) {
            if (gathered_flags[static_cast<std::size_t>(index)] == 0) {
                continue;
            }

            const auto* buffer_start =
                gathered_buffers.data() +
                static_cast<std::size_t>(index) * local_buffer.size();
            report.message = std::string(buffer_start);
            if (report.message.empty()) {
                report.message = "parallel startup failed with an unknown error";
            }
            break;
        }
    }

    return report;
}

}  // namespace retriever
