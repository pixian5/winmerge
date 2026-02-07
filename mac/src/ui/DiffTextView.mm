/*
 * DiffTextView.mm - Custom Text View Implementation
 *
 * Provides line-number-aware scrolling and read-only text display
 * for diff results.
 */

#import "DiffTextView.h"

@implementation DiffTextView

- (instancetype)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.editable = NO;
        self.selectable = YES;
        self.richText = YES;
        self.usesFindBar = YES;
        self.font = [NSFont monospacedSystemFontOfSize:12 weight:NSFontWeightRegular];
        self.backgroundColor = [NSColor textBackgroundColor];
        self.textColor = [NSColor textColor];
        self.automaticQuoteSubstitutionEnabled = NO;
        self.automaticDashSubstitutionEnabled = NO;
        self.automaticTextReplacementEnabled = NO;
    }
    return self;
}

- (void)scrollToLine:(NSUInteger)lineNumber {
    NSString *text = self.string;
    if (text.length == 0) return;

    NSUInteger currentLine = 0;
    NSUInteger charIndex = 0;

    while (currentLine < lineNumber && charIndex < text.length) {
        NSRange lineRange = [text lineRangeForRange:NSMakeRange(charIndex, 0)];
        charIndex = NSMaxRange(lineRange);
        currentLine++;
    }

    if (charIndex < text.length) {
        NSRange lineRange = [text lineRangeForRange:NSMakeRange(charIndex, 0)];
        [self scrollRangeToVisible:lineRange];
        [self setSelectedRange:NSMakeRange(lineRange.location, 0)];
    }
}

@end
