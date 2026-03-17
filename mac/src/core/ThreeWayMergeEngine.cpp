/*
 * ThreeWayMergeEngine.cpp - 3-way merge foundation for macOS port
 */

#include "ThreeWayMergeEngine.h"
#include "FileOperations.h"
#include <algorithm>
#include <sstream>

namespace wm {

namespace {

static std::vector<std::string> splitLines(const std::string& text) {
    std::vector<std::string> lines;
    std::stringstream ss(text);
    std::string line;
    while (std::getline(ss, line)) {
        lines.push_back(line);
    }
    if (!text.empty() && text.back() == '\n') {
        lines.emplace_back("");
    }
    return lines;
}

} // namespace

ThreeWayMergeResult ThreeWayMergeEngine::mergeFiles(const std::string& basePath,
                                                    const std::string& leftPath,
                                                    const std::string& rightPath) const {
    ThreeWayMergeResult result;
    const auto baseLines = splitLines(FileOps::readFile(basePath));
    const auto leftLines = splitLines(FileOps::readFile(leftPath));
    const auto rightLines = splitLines(FileOps::readFile(rightPath));

    const size_t maxLines = std::max({baseLines.size(), leftLines.size(), rightLines.size()});
    std::ostringstream out;
    int mergedLineIndex = 0;

    auto lineAt = [](const std::vector<std::string>& lines, size_t index, bool& exists) -> std::string {
        if (index < lines.size()) {
            exists = true;
            return lines[index];
        }
        exists = false;
        return {};
    };

    for (size_t i = 0; i < maxLines; ++i) {
        bool hasBase = false, hasLeft = false, hasRight = false;
        std::string base = lineAt(baseLines, i, hasBase);
        std::string left = lineAt(leftLines, i, hasLeft);
        std::string right = lineAt(rightLines, i, hasRight);

        if (!hasBase && !hasLeft && !hasRight) {
            continue;
        }

        if (left == right) {
            out << left << '\n';
            mergedLineIndex++;
            continue;
        }
        if (left == base) {
            out << right << '\n';
            mergedLineIndex++;
            continue;
        }
        if (right == base) {
            out << left << '\n';
            mergedLineIndex++;
            continue;
        }

        const int start = mergedLineIndex + 1;
        out << "<<<<<<< LEFT\n";
        out << left << '\n';
        out << "||||||| BASE\n";
        out << base << '\n';
        out << "=======\n";
        out << right << '\n';
        out << ">>>>>>> RIGHT\n";
        mergedLineIndex += 7;
        result.conflicts.push_back({start, mergedLineIndex});
        result.conflictCount++;
    }

    result.mergedText = out.str();
    return result;
}

} // namespace wm
