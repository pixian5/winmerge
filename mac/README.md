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
./mac/build-mac.sh --version 2603180101  # build with specific timestamp version
./mac/build-mac.sh --release # build, package, then bump mac/VERSION for the next release
```

- Version can be semantic (e.g., `0.0.1`) or timestamp format (e.g., `2603180101` for 2026-03-18 01:01).
- Default version is read from `mac/VERSION`; pass `--version` to override.
- Output artifacts are placed in `mac/dist/`.

### Manual CMake build

```bash
cd mac
mkdir build && cd build
cmake .. -DCMAKE_BUILD_TYPE=Release -DWM_VERSION=2603180101
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

- After every code change to master branch, CI automatically builds and publishes a macOS release.
- Versioning uses timestamp format `YYMMDDHHMI` (e.g., `2603180101` for 2026-03-18 01:01) to ensure unique versions for each build.
- CI automation (`.github/workflows/mac-release.yml`) builds and publishes a macOS release on every push to `master`, creating tags like `v2603180101`.

1. Push your code changes to the `master` branch.
2. GitHub Actions automatically builds the macOS release with a timestamp-based version.
3. The workflow creates a GitHub Release tagged `v<timestamp>` (e.g., `v2603180101`) and uploads the zip artifact.
4. Manual builds: Run `./mac/build-mac.sh --version <timestamp>` to build locally with a specific version.

## Features

### Implemented
- Side-by-side file comparison with syntax highlighting
- **Line numbers** displayed in the gutter
- Difference highlighting (added, removed, modified lines)
- **Enhanced statistics** showing lines added (+), removed (-), and modified (~)
- Navigation between differences (⌘↑ / ⌘↓)
- **Go to Line** navigation (⌘L) for left/right/both panes
- File open dialog for selecting files to compare
- **Folder comparison** (mac-native implementation) with added/removed/modified item listing
- Folder compare filtering (all/modified/added/removed) and quick open of selected comparable file pair
- Support for multiple diff algorithms (Myers, Patience, Histogram, Minimal)
- Algorithm selection from the UI
- Ignore options: whitespace, whitespace changes, blank lines, and case
- **Find functionality** (⌘F) with find bar support
- **Edit and save files** (⌘S for left, ⌘⇧S for right)
- **Copy/merge operations**: Copy selected text between left and right panes (⌘[ and ⌘])
- **3-way merge foundation**: Base/Left/Right input and merged result generation with conflict markers
- 3-way conflict navigation and per-conflict resolve actions (take left/right/base)
- Copy, Select All, and standard text editing operations

### Not Included (macOS limitations / intentionally removed)
- Windows Explorer shell integration and context menus
- Windows-only archive browsing (7-Zip) and plugin DLLs
- Windows-specific registry/options storage (uses NSUserDefaults instead)

### Planned
- Plugin system
- Enhanced syntax highlighting for more programming languages
- Patch generation and application
- Inline/character-level diffs (word-by-word comparison)
- Binary/hex file comparison
- Image comparison

## Porting Strategy

The port follows an incremental approach:

1. **Phase 1** (Current): Core diff engine + basic 2-file comparison UI
2. **Phase 2**: Folder comparison, encoding detection, filter support
3. **Phase 3**: 3-way merge, plugin system, advanced features

## License

Same as WinMerge - GNU General Public License v2.0 or later.
