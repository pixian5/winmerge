/*
 * FileOperations.h - File I/O utilities
 *
 * Cross-platform file operations using C++ standard library and POSIX APIs.
 */

#pragma once

#include <string>
#include <vector>

namespace wm {
namespace FileOps {

// Read entire file contents into a string
std::string readFile(const std::string& path);

// Check if a file exists
bool fileExists(const std::string& path);

// Check if a path is a directory
bool isDirectory(const std::string& path);

// Get the filename component from a path
std::string fileName(const std::string& path);

// List files in a directory (non-recursive)
std::vector<std::string> listDirectory(const std::string& path);

} // namespace FileOps
} // namespace wm
