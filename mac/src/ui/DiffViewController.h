/*
 * DiffViewController.h - Main Diff View Controller
 *
 * Manages the side-by-side file comparison view with diff highlighting.
 */

#import <Cocoa/Cocoa.h>

@class DiffTextView;

@interface DiffViewController : NSViewController

@property (strong, nonatomic) DiffTextView *leftTextView;
@property (strong, nonatomic) DiffTextView *rightTextView;
@property (strong, nonatomic) NSTextField *leftLabel;
@property (strong, nonatomic) NSTextField *rightLabel;
@property (strong, nonatomic) NSTextField *statusLabel;

// Compare two files and display the results
- (void)compareLeftFile:(NSString *)leftPath rightFile:(NSString *)rightPath;

// Navigate between differences
- (void)navigateToNextDiff;
- (void)navigateToPrevDiff;

@end
