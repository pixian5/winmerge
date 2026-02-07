/*
 * DiffTextView.h - Custom Text View with Diff Highlighting
 *
 * A specialized NSTextView that supports line number display
 * and diff-aware scrolling.
 */

#import <Cocoa/Cocoa.h>

@interface DiffTextView : NSTextView

// Scroll to a specific line number
- (void)scrollToLine:(NSUInteger)lineNumber;

@end
