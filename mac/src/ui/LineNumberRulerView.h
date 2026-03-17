/*
 * LineNumberRulerView.h - Line Number Ruler View
 *
 * Displays line numbers in the gutter for text views.
 */

#import <Cocoa/Cocoa.h>

@interface LineNumberRulerView : NSRulerView

- (instancetype)initWithScrollView:(NSScrollView *)scrollView;

@end
