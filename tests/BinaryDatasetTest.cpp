#include "BinaryDataset.hpp"

#include <algorithm>
#include <cstdint>
#include <filesystem>
#include <fstream>
#include <functional>
#include <stdexcept>
#include <string>
#include <vector>

namespace {

using retriever::BinaryDataset;
using retriever::BinaryDatasetHeader;
using retriever::ShardBounds;

void expect_true(bool condition, const std::string& message) {
    if (!condition) {
        throw std::runtime_error(message);
    }
}

template <typename ExceptionType>
void expect_throws(
    const std::function<void()>& fn,
    const std::string& expected_message_fragment) {
    try {
        fn();
    } catch (const ExceptionType& ex) {
        expect_true(
            std::string(ex.what()).find(expected_message_fragment) != std::string::npos,
            "exception message should mention " + expected_message_fragment);
        return;
    }

    throw std::runtime_error("expected exception was not thrown");
}

std::filesystem::path test_dir() {
    const auto path = std::filesystem::current_path() / "binary_dataset_test_tmp";
    std::filesystem::remove_all(path);
    std::filesystem::create_directories(path);
    return path;
}

void write_raw_header(
    const std::filesystem::path& path,
    const std::array<char, 8>& magic,
    std::uint32_t version,
    std::uint32_t flags,
    std::uint64_t num_vectors,
    std::uint32_t dimension,
    std::uint32_t reserved0,
    const std::vector<float>& values) {
    std::ofstream stream(path, std::ios::binary);
    if (!stream) {
        throw std::runtime_error("failed to open test file");
    }

    stream.write(magic.data(), static_cast<std::streamsize>(magic.size()));
    stream.write(reinterpret_cast<const char*>(&version), sizeof(version));
    stream.write(reinterpret_cast<const char*>(&flags), sizeof(flags));
    stream.write(reinterpret_cast<const char*>(&num_vectors), sizeof(num_vectors));
    stream.write(reinterpret_cast<const char*>(&dimension), sizeof(dimension));
    stream.write(reinterpret_cast<const char*>(&reserved0), sizeof(reserved0));
    stream.write(
        reinterpret_cast<const char*>(values.data()),
        static_cast<std::streamsize>(values.size() * sizeof(float)));
}

void test_header_round_trip() {
    const auto dir = test_dir();
    const auto path = dir / "roundtrip.bin";

    const auto header = BinaryDataset::make_header(
        3,
        2,
        BinaryDataset::kFlagNormalized | BinaryDataset::kFlagRowMajor);
    const std::vector<float> values = {
        1.0f, 0.0f,
        0.0f, 1.0f,
        0.70710677f, 0.70710677f,
    };

    BinaryDataset::write(path, header, values);

    const auto read_header = BinaryDataset::read_header(path);
    const auto contents = BinaryDataset::read_all(path);

    expect_true(read_header.magic == header.magic, "magic should round-trip");
    expect_true(read_header.version == BinaryDataset::kVersion, "version should round-trip");
    expect_true(read_header.flags == header.flags, "flags should round-trip");
    expect_true(read_header.num_vectors == 3, "num_vectors should round-trip");
    expect_true(read_header.dimension == 2, "dimension should round-trip");
    expect_true(contents.values == values, "payload should round-trip");
}

void test_invalid_magic_fails() {
    const auto dir = test_dir();
    const auto path = dir / "invalid_magic.bin";

    write_raw_header(path, {'B', 'A', 'D', 'M', 'A', 'G', 'I', 'C'}, 1, 3, 1, 2, 0, {1.0f, 2.0f});

    expect_throws<std::runtime_error>(
        [&]() { (void)BinaryDataset::read_header(path); },
        "magic");
}

void test_invalid_version_fails() {
    const auto dir = test_dir();
    const auto path = dir / "invalid_version.bin";

    write_raw_header(path, {'P', 'M', 'R', 'A', 'G', 'V', '1', '\0'}, 2, 3, 1, 2, 0, {1.0f, 2.0f});

    expect_throws<std::runtime_error>(
        [&]() { (void)BinaryDataset::read_header(path); },
        "version");
}

void test_zero_dimension_fails() {
    const auto dir = test_dir();
    const auto path = dir / "zero_dimension.bin";

    write_raw_header(path, {'P', 'M', 'R', 'A', 'G', 'V', '1', '\0'}, 1, 3, 1, 0, 0, {});

    expect_throws<std::runtime_error>(
        [&]() { (void)BinaryDataset::read_all(path); },
        "dimension");
}

void test_truncated_payload_fails() {
    const auto dir = test_dir();
    const auto path = dir / "truncated.bin";

    write_raw_header(
        path,
        {'P', 'M', 'R', 'A', 'G', 'V', '1', '\0'},
        1,
        3,
        3,
        2,
        0,
        {1.0f, 2.0f, 3.0f, 4.0f, 5.0f});

    expect_throws<std::runtime_error>(
        [&]() { (void)BinaryDataset::read_all(path); },
        "payload");
}

void test_divisible_shard_bounds() {
    const ShardBounds rank0 = BinaryDataset::compute_shard_bounds(12, 0, 4);
    const ShardBounds rank3 = BinaryDataset::compute_shard_bounds(12, 3, 4);

    expect_true(rank0.start_index == 0, "rank0 start should be 0");
    expect_true(rank0.count == 3, "rank0 count should be 3");
    expect_true(rank3.start_index == 9, "rank3 start should be 9");
    expect_true(rank3.count == 3, "rank3 count should be 3");
}

void test_non_divisible_shard_bounds() {
    const ShardBounds rank0 = BinaryDataset::compute_shard_bounds(10, 0, 3);
    const ShardBounds rank1 = BinaryDataset::compute_shard_bounds(10, 1, 3);
    const ShardBounds rank2 = BinaryDataset::compute_shard_bounds(10, 2, 3);

    expect_true(rank0.start_index == 0, "rank0 start should be 0");
    expect_true(rank0.count == 4, "rank0 count should include remainder");
    expect_true(rank1.start_index == 4, "rank1 start should be 4");
    expect_true(rank1.count == 3, "rank1 count should be 3");
    expect_true(rank2.start_index == 7, "rank2 start should be 7");
    expect_true(rank2.count == 3, "rank2 count should be 3");
}

void test_read_shard_returns_expected_slice() {
    const auto dir = test_dir();
    const auto path = dir / "shard.bin";

    const auto header = BinaryDataset::make_header(
        5,
        3,
        BinaryDataset::kFlagNormalized | BinaryDataset::kFlagRowMajor);

    const std::vector<float> values = {
        0.0f, 1.0f, 2.0f,
        3.0f, 4.0f, 5.0f,
        6.0f, 7.0f, 8.0f,
        9.0f, 10.0f, 11.0f,
        12.0f, 13.0f, 14.0f,
    };

    BinaryDataset::write(path, header, values);

    const auto shard = BinaryDataset::read_shard(path, 1, 2);
    const std::vector<float> expected = {
        9.0f, 10.0f, 11.0f,
        12.0f, 13.0f, 14.0f,
    };

    expect_true(shard.bounds.start_index == 3, "rank1 shard should start at index 3");
    expect_true(shard.bounds.count == 2, "rank1 shard should contain 2 vectors");
    expect_true(shard.values == expected, "rank1 shard payload should match contiguous slice");
}

}  // namespace

int main() {
    test_header_round_trip();
    test_invalid_magic_fails();
    test_invalid_version_fails();
    test_zero_dimension_fails();
    test_truncated_payload_fails();
    test_divisible_shard_bounds();
    test_non_divisible_shard_bounds();
    test_read_shard_returns_expected_slice();
    return 0;
}
