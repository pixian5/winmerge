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

static std::string lineForResolution(const MergeConflictRange& conflict) {
    switch (conflict.resolution) {
        case MergeResolution::TakeLeft: return conflict.leftLine;
        case MergeResolution::TakeRight: return conflict.rightLine;
        case MergeResolution::TakeBase: return conflict.baseLine;
        case MergeResolution::Unresolved:
        default: return {};
    }
}

static void rebuildMergedTextAndRanges(ThreeWayMergeResult& result) {
    std::ostringstream out;
    int renderedLine = 0;
    int unresolved = 0;

    for (const auto& segment : result.segments) {
        if (!segment.isConflict) {
            out << segment.lineText << '\n';
            renderedLine++;
            continue;
        }

        if (segment.conflictIndex < 0 || static_cast<size_t>(segment.conflictIndex) >= result.conflicts.size()) {
            continue;
        }

        auto& conflict = result.conflicts[static_cast<size_t>(segment.conflictIndex)];
        int startLine = renderedLine + 1;
        if (conflict.resolution == MergeResolution::Unresolved) {
            out << "<<<<<<< LEFT\n";
            out << conflict.leftLine << '\n';
            out << "||||||| BASE\n";
            out << conflict.baseLine << '\n';
            out << "=======\n";
            out << conflict.rightLine << '\n';
            out << ">>>>>>> RIGHT\n";
            renderedLine += 7;
            unresolved++;
        } else {
            out << lineForResolution(conflict) << '\n';
            renderedLine += 1;
        }
        conflict.startLine = startLine;
        conflict.endLine = renderedLine;
    }

    result.mergedText = out.str();
    result.conflictCount = unresolved;
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
    auto tryGetLineAt = [](const std::vector<std::string>& lines, size_t index, bool& exists) -> const std::string* {
        if (index < lines.size()) {
            exists = true;
            return &lines[index];
        }
        exists = false;
        return nullptr;
    };

    for (size_t i = 0; i < maxLines; ++i) {
        bool hasBase = false, hasLeft = false, hasRight = false;
        const std::string* basePtr = tryGetLineAt(baseLines, i, hasBase);
        const std::string* leftPtr = tryGetLineAt(leftLines, i, hasLeft);
        const std::string* rightPtr = tryGetLineAt(rightLines, i, hasRight);
        static const std::string kEmptyLine;
        const std::string& base = hasBase ? *basePtr : kEmptyLine;
        const std::string& left = hasLeft ? *leftPtr : kEmptyLine;
        const std::string& right = hasRight ? *rightPtr : kEmptyLine;

        if (!hasBase && !hasLeft && !hasRight) {
            continue;
        }

        if (left == right) {
            result.segments.push_back({false, left, -1});
            continue;
        }
        if (left == base) {
            result.segments.push_back({false, right, -1});
            continue;
        }
        if (right == base) {
            result.segments.push_back({false, left, -1});
            continue;
        }

        int conflictIndex = static_cast<int>(result.conflicts.size());
        MergeConflictRange conflict;
        conflict.baseLine = base;
        conflict.leftLine = left;
        conflict.rightLine = right;
        conflict.resolution = MergeResolution::Unresolved;
        result.conflicts.push_back(std::move(conflict));
        result.segments.push_back({true, {}, conflictIndex});
    }

    rebuildMergedTextAndRanges(result);
    return result;
}

void ThreeWayMergeEngine::resolveConflict(ThreeWayMergeResult& result,
                                          size_t conflictIndex,
                                          MergeResolution resolution) const {
    if (conflictIndex >= result.conflicts.size()) {
        return;
    }
    result.conflicts[conflictIndex].resolution = resolution;
    rebuildMergedTextAndRanges(result);
}

} // namespace wm
