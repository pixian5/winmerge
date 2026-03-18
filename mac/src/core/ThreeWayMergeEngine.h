/*
 * ThreeWayMergeEngine.h - 3-way merge foundation for macOS port
 */

#pragma once

#include <string>
#include <vector>

namespace wm {

enum class MergeResolution {
    Unresolved,
    TakeLeft,
    TakeRight,
    TakeBase
};

struct MergeConflictRange {
    int startLine = 0;
    int endLine = 0;
    std::string baseLine;
    std::string leftLine;
    std::string rightLine;
    MergeResolution resolution = MergeResolution::Unresolved;
};

struct MergeSegment {
    bool isConflict = false;
    std::string lineText;
    int conflictIndex = -1;
};

struct ThreeWayMergeResult {
    std::string mergedText;
    std::vector<MergeConflictRange> conflicts;
    std::vector<MergeSegment> segments;
    int conflictCount = 0;

    bool hasConflicts() const { return conflictCount > 0; }
};

class ThreeWayMergeEngine {
public:
    ThreeWayMergeResult mergeFiles(const std::string& basePath,
                                   const std::string& leftPath,
                                   const std::string& rightPath) const;
    void resolveConflict(ThreeWayMergeResult& result, size_t conflictIndex, MergeResolution resolution) const;
};

} // namespace wm
