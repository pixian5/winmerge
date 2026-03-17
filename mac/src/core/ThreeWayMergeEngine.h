/*
 * ThreeWayMergeEngine.h - 3-way merge foundation for macOS port
 */

#pragma once

#include <string>
#include <vector>

namespace wm {

struct MergeConflictRange {
    int startLine = 0;
    int endLine = 0;
};

struct ThreeWayMergeResult {
    std::string mergedText;
    std::vector<MergeConflictRange> conflicts;
    int conflictCount = 0;

    bool hasConflicts() const { return conflictCount > 0; }
};

class ThreeWayMergeEngine {
public:
    ThreeWayMergeResult mergeFiles(const std::string& basePath,
                                   const std::string& leftPath,
                                   const std::string& rightPath) const;
};

} // namespace wm
