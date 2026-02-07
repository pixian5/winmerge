/*
 * DiffResult.h - Data structures for diff results
 *
 * Cross-platform diff result types used by both the core engine
 * and the UI layer.
 */

#pragma once

#include <string>
#include <vector>

namespace wm {

// Type of difference operation
enum class DiffOp {
    Equal,      // Lines are identical
    Added,      // Lines added in the right file
    Removed,    // Lines removed from the left file
    Modified    // Lines differ between left and right
};

// A single line in a diff result
struct DiffLine {
    std::string text;
    DiffOp op = DiffOp::Equal;
    int leftLineNum = -1;   // -1 indicates no corresponding line
    int rightLineNum = -1;
};

// A contiguous block of differences
struct DiffBlock {
    DiffOp op = DiffOp::Equal;
    int leftStart = 0;
    int leftCount = 0;
    int rightStart = 0;
    int rightCount = 0;
};

// Complete result of a file comparison
struct DiffResult {
    std::vector<DiffLine> lines;
    std::vector<DiffBlock> blocks;
    bool identical = false;
    bool binaryFile = false;

    int totalDiffs() const {
        int count = 0;
        for (const auto& b : blocks) {
            if (b.op != DiffOp::Equal)
                count++;
        }
        return count;
    }
};

// Options controlling the diff algorithm
struct DiffOptions {
    bool ignoreWhitespace = false;
    bool ignoreWhitespaceChange = false;
    bool ignoreBlankLines = false;
    bool ignoreCase = false;

    enum class Algorithm {
        Myers,      // Default (fastest for most cases)
        Patience,   // Better for code with moved blocks
        Histogram,  // Good balance of speed and quality
        Minimal     // Produces minimal diff (slower)
    };
    Algorithm algorithm = Algorithm::Myers;
};

} // namespace wm
