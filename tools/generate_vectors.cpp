#include "BinaryDataset.hpp"
#include "SyntheticGeneratorCommon.hpp"

#include <iostream>

namespace {

constexpr const char* kBinaryName = "generate_vectors";
constexpr const char* kCountFlag = "--N";

}  // namespace

int main(int argc, const char* const argv[]) {
    const auto parse_result = retriever::tooling::parse_generator_args(argc, argv, kCountFlag);

    if (!parse_result.ok) {
        std::cerr << "Error: " << parse_result.error << "\n\n";
        std::cerr << retriever::tooling::generator_usage_text(kBinaryName, kCountFlag);
        return 1;
    }

    if (parse_result.options.show_help) {
        std::cout << retriever::tooling::generator_usage_text(kBinaryName, kCountFlag);
        return 0;
    }

    try {
        const auto values = retriever::tooling::generate_normalized_vectors(
            parse_result.options.count,
            parse_result.options.dimension,
            parse_result.options.seed);

        const auto header = retriever::BinaryDataset::make_header(
            parse_result.options.count,
            parse_result.options.dimension,
            retriever::BinaryDataset::kFlagNormalized | retriever::BinaryDataset::kFlagRowMajor);

        retriever::BinaryDataset::write(parse_result.options.output_path, header, values);
    } catch (const std::exception& ex) {
        std::cerr << "Error: " << ex.what() << "\n";
        return 1;
    }

    return 0;
}
