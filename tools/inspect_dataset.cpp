#include "BinaryDataset.hpp"

#include <iostream>
#include <string>

namespace {

std::string usage_text() {
    return
        "Usage: inspect_dataset --input <path> [--help]\n"
        "\n"
        "Required options:\n"
        "  --input <path>\n"
        "\n"
        "Optional options:\n"
        "  --help\n";
}

std::string magic_to_string(const std::array<char, 8>& magic) {
    std::string result;
    for (const char character : magic) {
        if (character == '\0') {
            break;
        }
        result.push_back(character);
    }
    return result;
}

}  // namespace

int main(int argc, const char* const argv[]) {
    bool show_help = false;
    std::string input_path;

    for (int index = 1; index < argc; ++index) {
        const std::string argument = argv[index];
        if (argument == "--help") {
            show_help = true;
            break;
        }

        if (argument == "--input") {
            if (index + 1 >= argc) {
                std::cerr << "Error: missing value for --input\n\n";
                std::cerr << usage_text();
                return 1;
            }
            input_path = argv[++index];
            continue;
        }

        std::cerr << "Error: unknown flag: " << argument << "\n\n";
        std::cerr << usage_text();
        return 1;
    }

    if (show_help) {
        std::cout << usage_text();
        return 0;
    }

    if (input_path.empty()) {
        std::cerr << "Error: missing required option: --input\n\n";
        std::cerr << usage_text();
        return 1;
    }

    try {
        const auto header = retriever::BinaryDataset::read_header(input_path);
        std::cout << "magic = " << magic_to_string(header.magic) << "\n";
        std::cout << "version = " << header.version << "\n";
        std::cout << "flags = " << header.flags << "\n";
        std::cout << "num_vectors = " << header.num_vectors << "\n";
        std::cout << "dimension = " << header.dimension << "\n";
        std::cout << "reserved0 = " << header.reserved0 << "\n";
    } catch (const std::exception& ex) {
        std::cerr << "Error: " << ex.what() << "\n";
        return 1;
    }

    return 0;
}
