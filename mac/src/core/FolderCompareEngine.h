/*
 * FolderCompareEngine.h - Folder comparison engine for macOS port
 */

#pragma once

#include "DiffResult.h"
#include <string>
#include <vector>

namespace wm {

struct FolderDiffItem {
    std::string relativePath;
    bool isDirectory = false;
    DiffOp op = DiffOp::Equal;
};

struct FolderCompareResult {
    std::vector<FolderDiffItem> items;
    int addedCount = 0;
    int removedCount = 0;
    int modifiedCount = 0;

    int totalDiffs() const {
        return addedCount + removedCount + modifiedCount;
    }
};

class FolderCompareEngine {
public:
    FolderCompareResult compareFolders(const std::string& leftRoot,
                                       const std::string& rightRoot) const;
};

} // namespace wm
