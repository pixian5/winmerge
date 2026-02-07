/*
 * DiffEngine.cpp - Cross-platform diff engine implementation
 *
 * Uses the xdiff library for the core comparison algorithm.
 */

#include "DiffEngine.h"
#include "FileOperations.h"
#include "xdiff.h"
#include <cstdlib>
#include <cstring>

namespace wm {

// Callback context for collecting hunk information from xdiff
struct HunkCollector {
    std::vector<DiffBlock>* blocks;
};

static int hunkCallback(long start_a, long count_a,
                        long start_b, long count_b,
                        void* cb_data) {
    auto* collector = static_cast<HunkCollector*>(cb_data);
    DiffBlock block;
    block.leftStart = static_cast<int>(start_a);
    block.leftCount = static_cast<int>(count_a);
    block.rightStart = static_cast<int>(start_b);
    block.rightCount = static_cast<int>(count_b);

    if (count_a == 0)
        block.op = DiffOp::Added;
    else if (count_b == 0)
        block.op = DiffOp::Removed;
    else
        block.op = DiffOp::Modified;

    collector->blocks->push_back(block);
    return 0;
}

DiffEngine::DiffEngine() = default;
DiffEngine::~DiffEngine() = default;

void DiffEngine::setOptions(const DiffOptions& options) {
    m_options = options;
}

DiffResult DiffEngine::compareFiles(const std::string& leftPath,
                                    const std::string& rightPath) {
    std::string leftText = FileOps::readFile(leftPath);
    std::string rightText = FileOps::readFile(rightPath);
    return runDiff(leftText, rightText);
}

DiffResult DiffEngine::compareStrings(const std::string& leftText,
                                      const std::string& rightText) {
    return runDiff(leftText, rightText);
}

DiffResult DiffEngine::runDiff(const std::string& leftText,
                               const std::string& rightText) {
    DiffResult result;

    // Check if files are identical
    if (leftText == rightText) {
        result.identical = true;
        auto lines = splitLines(leftText);
        for (int i = 0; i < static_cast<int>(lines.size()); i++) {
            DiffLine dl;
            dl.text = lines[i];
            dl.op = DiffOp::Equal;
            dl.leftLineNum = i;
            dl.rightLineNum = i;
            result.lines.push_back(dl);
        }
        return result;
    }

    // Set up xdiff memory files
    mmfile_t mf1, mf2;
    mf1.ptr = const_cast<char*>(leftText.c_str());
    mf1.size = static_cast<long>(leftText.size());
    mf2.ptr = const_cast<char*>(rightText.c_str());
    mf2.size = static_cast<long>(rightText.size());

    // Configure xdiff parameters
    xpparam_t xpp;
    std::memset(&xpp, 0, sizeof(xpp));
    xpp.flags = 0;

    if (m_options.ignoreWhitespace)
        xpp.flags |= XDF_IGNORE_WHITESPACE;
    if (m_options.ignoreWhitespaceChange)
        xpp.flags |= XDF_IGNORE_WHITESPACE_CHANGE;
    if (m_options.ignoreBlankLines)
        xpp.flags |= XDF_IGNORE_BLANK_LINES;
    if (m_options.ignoreCase)
        xpp.flags |= XDF_IGNORE_CASE;

    switch (m_options.algorithm) {
        case DiffOptions::Algorithm::Patience:
            xpp.flags |= XDF_PATIENCE_DIFF;
            break;
        case DiffOptions::Algorithm::Histogram:
            xpp.flags |= XDF_HISTOGRAM_DIFF;
            break;
        case DiffOptions::Algorithm::Minimal:
            xpp.flags |= XDF_NEED_MINIMAL;
            break;
        case DiffOptions::Algorithm::Myers:
        default:
            break;
    }

    // Set up emit configuration with hunk callback
    xdemitconf_t xecfg;
    std::memset(&xecfg, 0, sizeof(xecfg));
    xecfg.hunk_func = hunkCallback;

    HunkCollector collector;
    collector.blocks = &result.blocks;

    xdemitcb_t ecb;
    std::memset(&ecb, 0, sizeof(ecb));
    ecb.priv = &collector;

    // Run the diff
    xdl_diff(&mf1, &mf2, &xpp, &xecfg, &ecb);

    // Build line-by-line diff from blocks
    auto leftLines = splitLines(leftText);
    auto rightLines = splitLines(rightText);
    buildDiffLines(result, leftLines, rightLines);

    result.identical = result.blocks.empty();
    return result;
}

void DiffEngine::buildDiffLines(DiffResult& result,
                                const std::vector<std::string>& leftLines,
                                const std::vector<std::string>& rightLines) {
    int leftPos = 0;
    int rightPos = 0;

    for (const auto& block : result.blocks) {
        // Add equal lines before this block
        while (leftPos < block.leftStart && rightPos < block.rightStart) {
            DiffLine dl;
            dl.text = leftLines[leftPos];
            dl.op = DiffOp::Equal;
            dl.leftLineNum = leftPos;
            dl.rightLineNum = rightPos;
            result.lines.push_back(dl);
            leftPos++;
            rightPos++;
        }

        // Add lines from this diff block
        if (block.op == DiffOp::Modified) {
            // Show removed lines from left, then added lines from right
            for (int i = 0; i < block.leftCount; i++) {
                DiffLine dl;
                dl.text = leftLines[block.leftStart + i];
                dl.op = DiffOp::Removed;
                dl.leftLineNum = block.leftStart + i;
                result.lines.push_back(dl);
            }
            for (int i = 0; i < block.rightCount; i++) {
                DiffLine dl;
                dl.text = rightLines[block.rightStart + i];
                dl.op = DiffOp::Added;
                dl.rightLineNum = block.rightStart + i;
                result.lines.push_back(dl);
            }
        } else if (block.op == DiffOp::Removed) {
            for (int i = 0; i < block.leftCount; i++) {
                DiffLine dl;
                dl.text = leftLines[block.leftStart + i];
                dl.op = DiffOp::Removed;
                dl.leftLineNum = block.leftStart + i;
                result.lines.push_back(dl);
            }
        } else if (block.op == DiffOp::Added) {
            for (int i = 0; i < block.rightCount; i++) {
                DiffLine dl;
                dl.text = rightLines[block.rightStart + i];
                dl.op = DiffOp::Added;
                dl.rightLineNum = block.rightStart + i;
                result.lines.push_back(dl);
            }
        }

        leftPos = block.leftStart + block.leftCount;
        rightPos = block.rightStart + block.rightCount;
    }

    // Add remaining equal lines after the last block
    while (leftPos < static_cast<int>(leftLines.size()) &&
           rightPos < static_cast<int>(rightLines.size())) {
        DiffLine dl;
        dl.text = leftLines[leftPos];
        dl.op = DiffOp::Equal;
        dl.leftLineNum = leftPos;
        dl.rightLineNum = rightPos;
        result.lines.push_back(dl);
        leftPos++;
        rightPos++;
    }
}

std::vector<std::string> DiffEngine::splitLines(const std::string& text) {
    std::vector<std::string> lines;
    std::string::size_type start = 0;
    std::string::size_type pos;

    while ((pos = text.find('\n', start)) != std::string::npos) {
        std::string line = text.substr(start, pos - start);
        // Remove trailing \r for Windows line endings
        if (!line.empty() && line.back() == '\r')
            line.pop_back();
        lines.push_back(line);
        start = pos + 1;
    }

    // Add last line if text doesn't end with newline
    if (start < text.size()) {
        std::string line = text.substr(start);
        if (!line.empty() && line.back() == '\r')
            line.pop_back();
        lines.push_back(line);
    }

    return lines;
}

} // namespace wm
