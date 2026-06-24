#pragma once

#include <array>
#include <cstdint>
#include <filesystem>
#include <vector>

namespace retriever {

struct BinaryDatasetHeader {
    std::array<char, 8> magic{};
    std::uint32_t version = 0;
    std::uint32_t flags = 0;
    std::uint64_t num_vectors = 0;
    std::uint32_t dimension = 0;
    std::uint32_t reserved0 = 0;
};

struct BinaryDatasetContents {
    BinaryDatasetHeader header;
    std::vector<float> values;
};

struct ShardBounds {
    std::uint64_t start_index = 0;
    std::uint64_t count = 0;
};

struct BinaryDatasetShard {
    BinaryDatasetHeader header;
    std::vector<float> values;
    ShardBounds bounds;
};

class BinaryDataset {
public:
    static constexpr std::uint32_t kVersion = 1;
    static constexpr std::uint32_t kFlagNormalized = 1u << 0;
    static constexpr std::uint32_t kFlagRowMajor = 1u << 1;

    static BinaryDatasetHeader make_header(
        std::uint64_t num_vectors,
        std::uint32_t dimension,
        std::uint32_t flags);

    static void write(
        const std::filesystem::path& path,
        const BinaryDatasetHeader& header,
        const std::vector<float>& values);

    static BinaryDatasetHeader read_header(const std::filesystem::path& path);
    static BinaryDatasetContents read_all(const std::filesystem::path& path);
    static BinaryDatasetContents read_all(
        const std::filesystem::path& path,
        std::uint64_t limit_vectors);
    static BinaryDatasetShard read_shard(
        const std::filesystem::path& path,
        int rank,
        int world_size);
    static BinaryDatasetShard read_shard(
        const std::filesystem::path& path,
        int rank,
        int world_size,
        std::uint64_t limit_vectors);
    static ShardBounds compute_shard_bounds(
        std::uint64_t total_vectors,
        int rank,
        int world_size);
};

}  // namespace retriever
