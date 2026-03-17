# WinMerge.CrossPlatform (C# MVP)

This directory contains an experimental cross-platform C# CLI rewrite baseline.

## Commands

```bash
cd /home/runner/work/winmerge/winmerge/csharp/WinMerge.CrossPlatform
dotnet run -- file-diff <leftFile> <rightFile>
dotnet run -- folder-diff <leftFolder> <rightFolder>
dotnet run -- merge3 <baseFile> <leftFile> <rightFile> [--resolve left|right|base]
dotnet run -- --self-test
```

## Notes

- This is an MVP scope focused on core comparison/merge workflow in a portable CLI.
- It is intentionally independent from existing Windows UI and macOS Cocoa UI codepaths.
