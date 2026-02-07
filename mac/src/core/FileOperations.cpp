/*
 * FileOperations.cpp - File I/O utilities implementation
 *
 * Uses C++ standard library and POSIX APIs for cross-platform file operations.
 */

#include "FileOperations.h"
#include <fstream>
#include <sstream>
#include <sys/stat.h>
#include <dirent.h>

namespace wm {
namespace FileOps {

std::string readFile(const std::string& path) {
    std::ifstream file(path, std::ios::binary);
    if (!file.is_open())
        return {};

    std::ostringstream ss;
    ss << file.rdbuf();
    return ss.str();
}

bool fileExists(const std::string& path) {
    struct stat st;
    return stat(path.c_str(), &st) == 0;
}

bool isDirectory(const std::string& path) {
    struct stat st;
    if (stat(path.c_str(), &st) != 0)
        return false;
    return S_ISDIR(st.st_mode);
}

std::string fileName(const std::string& path) {
    auto pos = path.find_last_of('/');
    if (pos == std::string::npos)
        return path;
    return path.substr(pos + 1);
}

std::vector<std::string> listDirectory(const std::string& path) {
    std::vector<std::string> entries;
    DIR* dir = opendir(path.c_str());
    if (!dir)
        return entries;

    struct dirent* entry;
    while ((entry = readdir(dir)) != nullptr) {
        std::string name = entry->d_name;
        if (name != "." && name != "..")
            entries.push_back(path + "/" + name);
    }
    closedir(dir);
    return entries;
}

} // namespace FileOps
} // namespace wm
