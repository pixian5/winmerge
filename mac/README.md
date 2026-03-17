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
- Note: Configuration/build is supported only on macOS. On Linux/Windows hosts the CMake configure step will fail due to the missing Apple Objective-C++ toolchain.

Install CMake via Homebrew if needed:

```bash
brew install cmake
```

## Building

### One-shot build + package (recommended)

```bash
./mac/build-mac.sh           # build Release and produce dist/WinMerge-macOS-<version>.zip
./mac/build-mac.sh --release # build, package, then bump mac/VERSION by +0.0.1 for the next release
```

- Version is read from `mac/VERSION` (initially `0.0.1`); each release increments the patch version (e.g., `0.0.1 → 0.0.2`).
- Output artifacts are placed in `mac/dist/`.

### Manual CMake build

```bash
cd mac
mkdir build && cd build
cmake .. -DCMAKE_BUILD_TYPE=Release
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

## Releasing builds

**Release policy**

- After every mac-related code change, produce and publish a macOS build.
- Versioning starts at `0.0.1`; each new release increments by `+0.0.1`. Use `./mac/build-mac.sh --release` to package the app and automatically bump `mac/VERSION` for the next publish.

1. Make your code changes on macOS.
2. Run `./mac/build-mac.sh --release` to build and produce `mac/dist/WinMerge-macOS-<version>.zip`.
3. Create a GitHub Release tagged `v<version>` (starting at `v0.0.1`, then `v0.0.2`, etc.) and upload the zip from `mac/dist/`.
4. The script automatically bumps `mac/VERSION` to the next patch version (e.g., `0.0.1 → 0.0.2`) to prepare for the next release.

## Features

### Implemented
- Side-by-side file comparison with syntax highlighting
- Difference highlighting (added, removed, modified lines)
- Navigation between differences (⌘↑ / ⌘↓)
- File open dialog for selecting files to compare
- Support for multiple diff algorithms (Myers, Patience, Histogram)
- Whitespace comparison options

### Not Included (macOS limitations / intentionally removed)
- Windows Explorer shell integration and context menus
- Windows-only archive browsing (7-Zip) and plugin DLLs
- Windows-specific registry/options storage (uses NSUserDefaults instead)

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
