/*
 * AppDelegate.h - macOS Application Delegate
 *
 * Manages application lifecycle and the main menu for WinMerge macOS.
 */

#import <Cocoa/Cocoa.h>

@class DiffViewController;

@interface AppDelegate : NSObject <NSApplicationDelegate>

@property (strong, nonatomic) NSWindow *window;
@property (strong, nonatomic) DiffViewController *diffViewController;

- (void)openFiles:(id)sender;
- (void)nextDiff:(id)sender;
- (void)prevDiff:(id)sender;

@end
