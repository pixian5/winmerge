using System.Text;

if (args.Length == 0 || args[0] is "--help" or "-h")
{
    PrintUsage();
    return 0;
}

switch (args[0])
{
    case "file-diff":
        return RunFileDiff(args);
    case "folder-diff":
        return RunFolderDiff(args);
    case "merge3":
        return RunMerge3(args);
    case "--self-test":
        return RunSelfTests();
    default:
        Console.Error.WriteLine($"Unknown command: {args[0]}");
        PrintUsage();
        return 1;
}

static int RunFileDiff(string[] args)
{
    if (args.Length < 3)
    {
        Console.Error.WriteLine("file-diff requires <leftFile> <rightFile>.");
        return 1;
    }

    string leftPath = args[1];
    string rightPath = args[2];
    if (!File.Exists(leftPath) || !File.Exists(rightPath))
    {
        Console.Error.WriteLine("Both file paths must exist.");
        return 1;
    }

    var left = File.ReadAllLines(leftPath);
    var right = File.ReadAllLines(rightPath);
    int max = Math.Max(left.Length, right.Length);
    int diffs = 0;

    for (int i = 0; i < max; i++)
    {
        string? l = i < left.Length ? left[i] : null;
        string? r = i < right.Length ? right[i] : null;
        if (l == r)
        {
            Console.WriteLine($"  {l ?? ""}");
            continue;
        }

        diffs++;
        if (l is null)
            Console.WriteLine($"+ {r}");
        else if (r is null)
            Console.WriteLine($"- {l}");
        else
        {
            Console.WriteLine($"- {l}");
            Console.WriteLine($"+ {r}");
        }
    }

    Console.WriteLine($"[file-diff] differences={diffs}");
    return 0;
}

static int RunFolderDiff(string[] args)
{
    if (args.Length < 3)
    {
        Console.Error.WriteLine("folder-diff requires <leftFolder> <rightFolder>.");
        return 1;
    }

    string leftRoot = args[1];
    string rightRoot = args[2];
    if (!Directory.Exists(leftRoot) || !Directory.Exists(rightRoot))
    {
        Console.Error.WriteLine("Both folder paths must exist.");
        return 1;
    }

    var left = CollectEntries(leftRoot);
    var right = CollectEntries(rightRoot);
    var keys = new SortedSet<string>(left.Keys.Concat(right.Keys), StringComparer.Ordinal);

    int added = 0, removed = 0, modified = 0;
    foreach (var relative in keys)
    {
        bool inLeft = left.TryGetValue(relative, out var leftPath);
        bool inRight = right.TryGetValue(relative, out var rightPath);

        if (!inLeft)
        {
            added++;
            Console.WriteLine($"+ {relative}");
        }
        else if (!inRight)
        {
            removed++;
            Console.WriteLine($"- {relative}");
        }
        else if (Directory.Exists(leftPath!) || Directory.Exists(rightPath!))
        {
            // Skip directory equality output to keep result concise.
        }
        else if (!FileContentEquals(leftPath!, rightPath!))
        {
            modified++;
            Console.WriteLine($"~ {relative}");
        }
    }

    Console.WriteLine($"[folder-diff] +{added} -{removed} ~{modified}");
    return 0;
}

static int RunMerge3(string[] args)
{
    if (args.Length < 4)
    {
        Console.Error.WriteLine("merge3 requires <baseFile> <leftFile> <rightFile> [--resolve left|right|base].");
        return 1;
    }

    string basePath = args[1];
    string leftPath = args[2];
    string rightPath = args[3];
    if (!File.Exists(basePath) || !File.Exists(leftPath) || !File.Exists(rightPath))
    {
        Console.Error.WriteLine("Base/left/right files must all exist.");
        return 1;
    }

    string? resolveAll = null;
    if (args.Length >= 6 && args[4] == "--resolve")
    {
        resolveAll = args[5].ToLowerInvariant();
        if (resolveAll is not ("left" or "right" or "base"))
        {
            Console.Error.WriteLine("--resolve must be one of: left, right, base.");
            return 1;
        }
    }

    var baseLines = File.ReadAllLines(basePath);
    var leftLines = File.ReadAllLines(leftPath);
    var rightLines = File.ReadAllLines(rightPath);
    int max = Math.Max(baseLines.Length, Math.Max(leftLines.Length, rightLines.Length));
    int conflicts = 0;
    var output = new StringBuilder();

    for (int i = 0; i < max; i++)
    {
        string b = i < baseLines.Length ? baseLines[i] : "";
        string l = i < leftLines.Length ? leftLines[i] : "";
        string r = i < rightLines.Length ? rightLines[i] : "";

        if (l == r)
        {
            output.AppendLine(l);
        }
        else if (l == b)
        {
            output.AppendLine(r);
        }
        else if (r == b)
        {
            output.AppendLine(l);
        }
        else if (resolveAll is not null)
        {
            output.AppendLine(resolveAll switch
            {
                "left" => l,
                "right" => r,
                _ => b
            });
        }
        else
        {
            conflicts++;
            output.AppendLine("<<<<<<< LEFT");
            output.AppendLine(l);
            output.AppendLine("||||||| BASE");
            output.AppendLine(b);
            output.AppendLine("=======");
            output.AppendLine(r);
            output.AppendLine(">>>>>>> RIGHT");
        }
    }

    Console.Write(output.ToString());
    Console.WriteLine($"[merge3] conflicts={conflicts}");
    return 0;
}

static Dictionary<string, string> CollectEntries(string root)
{
    var map = new Dictionary<string, string>(StringComparer.Ordinal);
    foreach (var path in Directory.EnumerateFileSystemEntries(root, "*", SearchOption.AllDirectories))
    {
        string relative = Path.GetRelativePath(root, path).Replace('\\', '/');
        map[relative] = path;
    }
    return map;
}

static bool FileContentEquals(string leftPath, string rightPath)
{
    var leftInfo = new FileInfo(leftPath);
    var rightInfo = new FileInfo(rightPath);
    if (leftInfo.Length != rightInfo.Length) return false;
    return File.ReadAllBytes(leftPath).AsSpan().SequenceEqual(File.ReadAllBytes(rightPath));
}

static int RunSelfTests()
{
    string root = Path.Combine(Path.GetTempPath(), "wm-csharp-selftest");
    if (Directory.Exists(root))
        Directory.Delete(root, recursive: true);
    Directory.CreateDirectory(root);

    string baseFile = Path.Combine(root, "base.txt");
    string leftFile = Path.Combine(root, "left.txt");
    string rightFile = Path.Combine(root, "right.txt");
    File.WriteAllText(baseFile, "A\nB\n");
    File.WriteAllText(leftFile, "A\nL\n");
    File.WriteAllText(rightFile, "A\nR\n");

    var mergeOutput = Capture(() => RunMerge3(["merge3", baseFile, leftFile, rightFile]));
    Assert(mergeOutput.Contains("[merge3] conflicts=1"), "merge3 conflict count should be 1");

    string lf = Path.Combine(root, "f1.txt");
    string rf = Path.Combine(root, "f2.txt");
    File.WriteAllText(lf, "x\ny\n");
    File.WriteAllText(rf, "x\nz\n");
    var diffOutput = Capture(() => RunFileDiff(["file-diff", lf, rf]));
    Assert(diffOutput.Contains("[file-diff] differences=1"), "file-diff differences should be 1");

    string ldir = Path.Combine(root, "leftdir");
    string rdir = Path.Combine(root, "rightdir");
    Directory.CreateDirectory(ldir);
    Directory.CreateDirectory(rdir);
    File.WriteAllText(Path.Combine(ldir, "a.txt"), "1");
    File.WriteAllText(Path.Combine(rdir, "a.txt"), "2");
    File.WriteAllText(Path.Combine(rdir, "b.txt"), "3");
    var folderOutput = Capture(() => RunFolderDiff(["folder-diff", ldir, rdir]));
    Assert(folderOutput.Contains("~ a.txt"), "folder-diff should include modified file");
    Assert(folderOutput.Contains("+ b.txt"), "folder-diff should include added file");

    Console.WriteLine("[self-test] all tests passed");
    return 0;
}

static string Capture(Func<int> run)
{
    var originalOut = Console.Out;
    var originalErr = Console.Error;
    using var writer = new StringWriter();
    Console.SetOut(writer);
    Console.SetError(writer);
    int exit = run();
    Console.SetOut(originalOut);
    Console.SetError(originalErr);
    if (exit != 0)
        throw new Exception($"Captured run failed with exit code {exit}: {writer}");
    return writer.ToString();
}

static void Assert(bool condition, string message)
{
    if (!condition) throw new Exception(message);
}

static void PrintUsage()
{
    Console.WriteLine("WinMerge.CrossPlatform (C# MVP)");
    Console.WriteLine("Usage:");
    Console.WriteLine("  file-diff <leftFile> <rightFile>");
    Console.WriteLine("  folder-diff <leftFolder> <rightFolder>");
    Console.WriteLine("  merge3 <baseFile> <leftFile> <rightFile> [--resolve left|right|base]");
    Console.WriteLine("  --self-test");
}
