/*
 * DiffViewController.mm - Main Diff View Controller Implementation
 *
 * Creates the side-by-side comparison layout and drives the diff engine.
 */

#import "DiffViewController.h"
#import "DiffTextView.h"
#include "DiffEngine.h"
#include "FileOperations.h"
#include <memory>

@interface DiffViewController ()
@property (assign, nonatomic) int currentDiffIndex;
@property (assign, nonatomic) int totalDiffs;
@end

@implementation DiffViewController {
    std::unique_ptr<wm::DiffResult> _diffResult;
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

    // Status bar
    NSStackView *statusBar = [NSStackView stackViewWithViews:@[self.statusLabel]];
    statusBar.edgeInsets = NSEdgeInsetsMake(2, 8, 2, 8);

    // Main vertical stack
    NSStackView *mainStack = [NSStackView stackViewWithViews:@[headerStack, splitView, statusBar]];
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

    textView.minSize = NSMakeSize(0, 0);
    textView.maxSize = NSMakeSize(CGFLOAT_MAX, CGFLOAT_MAX);
    textView.verticallyResizable = YES;
    textView.horizontallyResizable = YES;
    textView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    textView.textContainer.containerSize = NSMakeSize(CGFLOAT_MAX, CGFLOAT_MAX);
    textView.textContainer.widthTracksTextView = NO;

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

    // Run the diff engine
    wm::DiffEngine engine;
    _diffResult = std::make_unique<wm::DiffResult>(
        engine.compareFiles(leftPath.UTF8String, rightPath.UTF8String)
    );

    self.totalDiffs = _diffResult->totalDiffs();
    self.currentDiffIndex = -1;

    // Display results
    [self displayDiffResult];

    // Update status
    if (_diffResult->identical) {
        self.statusLabel.stringValue = @"Files are identical";
    } else {
        self.statusLabel.stringValue =
            [NSString stringWithFormat:@"%d difference(s) found", self.totalDiffs];
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
}

@end
