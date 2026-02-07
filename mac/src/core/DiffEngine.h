/*
 * DiffEngine.h - Cross-platform diff engine wrapper
 *
 * Wraps the xdiff library (from WinMerge Externals/) to provide
 * a clean C++ interface for file comparison.
 */

#pragma once

#include "DiffResult.h"
#include <string>
#include <vector>

namespace wm {

class DiffEngine {
public:
    DiffEngine();
    ~DiffEngine();

    // Set comparison options
    void setOptions(const DiffOptions& options);
    const DiffOptions& options() const { return m_options; }

    // Compare two files and produce a DiffResult
    DiffResult compareFiles(const std::string& leftPath,
                            const std::string& rightPath);

    // Compare two in-memory strings
    DiffResult compareStrings(const std::string& leftText,
                              const std::string& rightText);

private:
    DiffOptions m_options;

    // Internal: run xdiff on two memory buffers
    DiffResult runDiff(const std::string& leftText,
                       const std::string& rightText);

    // Build DiffLine entries from blocks and source text
    void buildDiffLines(DiffResult& result,
                        const std::vector<std::string>& leftLines,
                        const std::vector<std::string>& rightLines);

    // Split text into lines
    static std::vector<std::string> splitLines(const std::string& text);
};

} // namespace wm
