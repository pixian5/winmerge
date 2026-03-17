/*
 * DiffViewController.mm - Main Diff View Controller Implementation
 *
 * Creates the side-by-side comparison layout and drives the diff engine.
 */

#import "DiffViewController.h"
#import "DiffTextView.h"
#import "LineNumberRulerView.h"
#include "DiffEngine.h"
#include "FileOperations.h"
#include "FolderCompareEngine.h"
#include "ThreeWayMergeEngine.h"
#include <memory>

static NSString * const kWMDiffErrorDomain = @"org.winmerge.mac";
static const NSInteger kWMDiffErrorMissingFile = 1;
static const NSInteger kWMDiffErrorPathTypeMismatch = 2;

@interface DiffViewController ()
@property (assign, nonatomic) int currentDiffIndex;
@property (assign, nonatomic) int totalDiffs;
@property (strong, nonatomic) NSButton *ignoreWhitespaceButton;
@property (strong, nonatomic) NSButton *ignoreWhitespaceChangeButton;
@property (strong, nonatomic) NSButton *ignoreBlankLinesButton;
@property (strong, nonatomic) NSButton *ignoreCaseButton;
@property (strong, nonatomic) NSPopUpButton *algorithmPopup;
@property (copy, nonatomic) NSString *currentLeftPath;
@property (copy, nonatomic) NSString *currentRightPath;
@property (copy, nonatomic) NSString *currentBasePath;
@end

@implementation DiffViewController {
    std::unique_ptr<wm::DiffResult> _diffResult;
    wm::DiffOptions _options;
}

- (void)loadView {
    self.view = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 1200, 700)];
    [self setupUI];
}

- (void)setupUI {
    // Toolbar area with file labels and status
    self.leftLabel = [self createLabel:@"(no file)"];
    self.rightLabel = [self createLabel:@"(no file)"];
    self.statusLabel = [self createLabel:@"Ready"];

    // Create scroll views with diff text views
    self.leftTextView = [[DiffTextView alloc] initWithFrame:NSZeroRect];
    self.rightTextView = [[DiffTextView alloc] initWithFrame:NSZeroRect];

    NSScrollView *leftScroll = [self wrapInScrollView:self.leftTextView];
    NSScrollView *rightScroll = [self wrapInScrollView:self.rightTextView];

    // Synchronize scrolling between the two text views
    [self synchronizeScrollViews:leftScroll and:rightScroll];

    // Layout using auto layout
    NSSplitView *splitView = [[NSSplitView alloc] init];
    splitView.dividerStyle = NSSplitViewDividerStyleThin;
    splitView.vertical = YES;
    [splitView addSubview:leftScroll];
    [splitView addSubview:rightScroll];

    // Header bar
    NSStackView *leftHeader = [NSStackView stackViewWithViews:@[self.leftLabel]];
    leftHeader.edgeInsets = NSEdgeInsetsMake(4, 8, 4, 8);
    NSStackView *rightHeader = [NSStackView stackViewWithViews:@[self.rightLabel]];
    rightHeader.edgeInsets = NSEdgeInsetsMake(4, 8, 4, 8);

    NSStackView *headerStack = [NSStackView stackViewWithViews:@[leftHeader, rightHeader]];
    headerStack.distribution = NSStackViewDistributionFillEqually;

    NSView *optionsBar = [self buildOptionsBar];

    // Status bar
    NSStackView *statusBar = [NSStackView stackViewWithViews:@[self.statusLabel]];
    statusBar.edgeInsets = NSEdgeInsetsMake(2, 8, 2, 8);

    // Main vertical stack
    NSStackView *mainStack = [NSStackView stackViewWithViews:@[headerStack, optionsBar, splitView, statusBar]];
    mainStack.orientation = NSUserInterfaceLayoutOrientationVertical;
    mainStack.spacing = 0;
    mainStack.translatesAutoresizingMaskIntoConstraints = NO;

    [self.view addSubview:mainStack];
    [NSLayoutConstraint activateConstraints:@[
        [mainStack.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [mainStack.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [mainStack.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [mainStack.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [splitView.heightAnchor constraintGreaterThanOrEqualToConstant:300],
    ]];

    // Make splitView fill available space
    [mainStack setHuggingPriority:NSLayoutPriorityDefaultLow
                   forOrientation:NSLayoutConstraintOrientationVertical];
    [splitView setContentHuggingPriority:NSLayoutPriorityDefaultLow
                           forOrientation:NSLayoutConstraintOrientationVertical];
}

- (NSView *)buildOptionsBar {
    self.ignoreWhitespaceButton = [self checkboxWithTitle:@"Ignore whitespace"
                                                   action:@selector(optionToggleChanged:)];
    self.ignoreWhitespaceChangeButton = [self checkboxWithTitle:@"Ignore whitespace changes"
                                                         action:@selector(optionToggleChanged:)];
    self.ignoreBlankLinesButton = [self checkboxWithTitle:@"Ignore blank lines"
                                                   action:@selector(optionToggleChanged:)];
    self.ignoreCaseButton = [self checkboxWithTitle:@"Ignore case"
                                             action:@selector(optionToggleChanged:)];

    self.algorithmPopup = [[NSPopUpButton alloc] initWithFrame:NSZeroRect pullsDown:NO];
    [self.algorithmPopup addItemsWithTitles:@[@"Myers (Default)", @"Minimal", @"Patience", @"Histogram"]];
    self.algorithmPopup.target = self;
    self.algorithmPopup.action = @selector(algorithmChanged:);

    NSStackView *optionsStack = [NSStackView stackViewWithViews:@[
        self.ignoreWhitespaceButton,
        self.ignoreWhitespaceChangeButton,
        self.ignoreBlankLinesButton,
        self.ignoreCaseButton,
        self.algorithmPopup
    ]];
    optionsStack.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    optionsStack.spacing = 12;
    optionsStack.edgeInsets = NSEdgeInsetsMake(4, 8, 4, 8);
    optionsStack.alignment = NSLayoutAttributeCenterY;

    return optionsStack;
}

- (NSButton *)checkboxWithTitle:(NSString *)title action:(SEL)action {
    NSButton *button = [NSButton checkboxWithTitle:title target:self action:action];
    button.font = [NSFont systemFontOfSize:12];
    return button;
}

- (NSTextField *)createLabel:(NSString *)text {
    NSTextField *label = [NSTextField labelWithString:text];
    label.font = [NSFont systemFontOfSize:12 weight:NSFontWeightMedium];
    label.lineBreakMode = NSLineBreakByTruncatingMiddle;
    return label;
}

- (NSScrollView *)wrapInScrollView:(NSTextView *)textView {
    NSScrollView *scrollView = [[NSScrollView alloc] init];
    scrollView.documentView = textView;
    scrollView.hasVerticalScroller = YES;
    scrollView.hasHorizontalScroller = YES;
    scrollView.autohidesScrollers = YES;
    scrollView.rulersVisible = YES;

    textView.minSize = NSMakeSize(0, 0);
    textView.maxSize = NSMakeSize(CGFLOAT_MAX, CGFLOAT_MAX);
    textView.verticallyResizable = YES;
    textView.horizontallyResizable = YES;
    textView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    textView.textContainer.containerSize = NSMakeSize(CGFLOAT_MAX, CGFLOAT_MAX);
    textView.textContainer.widthTracksTextView = NO;

    // Add line number ruler
    LineNumberRulerView *lineNumberRuler = [[LineNumberRulerView alloc] initWithScrollView:scrollView];
    [scrollView setVerticalRulerView:lineNumberRuler];

    return scrollView;
}

- (void)synchronizeScrollViews:(NSScrollView *)scrollA and:(NSScrollView *)scrollB {
    [[NSNotificationCenter defaultCenter]
        addObserverForName:NSViewBoundsDidChangeNotification
                    object:scrollA.contentView
                     queue:nil
                usingBlock:^(NSNotification *note) {
        NSPoint origin = scrollA.contentView.bounds.origin;
        [scrollB.contentView scrollToPoint:origin];
        [scrollB reflectScrolledClipView:scrollB.contentView];
    }];

    [[NSNotificationCenter defaultCenter]
        addObserverForName:NSViewBoundsDidChangeNotification
                    object:scrollB.contentView
                     queue:nil
                usingBlock:^(NSNotification *note) {
        NSPoint origin = scrollB.contentView.bounds.origin;
        [scrollA.contentView scrollToPoint:origin];
        [scrollA reflectScrolledClipView:scrollA.contentView];
    }];

    scrollA.contentView.postsBoundsChangedNotifications = YES;
    scrollB.contentView.postsBoundsChangedNotifications = YES;
}

#pragma mark - Comparison

- (void)compareLeftFile:(NSString *)leftPath rightFile:(NSString *)rightPath {
    self.leftLabel.stringValue = leftPath;
    self.rightLabel.stringValue = rightPath;

    self.currentBasePath = nil;
    self.currentLeftPath = leftPath;
    self.currentRightPath = rightPath;

    if (![self validateSelectionPaths:leftPath right:rightPath]) {
        return;
    }

    if (wm::FileOps::isDirectory(leftPath.UTF8String) && wm::FileOps::isDirectory(rightPath.UTF8String)) {
        [self runFolderCompareForCurrentPaths];
        return;
    }

    [self runDiffForCurrentPaths];
}

- (void)mergeBaseFile:(NSString *)basePath leftFile:(NSString *)leftPath rightFile:(NSString *)rightPath {
    auto baseExists = wm::FileOps::fileExists(basePath.UTF8String);
    auto leftExists = wm::FileOps::fileExists(leftPath.UTF8String);
    auto rightExists = wm::FileOps::fileExists(rightPath.UTF8String);
    if (!baseExists || !leftExists || !rightExists) {
        NSError *error = [NSError errorWithDomain:kWMDiffErrorDomain
                                             code:kWMDiffErrorMissingFile
                                         userInfo:@{ NSLocalizedDescriptionKey :
                                                     @"Base/left/right file paths must all exist." }];
        [self displayComparisonError:error];
        return;
    }
    if (wm::FileOps::isDirectory(basePath.UTF8String) ||
        wm::FileOps::isDirectory(leftPath.UTF8String) ||
        wm::FileOps::isDirectory(rightPath.UTF8String)) {
        NSError *error = [NSError errorWithDomain:kWMDiffErrorDomain
                                             code:kWMDiffErrorPathTypeMismatch
                                         userInfo:@{ NSLocalizedDescriptionKey :
                                                     @"3-way merge currently supports files only." }];
        [self displayComparisonError:error];
        return;
    }

    self.currentBasePath = basePath;
    self.currentLeftPath = leftPath;
    self.currentRightPath = rightPath;
    self.leftLabel.stringValue = [NSString stringWithFormat:@"LEFT: %@", leftPath];
    self.rightLabel.stringValue = [NSString stringWithFormat:@"MERGED: %@", [rightPath lastPathComponent]];

    wm::ThreeWayMergeEngine mergeEngine;
    wm::ThreeWayMergeResult mergeResult = mergeEngine.mergeFiles(basePath.UTF8String, leftPath.UTF8String, rightPath.UTF8String);

    NSString *leftContent = [NSString stringWithUTF8String:wm::FileOps::readFile(leftPath.UTF8String).c_str()];
    NSString *mergedContent = [NSString stringWithUTF8String:mergeResult.mergedText.c_str()];
    if (!leftContent) leftContent = @"";
    if (!mergedContent) mergedContent = @"";

    NSDictionary *attrs = @{NSFontAttributeName: [NSFont monospacedSystemFontOfSize:12 weight:NSFontWeightRegular]};
    [self.leftTextView.textStorage setAttributedString:[[NSAttributedString alloc] initWithString:leftContent attributes:attrs]];
    [self.rightTextView.textStorage setAttributedString:[[NSAttributedString alloc] initWithString:mergedContent attributes:attrs]];

    self.totalDiffs = mergeResult.conflictCount;
    self.currentDiffIndex = -1;
    self.statusLabel.stringValue = [NSString stringWithFormat:@"3-way merge: %d conflict(s) | base: %@",
                                    mergeResult.conflictCount, [basePath lastPathComponent]];
}

- (BOOL)validateSelectionPaths:(NSString *)leftPath right:(NSString *)rightPath {
    auto leftExists = wm::FileOps::fileExists(leftPath.UTF8String);
    auto rightExists = wm::FileOps::fileExists(rightPath.UTF8String);

    if (!leftExists || !rightExists) {
        NSError *error = [NSError errorWithDomain:kWMDiffErrorDomain
                                             code:kWMDiffErrorMissingFile
                                         userInfo:@{ NSLocalizedDescriptionKey :
                                                     [NSString stringWithFormat:@"One or both files do not exist:\n%@\n%@", leftPath, rightPath]}];
        [self displayComparisonError:error];
        return NO;
    }

    bool leftIsDir = wm::FileOps::isDirectory(leftPath.UTF8String);
    bool rightIsDir = wm::FileOps::isDirectory(rightPath.UTF8String);
    if (leftIsDir != rightIsDir) {
        NSError *error = [NSError errorWithDomain:kWMDiffErrorDomain
                                             code:kWMDiffErrorPathTypeMismatch
                                         userInfo:@{ NSLocalizedDescriptionKey :
                                                     @"Please select either two files or two folders." }];
        [self displayComparisonError:error];
        return NO;
    }

    return YES;
}

- (void)runFolderCompareForCurrentPaths {
    wm::FolderCompareEngine engine;
    wm::FolderCompareResult result = engine.compareFolders(self.currentLeftPath.UTF8String, self.currentRightPath.UTF8String);

    NSMutableAttributedString *leftAttr = [[NSMutableAttributedString alloc] init];
    NSMutableAttributedString *rightAttr = [[NSMutableAttributedString alloc] init];
    NSDictionary *defaultAttrs = @{NSFontAttributeName: [NSFont monospacedSystemFontOfSize:12 weight:NSFontWeightRegular]};

    for (const auto& item : result.items) {
        NSString *relative = [NSString stringWithUTF8String:item.relativePath.c_str()];
        NSString *label = item.isDirectory
            ? [NSString stringWithFormat:@"[DIR] %@\n", relative ?: @""]
            : [NSString stringWithFormat:@"[FILE] %@\n", relative ?: @""];

        NSColor *bgColor = nil;
        switch (item.op) {
            case wm::DiffOp::Added:
                bgColor = [NSColor colorWithSRGBRed:0.85 green:1.0 blue:0.85 alpha:1.0];
                break;
            case wm::DiffOp::Removed:
                bgColor = [NSColor colorWithSRGBRed:1.0 green:0.85 blue:0.85 alpha:1.0];
                break;
            case wm::DiffOp::Modified:
                bgColor = [NSColor colorWithSRGBRed:1.0 green:1.0 blue:0.8 alpha:1.0];
                break;
            default:
                break;
        }

        NSMutableDictionary *attrs = [defaultAttrs mutableCopy];
        if (bgColor) attrs[NSBackgroundColorAttributeName] = bgColor;

        if (item.op == wm::DiffOp::Added) {
            [leftAttr appendAttributedString:[[NSAttributedString alloc] initWithString:@"\n" attributes:defaultAttrs]];
            [rightAttr appendAttributedString:[[NSAttributedString alloc] initWithString:label attributes:attrs]];
        } else if (item.op == wm::DiffOp::Removed) {
            [leftAttr appendAttributedString:[[NSAttributedString alloc] initWithString:label attributes:attrs]];
            [rightAttr appendAttributedString:[[NSAttributedString alloc] initWithString:@"\n" attributes:defaultAttrs]];
        } else {
            [leftAttr appendAttributedString:[[NSAttributedString alloc] initWithString:label attributes:attrs]];
            [rightAttr appendAttributedString:[[NSAttributedString alloc] initWithString:label attributes:attrs]];
        }
    }

    [self.leftTextView.textStorage setAttributedString:leftAttr];
    [self.rightTextView.textStorage setAttributedString:rightAttr];
    self.totalDiffs = result.totalDiffs();
    self.currentDiffIndex = -1;
    self.statusLabel.stringValue = [NSString stringWithFormat:@"Folder compare: %d difference(s) | +%d -%d ~%d",
                                    result.totalDiffs(), result.addedCount, result.removedCount, result.modifiedCount];
}

- (void)runDiffForCurrentPaths {
    if (!self.currentLeftPath || !self.currentRightPath) return;

    wm::DiffEngine engine;
    engine.setOptions(_options);
    _diffResult = std::make_unique<wm::DiffResult>(
        engine.compareFiles(self.currentLeftPath.UTF8String, self.currentRightPath.UTF8String)
    );

    self.totalDiffs = _diffResult->totalDiffs();
    self.currentDiffIndex = -1;

    [self displayDiffResult];
    [self updateStatusLabel];
}

- (void)updateStatusLabel {
    if (!_diffResult) {
        self.statusLabel.stringValue = @"Ready";
        return;
    }

    if (_diffResult->identical) {
        self.statusLabel.stringValue = @"Files are identical (options applied)";
    } else {
        NSString *algorithm = @"Myers";
        switch (_options.algorithm) {
            case wm::DiffOptions::Algorithm::Minimal: algorithm = @"Minimal"; break;
            case wm::DiffOptions::Algorithm::Patience: algorithm = @"Patience"; break;
            case wm::DiffOptions::Algorithm::Histogram: algorithm = @"Histogram"; break;
            default: break;
        }

        // Count added, removed, and modified lines
        int linesAdded = 0;
        int linesRemoved = 0;
        int linesModified = 0;

        for (const auto& line : _diffResult->lines) {
            switch (line.op) {
                case wm::DiffOp::Added:
                    linesAdded++;
                    break;
                case wm::DiffOp::Removed:
                    linesRemoved++;
                    break;
                case wm::DiffOp::Modified:
                    linesModified++;
                    break;
                default:
                    break;
            }
        }

        self.statusLabel.stringValue =
            [NSString stringWithFormat:@"%d difference(s) - %@ algorithm | +%d -%d ~%d lines",
                self.totalDiffs, algorithm, linesAdded, linesRemoved, linesModified];
    }
}

- (void)displayDiffResult {
    if (!_diffResult) return;

    NSMutableAttributedString *leftAttr = [[NSMutableAttributedString alloc] init];
    NSMutableAttributedString *rightAttr = [[NSMutableAttributedString alloc] init];

    NSFont *monoFont = [NSFont monospacedSystemFontOfSize:12 weight:NSFontWeightRegular];
    NSDictionary *defaultAttrs = @{NSFontAttributeName: monoFont};

    for (const auto& line : _diffResult->lines) {
        NSString *text = [NSString stringWithUTF8String:line.text.c_str()];
        if (!text) text = @"";
        NSString *lineWithNewline = [text stringByAppendingString:@"\n"];

        NSColor *bgColor = nil;
        switch (line.op) {
            case wm::DiffOp::Added:
                bgColor = [NSColor colorWithSRGBRed:0.85 green:1.0 blue:0.85 alpha:1.0];
                break;
            case wm::DiffOp::Removed:
                bgColor = [NSColor colorWithSRGBRed:1.0 green:0.85 blue:0.85 alpha:1.0];
                break;
            case wm::DiffOp::Modified:
                bgColor = [NSColor colorWithSRGBRed:1.0 green:1.0 blue:0.8 alpha:1.0];
                break;
            default:
                break;
        }

        NSMutableDictionary *attrs = [defaultAttrs mutableCopy];
        if (bgColor) {
            attrs[NSBackgroundColorAttributeName] = bgColor;
        }

        // Left side: show Equal and Removed lines
        if (line.op == wm::DiffOp::Equal || line.op == wm::DiffOp::Removed) {
            NSAttributedString *as = [[NSAttributedString alloc]
                initWithString:lineWithNewline attributes:attrs];
            [leftAttr appendAttributedString:as];
        } else if (line.op == wm::DiffOp::Added) {
            // Blank placeholder on left for added lines
            NSAttributedString *as = [[NSAttributedString alloc]
                initWithString:@"\n" attributes:attrs];
            [leftAttr appendAttributedString:as];
        }

        // Right side: show Equal and Added lines
        if (line.op == wm::DiffOp::Equal || line.op == wm::DiffOp::Added) {
            NSAttributedString *as = [[NSAttributedString alloc]
                initWithString:lineWithNewline attributes:attrs];
            [rightAttr appendAttributedString:as];
        } else if (line.op == wm::DiffOp::Removed) {
            // Blank placeholder on right for removed lines
            NSAttributedString *as = [[NSAttributedString alloc]
                initWithString:@"\n" attributes:attrs];
            [rightAttr appendAttributedString:as];
        }
    }

    [self.leftTextView.textStorage setAttributedString:leftAttr];
    [self.rightTextView.textStorage setAttributedString:rightAttr];
}

- (void)optionToggleChanged:(id)sender {
    [self syncOptionsFromUI];
    [self rerunIfPossible];
}

- (void)algorithmChanged:(id)sender {
    [self syncOptionsFromUI];
    [self rerunIfPossible];
}

- (void)syncOptionsFromUI {
    _options.ignoreWhitespace = self.ignoreWhitespaceButton.state == NSControlStateValueOn;
    _options.ignoreWhitespaceChange = self.ignoreWhitespaceChangeButton.state == NSControlStateValueOn;
    _options.ignoreBlankLines = self.ignoreBlankLinesButton.state == NSControlStateValueOn;
    _options.ignoreCase = self.ignoreCaseButton.state == NSControlStateValueOn;

    switch (self.algorithmPopup.indexOfSelectedItem) {
        case 1: _options.algorithm = wm::DiffOptions::Algorithm::Minimal; break;
        case 2: _options.algorithm = wm::DiffOptions::Algorithm::Patience; break;
        case 3: _options.algorithm = wm::DiffOptions::Algorithm::Histogram; break;
        case 0:
        default: _options.algorithm = wm::DiffOptions::Algorithm::Myers; break;
    }
}

- (void)rerunIfPossible {
    if (self.currentLeftPath && self.currentRightPath) {
        [self runDiffForCurrentPaths];
    }
}

#pragma mark - Navigation

- (void)navigateToNextDiff {
    if (!_diffResult || self.totalDiffs == 0) return;

    self.currentDiffIndex++;
    if (self.currentDiffIndex >= self.totalDiffs)
        self.currentDiffIndex = 0;

    [self scrollToDiffAtIndex:self.currentDiffIndex];
}

- (void)navigateToPrevDiff {
    if (!_diffResult || self.totalDiffs == 0) return;

    self.currentDiffIndex--;
    if (self.currentDiffIndex < 0)
        self.currentDiffIndex = self.totalDiffs - 1;

    [self scrollToDiffAtIndex:self.currentDiffIndex];
}

- (void)scrollToDiffAtIndex:(int)index {
    if (!_diffResult) return;

    int diffCount = 0;
    for (const auto& block : _diffResult->blocks) {
        if (block.op != wm::DiffOp::Equal) {
            if (diffCount == index) {
                // Estimate line position and scroll to it
                NSUInteger lineNum = static_cast<NSUInteger>(block.leftStart);
                [self.leftTextView scrollToLine:lineNum];
                [self.rightTextView scrollToLine:lineNum];

                self.statusLabel.stringValue =
                    [NSString stringWithFormat:@"Difference %d of %d",
                        index + 1, self.totalDiffs];
                return;
            }
            diffCount++;
        }
    }
}

- (NSUInteger)lineCountForTextView:(NSTextView *)textView {
    NSString *text = textView.string ?: @"";
    if (text.length == 0) return 0;

    NSUInteger lines = 0;
    NSUInteger charIndex = 0;
    while (charIndex < text.length) {
        NSRange lineRange = [text lineRangeForRange:NSMakeRange(charIndex, 0)];
        charIndex = NSMaxRange(lineRange);
        lines++;
    }
    return lines;
}

- (void)presentGoToLineDialog {
    NSUInteger leftLines = [self lineCountForTextView:self.leftTextView];
    NSUInteger rightLines = [self lineCountForTextView:self.rightTextView];
    NSUInteger maxLines = MAX(leftLines, rightLines);
    if (maxLines == 0) {
        [self showAlert:@"No content to navigate. Open files and run compare first."];
        return;
    }

    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Go to Line";
    alert.informativeText = [NSString stringWithFormat:@"Enter a line number (1-%lu).", (unsigned long)maxLines];
    [alert addButtonWithTitle:@"Go"];
    [alert addButtonWithTitle:@"Cancel"];

    NSTextField *lineField = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 220, 24)];
    lineField.placeholderString = @"Line number";

    NSPopUpButton *panePopup = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(0, 0, 220, 26) pullsDown:NO];
    [panePopup addItemsWithTitles:@[@"Both panes", @"Left pane", @"Right pane"]];
    [panePopup selectItemAtIndex:0];

    NSStackView *accessory = [NSStackView stackViewWithViews:@[lineField, panePopup]];
    accessory.orientation = NSUserInterfaceLayoutOrientationVertical;
    accessory.spacing = 8;
    alert.accessoryView = accessory;

    if ([self.view.window makeFirstResponder:lineField]) {
        [lineField selectText:nil];
    }

    NSModalResponse response = [alert runModal];
    if (response != NSAlertFirstButtonReturn) return;

    NSString *rawLineValue = [lineField.stringValue stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSScanner *scanner = [NSScanner scannerWithString:rawLineValue];
    NSInteger line = 0;
    if (rawLineValue.length == 0 || ![scanner scanInteger:&line] || !scanner.isAtEnd) {
        [self showAlert:@"Please enter a valid integer line number."];
        return;
    }

    if (line < 1 || line > (NSInteger)maxLines) {
        [self showAlert:[NSString stringWithFormat:@"Line number must be between 1 and %lu.", (unsigned long)maxLines]];
        return;
    }

    NSUInteger lineIndex = (NSUInteger)(line - 1);
    switch (panePopup.indexOfSelectedItem) {
        case 1:
            [self.leftTextView scrollToLine:lineIndex];
            self.statusLabel.stringValue = [NSString stringWithFormat:@"Jumped to line %ld in left pane", (long)line];
            break;
        case 2:
            [self.rightTextView scrollToLine:lineIndex];
            self.statusLabel.stringValue = [NSString stringWithFormat:@"Jumped to line %ld in right pane", (long)line];
            break;
        case 0:
        default:
            [self.leftTextView scrollToLine:lineIndex];
            [self.rightTextView scrollToLine:lineIndex];
            self.statusLabel.stringValue = [NSString stringWithFormat:@"Jumped to line %ld in both panes", (long)line];
            break;
    }
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
#if !__has_feature(objc_arc)
    [super dealloc];
#endif
}

- (BOOL)presentComparisonError:(NSError *)error {
    if (!error) return NO;

    NSWindow *window = self.view.window;
    if (window) {
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = @"Cannot compare selection";
        alert.informativeText = error.localizedDescription ?: @"Unknown error";
        [alert addButtonWithTitle:@"OK"];
        [alert beginSheetModalForWindow:window completionHandler:nil];
        return YES;
    }

    return [NSApp presentError:error];
}

- (void)displayComparisonError:(NSError *)error {
    if (!error) return;
    if (![self presentComparisonError:error]) {
        self.statusLabel.stringValue = error.localizedDescription ?: @"Unknown error";
        NSLog(@"Failed to present comparison error: %@", error.localizedDescription ?: error);
    }
}

#pragma mark - File Operations

- (void)saveLeftFile {
    if (!self.currentLeftPath) {
        [self showAlert:@"No left file to save"];
        return;
    }

    NSString *content = self.leftTextView.string;
    NSError *error = nil;
    BOOL success = [content writeToFile:self.currentLeftPath
                             atomically:YES
                               encoding:NSUTF8StringEncoding
                                  error:&error];

    if (success) {
        self.statusLabel.stringValue = [NSString stringWithFormat:@"Saved: %@",
            [self.currentLeftPath lastPathComponent]];
    } else {
        [self showAlert:[NSString stringWithFormat:@"Failed to save left file: %@",
            error.localizedDescription]];
    }
}

- (void)saveRightFile {
    if (!self.currentRightPath) {
        [self showAlert:@"No right file to save"];
        return;
    }

    NSString *content = self.rightTextView.string;
    NSError *error = nil;
    BOOL success = [content writeToFile:self.currentRightPath
                             atomically:YES
                               encoding:NSUTF8StringEncoding
                                  error:&error];

    if (success) {
        self.statusLabel.stringValue = [NSString stringWithFormat:@"Saved: %@",
            [self.currentRightPath lastPathComponent]];
    } else {
        [self showAlert:[NSString stringWithFormat:@"Failed to save right file: %@",
            error.localizedDescription]];
    }
}

- (void)showAlert:(NSString *)message {
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"File Operation";
    alert.informativeText = message;
    [alert addButtonWithTitle:@"OK"];
    [alert beginSheetModalForWindow:self.view.window completionHandler:nil];
}

#pragma mark - Merge Operations

- (void)copySelectionToLeft {
    NSRange selectedRange = self.rightTextView.selectedRange;
    if (selectedRange.length == 0) {
        [self showAlert:@"No text selected in right pane"];
        return;
    }

    NSString *selectedText = [self.rightTextView.string substringWithRange:selectedRange];

    // Replace the selected range in the left view, or insert at cursor if nothing selected
    NSRange leftRange = self.leftTextView.selectedRange;
    if (leftRange.length == 0 && leftRange.location < self.leftTextView.string.length) {
        // Insert at cursor
        [self.leftTextView insertText:selectedText replacementRange:leftRange];
    } else {
        // Replace selection
        [self.leftTextView insertText:selectedText replacementRange:leftRange];
    }

    self.statusLabel.stringValue = @"Copied selection to left";
}

- (void)copySelectionToRight {
    NSRange selectedRange = self.leftTextView.selectedRange;
    if (selectedRange.length == 0) {
        [self showAlert:@"No text selected in left pane"];
        return;
    }

    NSString *selectedText = [self.leftTextView.string substringWithRange:selectedRange];

    // Replace the selected range in the right view, or insert at cursor if nothing selected
    NSRange rightRange = self.rightTextView.selectedRange;
    if (rightRange.length == 0 && rightRange.location < self.rightTextView.string.length) {
        // Insert at cursor
        [self.rightTextView insertText:selectedText replacementRange:rightRange];
    } else {
        // Replace selection
        [self.rightTextView insertText:selectedText replacementRange:rightRange];
    }

    self.statusLabel.stringValue = @"Copied selection to right";
}

@end
