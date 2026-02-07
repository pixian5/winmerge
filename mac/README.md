# WinMerge for macOS

This directory contains a macOS port of WinMerge, the open-source file differencing and merging tool.

## Architecture

The macOS port reuses WinMerge's cross-platform **xdiff** library (the same diff engine used by Git) for the core comparison algorithms, and provides a native **Cocoa** UI built with Objective-C++.

```
mac/
├── CMakeLists.txt          # CMake build system
├── README.md               # This file
├── src/
│   ├── core/               # Cross-platform C++ diff engine
│   │   ├── DiffEngine.h/cpp    # xdiff library wrapper
│   │   ├── DiffResult.h        # Diff result data structures
│   │   └── FileOperations.h/cpp # File I/O utilities
│   └── ui/                 # macOS Cocoa UI (Objective-C++)
│       ├── main.mm             # Application entry point
│       ├── AppDelegate.h/mm    # Application delegate
│       ├── DiffViewController.h/mm  # Main diff view controller
│       └── DiffTextView.h/mm   # Custom text view with diff highlighting
└── resources/
    ├── Info.plist           # macOS application metadata
    └── WinMerge.entitlements # App sandbox entitlements
```

## Key Design Decisions

| Windows (Original)          | macOS (This Port)                   |
|-----------------------------|-------------------------------------|
| MFC/ATL UI Framework        | Cocoa (AppKit) with Objective-C++   |
| Win32 File I/O              | POSIX / C++ standard library        |
| Windows Registry settings   | NSUserDefaults (plist)              |
| COM/OLE plugin system       | Native plugin bundles (future)      |
| TCHAR / wchar_t strings     | NSString / std::string (UTF-8)      |
| diffutils + xdiff engines   | xdiff engine (from Externals/)      |

## Prerequisites

- **macOS** 12.0 (Monterey) or later
- **Xcode** 14.0 or later (with Command Line Tools)
- **CMake** 3.20 or later

Install CMake via Homebrew if needed:

```bash
brew install cmake
```

## Building

```bash
cd mac
mkdir build && cd build
cmake ..
cmake --build .
```

The built application bundle will be at:
```
build/WinMerge.app
```

## Running

```bash
open build/WinMerge.app
```

Or compare files from the command line:

```bash
build/WinMerge.app/Contents/MacOS/WinMerge file1.txt file2.txt
```

## Features

### Implemented
- Side-by-side file comparison with syntax highlighting
- Difference highlighting (added, removed, modified lines)
- Navigation between differences (⌘↑ / ⌘↓)
- File open dialog for selecting files to compare
- Support for multiple diff algorithms (Myers, Patience, Histogram)
- Whitespace comparison options

### Planned
- Folder comparison
- 3-way merge
- Plugin system
- Syntax highlighting for common languages
- Find & replace in diff view
- Patch generation and application

## Porting Strategy

The port follows an incremental approach:

1. **Phase 1** (Current): Core diff engine + basic 2-file comparison UI
2. **Phase 2**: Folder comparison, encoding detection, filter support
3. **Phase 3**: 3-way merge, plugin system, advanced features

## License

Same as WinMerge - GNU General Public License v2.0 or later.
