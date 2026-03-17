/*
 * LineNumberRulerView.mm - Line Number Ruler View Implementation
 *
 * Displays line numbers in the gutter alongside text content.
 */

#import "LineNumberRulerView.h"

@implementation LineNumberRulerView

- (instancetype)initWithScrollView:(NSScrollView *)scrollView {
    self = [super initWithScrollView:scrollView orientation:NSRulerViewOrientationVertical];
    if (self) {
        self.clientView = scrollView.documentView;
        self.ruleThickness = 40.0;
    }
    return self;
}

- (void)drawHashMarksAndLabelsInRect:(NSRect)rect {
    NSTextView *textView = (NSTextView *)self.clientView;
    if (![textView isKindOfClass:[NSTextView class]]) {
        return;
    }

    NSString *text = textView.string;
    if (text.length == 0) {
        return;
    }

    NSLayoutManager *layoutManager = textView.layoutManager;
    NSTextContainer *textContainer = textView.textContainer;

    // Background
    [[NSColor colorWithWhite:0.95 alpha:1.0] setFill];
    NSRectFill(rect);

    // Right border line
    [[NSColor colorWithWhite:0.8 alpha:1.0] setStroke];
    NSBezierPath *path = [NSBezierPath bezierPath];
    [path moveToPoint:NSMakePoint(self.ruleThickness - 0.5, NSMinY(rect))];
    [path lineToPoint:NSMakePoint(self.ruleThickness - 0.5, NSMaxY(rect))];
    [path setLineWidth:1.0];
    [path stroke];

    // Get visible rect
    NSRect visibleRect = [[self.scrollView contentView] bounds];
    NSRange glyphRange = [layoutManager glyphRangeForBoundingRect:visibleRect
                                                    inTextContainer:textContainer];
    NSRange charRange = [layoutManager characterRangeForGlyphRange:glyphRange
                                                   actualGlyphRange:NULL];

    // Count lines and draw line numbers
    NSUInteger lineNumber = 1;
    NSUInteger charIndex = 0;

    // Count lines before visible range
    while (charIndex < charRange.location && charIndex < text.length) {
        NSRange lineRange = [text lineRangeForRange:NSMakeRange(charIndex, 0)];
        charIndex = NSMaxRange(lineRange);
        lineNumber++;
    }

    // Draw line numbers for visible lines
    charIndex = charRange.location;
    NSUInteger endChar = NSMaxRange(charRange);

    NSDictionary *attrs = @{
        NSFontAttributeName: [NSFont systemFontOfSize:11],
        NSForegroundColorAttributeName: [NSColor grayColor]
    };

    while (charIndex < endChar && charIndex < text.length) {
        NSRange lineRange = [text lineRangeForRange:NSMakeRange(charIndex, 0)];

        // Get the glyph range for this line
        NSRange lineGlyphRange = [layoutManager glyphRangeForCharacterRange:lineRange
                                                       actualCharacterRange:NULL];

        // Get the bounding rect for the first glyph in the line
        NSRect lineRect = [layoutManager boundingRectForGlyphRange:NSMakeRange(lineGlyphRange.location, 1)
                                                    inTextContainer:textContainer];

        // Adjust for text view's text container inset
        lineRect.origin.x += textView.textContainerOrigin.x;
        lineRect.origin.y += textView.textContainerOrigin.y;

        // Convert to ruler view coordinates
        NSPoint linePoint = [self convertPoint:lineRect.origin fromView:textView];

        // Draw line number
        NSString *lineNumberString = [NSString stringWithFormat:@"%lu", (unsigned long)lineNumber];
        NSSize stringSize = [lineNumberString sizeWithAttributes:attrs];

        NSPoint drawPoint = NSMakePoint(
            self.ruleThickness - stringSize.width - 5.0,
            linePoint.y
        );

        [lineNumberString drawAtPoint:drawPoint withAttributes:attrs];

        charIndex = NSMaxRange(lineRange);
        lineNumber++;
    }
}

@end
