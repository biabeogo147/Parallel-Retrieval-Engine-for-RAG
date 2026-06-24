#include "BinaryDataset.hpp"

#include <algorithm>
#include <cmath>
#include <fstream>
#include <limits>
#include <stdexcept>
#include <string>

namespace retriever {
namespace {

constexpr std::array<char, 8> kExpectedMagic = {'P', 'M', 'R', 'A', 'G', 'V', '1', '\0'};
constexpr std::uint64_t kHeaderSize =
    kExpectedMagic.size() +
    sizeof(std::uint32_t) +
    sizeof(std::uint32_t) +
    sizeof(std::uint64_t) +
    sizeof(std::uint32_t) +
    sizeof(std::uint32_t);

static_assert(sizeof(float) == 4, "BinaryDataset requires 32-bit float payloads");

void ensure_little_endian() {
    const std::uint32_t value = 1;
    const auto* bytes = reinterpret_cast<const unsigned char*>(&value);
    if (bytes[0] != 1) {
        throw std::runtime_error("BinaryDataset requires a little-endian host");
    }
}

std::uint64_t checked_multiply(std::uint64_t left, std::uint64_t right, const std::string& label) {
    if (left != 0 && right > std::numeric_limits<std::uint64_t>::max() / left) {
        throw std::runtime_error(label + " overflows uint64");
    }
    return left * right;
}

std::uint64_t checked_add(std::uint64_t left, std::uint64_t right, const std::string& label) {
    if (right > std::numeric_limits<std::uint64_t>::max() - left) {
        throw std::runtime_error(label + " overflows uint64");
    }
    return left + right;
}

std::uint64_t expected_value_count(const BinaryDatasetHeader& header) {
    return checked_multiply(
        header.num_vectors,
        static_cast<std::uint64_t>(header.dimension),
        "dataset element count");
}

std::uint64_t expected_payload_bytes(const BinaryDatasetHeader& header) {
    return checked_multiply(expected_value_count(header), sizeof(float), "dataset payload size");
}

void validate_header_fields(const BinaryDatasetHeader& header) {
    if (header.magic != kExpectedMagic) {
        throw std::runtime_error("invalid dataset magic");
    }

    if (header.version != BinaryDataset::kVersion) {
        throw std::runtime_error("invalid dataset version");
    }

    if (header.dimension == 0) {
        throw std::runtime_error("dataset dimension must be positive");
    }
}

std::ifstream open_input(const std::filesystem::path& path) {
    std::ifstream stream(path, std::ios::binary);
    if (!stream) {
        throw std::runtime_error("failed to open dataset for reading: " + path.string());
    }
    return stream;
}

std::ofstream open_output(const std::filesystem::path& path) {
    std::ofstream stream(path, std::ios::binary | std::ios::trunc);
    if (!stream) {
        throw std::runtime_error("failed to open dataset for writing: " + path.string());
    }
    return stream;
}

std::uint64_t file_size_bytes(std::ifstream& stream) {
    stream.seekg(0, std::ios::end);
    const auto end_position = stream.tellg();
    if (end_position < 0) {
        throw std::runtime_error("failed to determine dataset file size");
    }

    stream.seekg(0, std::ios::beg);
    return static_cast<std::uint64_t>(end_position);
}

template <typename T>
void read_value(std::ifstream& stream, T& value, const char* label) {
    stream.read(reinterpret_cast<char*>(&value), sizeof(T));
    if (!stream) {
        throw std::runtime_error(std::string("truncated dataset ") + label);
    }
}

template <typename T>
void write_value(std::ofstream& stream, const T& value) {
    stream.write(reinterpret_cast<const char*>(&value), sizeof(T));
}

BinaryDatasetHeader read_validated_header(std::ifstream& stream, std::uint64_t& actual_file_size) {
    ensure_little_endian();

    actual_file_size = file_size_bytes(stream);
    if (actual_file_size < kHeaderSize) {
        throw std::runtime_error("truncated dataset header");
    }

    BinaryDatasetHeader header;
    stream.read(header.magic.data(), static_cast<std::streamsize>(header.magic.size()));
    if (!stream) {
        throw std::runtime_error("truncated dataset header");
    }

    read_value(stream, header.version, "header");
    read_value(stream, header.flags, "header");
    read_value(stream, header.num_vectors, "header");
    read_value(stream, header.dimension, "header");
    read_value(stream, header.reserved0, "header");

    validate_header_fields(header);

    const auto expected_payload_size = expected_payload_bytes(header);
    const auto expected_file_size = checked_add(kHeaderSize, expected_payload_size, "dataset file size");

    if (actual_file_size < expected_file_size) {
        throw std::runtime_error("truncated dataset payload");
    }

    if (actual_file_size > expected_file_size) {
        throw std::runtime_error("dataset payload size is inconsistent with header metadata");
    }

    return header;
}

void validate_write_request(
    const BinaryDatasetHeader& header,
    const std::vector<float>& values) {
    ensure_little_endian();
    validate_header_fields(header);

    const auto expected_values = expected_value_count(header);
    if (values.size() != expected_values) {
        throw std::runtime_error("dataset payload size does not match header metadata");
    }
}

BinaryDatasetHeader apply_vector_limit(
    const BinaryDatasetHeader& header,
    const std::uint64_t limit_vectors) {
    if (limit_vectors == 0) {
        return header;
    }

    if (limit_vectors > header.num_vectors) {
        throw std::runtime_error(
            "requested dataset limit exceeds available vectors");
    }

    BinaryDatasetHeader limited_header = header;
    limited_header.num_vectors = limit_vectors;
    return limited_header;
}

}  // namespace

BinaryDatasetHeader BinaryDataset::make_header(
    const std::uint64_t num_vectors,
    const std::uint32_t dimension,
    const std::uint32_t flags) {
    BinaryDatasetHeader header;
    header.magic = kExpectedMagic;
    header.version = kVersion;
    header.flags = flags;
    header.num_vectors = num_vectors;
    header.dimension = dimension;
    header.reserved0 = 0;
    validate_header_fields(header);
    return header;
}

void BinaryDataset::write(
    const std::filesystem::path& path,
    const BinaryDatasetHeader& header,
    const std::vector<float>& values) {
    validate_write_request(header, values);

    const auto parent = path.parent_path();
    if (!parent.empty()) {
        std::filesystem::create_directories(parent);
    }

    auto stream = open_output(path);
    stream.write(header.magic.data(), static_cast<std::streamsize>(header.magic.size()));
    write_value(stream, header.version);
    write_value(stream, header.flags);
    write_value(stream, header.num_vectors);
    write_value(stream, header.dimension);
    write_value(stream, header.reserved0);

    if (!values.empty()) {
        stream.write(
            reinterpret_cast<const char*>(values.data()),
            static_cast<std::streamsize>(values.size() * sizeof(float)));
    }

    if (!stream) {
        throw std::runtime_error("failed while writing dataset payload");
    }
}

BinaryDatasetHeader BinaryDataset::read_header(const std::filesystem::path& path) {
    auto stream = open_input(path);
    std::uint64_t actual_file_size = 0;
    return read_validated_header(stream, actual_file_size);
}

BinaryDatasetContents BinaryDataset::read_all(const std::filesystem::path& path) {
    return read_all(path, 0);
}

BinaryDatasetContents BinaryDataset::read_all(
    const std::filesystem::path& path,
    const std::uint64_t limit_vectors) {
    auto stream = open_input(path);
    std::uint64_t actual_file_size = 0;
    const auto full_header = read_validated_header(stream, actual_file_size);
    const auto header = apply_vector_limit(full_header, limit_vectors);
    const auto total_values = expected_value_count(header);

    BinaryDatasetContents contents;
    contents.header = header;
    contents.values.resize(static_cast<std::size_t>(total_values));

    if (!contents.values.empty()) {
        stream.read(
            reinterpret_cast<char*>(contents.values.data()),
            static_cast<std::streamsize>(contents.values.size() * sizeof(float)));
        if (!stream) {
            throw std::runtime_error("truncated dataset payload");
        }
    }

    return contents;
}

BinaryDatasetShard BinaryDataset::read_shard(
    const std::filesystem::path& path,
    const int rank,
    const int world_size) {
    return read_shard(path, rank, world_size, 0);
}

BinaryDatasetShard BinaryDataset::read_shard(
    const std::filesystem::path& path,
    const int rank,
    const int world_size,
    const std::uint64_t limit_vectors) {
    auto stream = open_input(path);
    std::uint64_t actual_file_size = 0;
    const auto full_header = read_validated_header(stream, actual_file_size);
    const auto header = apply_vector_limit(full_header, limit_vectors);
    const auto bounds = compute_shard_bounds(header.num_vectors, rank, world_size);

    BinaryDatasetShard shard;
    shard.header = header;
    shard.bounds = bounds;

    const auto shard_values = checked_multiply(
        bounds.count,
        static_cast<std::uint64_t>(header.dimension),
        "shard element count");
    shard.values.resize(static_cast<std::size_t>(shard_values));

    if (shard.values.empty()) {
        return shard;
    }

    const auto element_offset = checked_multiply(
        bounds.start_index,
        static_cast<std::uint64_t>(header.dimension),
        "shard element offset");
    const auto byte_offset = checked_multiply(element_offset, sizeof(float), "shard byte offset");
    stream.seekg(static_cast<std::streamoff>(kHeaderSize + byte_offset), std::ios::beg);
    if (!stream) {
        throw std::runtime_error("failed to seek to shard payload");
    }

    stream.read(
        reinterpret_cast<char*>(shard.values.data()),
        static_cast<std::streamsize>(shard.values.size() * sizeof(float)));
    if (!stream) {
        throw std::runtime_error("truncated dataset payload");
    }

    return shard;
}

ShardBounds BinaryDataset::compute_shard_bounds(
    const std::uint64_t total_vectors,
    const int rank,
    const int world_size) {
    if (world_size <= 0) {
        throw std::runtime_error("world_size must be positive");
    }

    if (rank < 0 || rank >= world_size) {
        throw std::runtime_error("rank must be in [0, world_size)");
    }

    const auto world_size_u64 = static_cast<std::uint64_t>(world_size);
    const auto rank_u64 = static_cast<std::uint64_t>(rank);
    const auto base = total_vectors / world_size_u64;
    const auto remainder = total_vectors % world_size_u64;
    const auto count = base + (rank_u64 < remainder ? 1u : 0u);
    const auto start_index = checked_multiply(rank_u64, base, "shard start index") + std::min(rank_u64, remainder);
    return {start_index, count};
}

}  // namespace retriever
