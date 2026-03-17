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
#include <memory>

static NSString * const kWMDiffErrorDomain = @"org.winmerge.mac";
static const NSInteger kWMDiffErrorMissingFile = 1;
static const NSInteger kWMDiffErrorFolderUnsupported = 2;

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

    self.currentLeftPath = leftPath;
    self.currentRightPath = rightPath;

    if (![self validatePathsAreFiles:leftPath right:rightPath]) {
        return;
    }

    [self runDiffForCurrentPaths];
}

- (BOOL)validatePathsAreFiles:(NSString *)leftPath right:(NSString *)rightPath {
    auto leftExists = wm::FileOps::fileExists(leftPath.UTF8String);
    auto rightExists = wm::FileOps::fileExists(rightPath.UTF8String);

    if (!leftExists || !rightExists) {
        NSError *error = [NSError errorWithDomain:kWMDiffErrorDomain
                                             code:kWMDiffErrorMissingFile
                                         userInfo:@{ NSLocalizedDescriptionKey :
                                                     [NSString stringWithFormat:@"One or both files do not exist:\n%@\n%@", leftPath, rightPath]}];
        [self presentError:error];
        return NO;
    }

    if (wm::FileOps::isDirectory(leftPath.UTF8String) ||
        wm::FileOps::isDirectory(rightPath.UTF8String)) {
        NSError *error = [NSError errorWithDomain:kWMDiffErrorDomain
                                             code:kWMDiffErrorFolderUnsupported
                                         userInfo:@{ NSLocalizedDescriptionKey :
                                                     @"Folder comparison is not yet available on macOS. Please select two files." }];
        [self presentError:error];
        return NO;
    }

    return YES;
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

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
#if !__has_feature(objc_arc)
    [super dealloc];
#endif
}

- (BOOL)presentError:(NSError *)error {
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
