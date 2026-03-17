/*
 * FolderCompareEngine.cpp - Folder comparison engine for macOS port
 */

#include "FolderCompareEngine.h"
#include "FileOperations.h"
#include <algorithm>
#include <filesystem>
#include <map>

namespace wm {

namespace {
struct EntryInfo {
    std::string fullPath;
    bool isDirectory = false;
};

static std::map<std::string, EntryInfo> collectEntries(const std::string& rootPath) {
    std::map<std::string, EntryInfo> entries;
    namespace fs = std::filesystem;
    std::error_code ec;
    fs::path root(rootPath);
    if (!fs::exists(root, ec) || !fs::is_directory(root, ec)) {
        return entries;
    }

    for (fs::recursive_directory_iterator it(root, ec), end; it != end && !ec; it.increment(ec)) {
        fs::path relative = fs::relative(it->path(), root, ec);
        if (ec) continue;
        std::string rel = relative.generic_string();
        entries[rel] = EntryInfo{it->path().string(), it->is_directory(ec)};
    }
    return entries;
}
} // namespace

FolderCompareResult FolderCompareEngine::compareFolders(const std::string& leftRoot,
                                                        const std::string& rightRoot) const {
    FolderCompareResult result;
    auto leftEntries = collectEntries(leftRoot);
    auto rightEntries = collectEntries(rightRoot);

    std::map<std::string, bool> allKeys;
    for (const auto& kv : leftEntries) allKeys[kv.first] = true;
    for (const auto& kv : rightEntries) allKeys[kv.first] = true;

    for (const auto& kv : allKeys) {
        const std::string& rel = kv.first;
        auto leftIt = leftEntries.find(rel);
        auto rightIt = rightEntries.find(rel);
        bool inLeft = leftIt != leftEntries.end();
        bool inRight = rightIt != rightEntries.end();

        FolderDiffItem item;
        item.relativePath = rel;
        item.isDirectory = (inLeft ? leftIt->second.isDirectory : rightIt->second.isDirectory);

        if (!inLeft) {
            item.op = DiffOp::Added;
            result.addedCount++;
        } else if (!inRight) {
            item.op = DiffOp::Removed;
            result.removedCount++;
        } else if (leftIt->second.isDirectory != rightIt->second.isDirectory) {
            item.op = DiffOp::Modified;
            result.modifiedCount++;
        } else if (leftIt->second.isDirectory) {
            item.op = DiffOp::Equal;
        } else {
            std::string leftData = FileOps::readFile(leftIt->second.fullPath);
            std::string rightData = FileOps::readFile(rightIt->second.fullPath);
            if (leftData == rightData) {
                item.op = DiffOp::Equal;
            } else {
                item.op = DiffOp::Modified;
                result.modifiedCount++;
            }
        }
        result.items.push_back(std::move(item));
    }

    std::sort(result.items.begin(), result.items.end(), [](const FolderDiffItem& a, const FolderDiffItem& b) {
        return a.relativePath < b.relativePath;
    });
    return result;
}

} // namespace wm
