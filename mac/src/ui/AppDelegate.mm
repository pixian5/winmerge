/*
 * AppDelegate.mm - macOS Application Delegate Implementation
 *
 * Sets up the main window, menu bar, and coordinates file comparison.
 */

#import "AppDelegate.h"
#import "DiffViewController.h"
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    [self setupMainMenu];
    [self setupMainWindow];

    // If files were passed as command-line arguments, compare them
    NSArray *args = [[NSProcessInfo processInfo] arguments];
    if (args.count >= 3) {
        NSString *leftPath = args[1];
        NSString *rightPath = args[2];
        [self.diffViewController compareLeftFile:leftPath rightFile:rightPath];
    }
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
    return YES;
}

#pragma mark - Window Setup

- (void)setupMainWindow {
    NSRect frame = NSMakeRect(100, 100, 1200, 700);
    NSWindowStyleMask style = NSWindowStyleMaskTitled
        | NSWindowStyleMaskClosable
        | NSWindowStyleMaskMiniaturizable
        | NSWindowStyleMaskResizable;

    self.window = [[NSWindow alloc] initWithContentRect:frame
                                              styleMask:style
                                                backing:NSBackingStoreBuffered
                                                  defer:NO];
    self.window.title = @"WinMerge";
    self.window.minSize = NSMakeSize(600, 400);

    self.diffViewController = [[DiffViewController alloc] init];
    self.window.contentViewController = self.diffViewController;

    [self.window center];
    [self.window makeKeyAndOrderFront:nil];
}

#pragma mark - Menu Setup

- (void)setupMainMenu {
    NSMenu *mainMenu = [[NSMenu alloc] init];

    // Application menu
    NSMenuItem *appMenuItem = [[NSMenuItem alloc] init];
    NSMenu *appMenu = [[NSMenu alloc] initWithTitle:@"WinMerge"];
    [appMenu addItemWithTitle:@"About WinMerge"
                       action:@selector(orderFrontStandardAboutPanel:)
                keyEquivalent:@""];
    [appMenu addItem:[NSMenuItem separatorItem]];
    [appMenu addItemWithTitle:@"Quit WinMerge"
                       action:@selector(terminate:)
                keyEquivalent:@"q"];
    appMenuItem.submenu = appMenu;
    [mainMenu addItem:appMenuItem];

    // File menu
    NSMenuItem *fileMenuItem = [[NSMenuItem alloc] init];
    NSMenu *fileMenu = [[NSMenu alloc] initWithTitle:@"File"];
    [fileMenu addItemWithTitle:@"Open Files…"
                        action:@selector(openFiles:)
                 keyEquivalent:@"o"];
    [fileMenu addItem:[NSMenuItem separatorItem]];
    [fileMenu addItemWithTitle:@"Close Window"
                        action:@selector(performClose:)
                 keyEquivalent:@"w"];
    fileMenuItem.submenu = fileMenu;
    [mainMenu addItem:fileMenuItem];

    // Navigate menu
    NSMenuItem *navMenuItem = [[NSMenuItem alloc] init];
    NSMenu *navMenu = [[NSMenu alloc] initWithTitle:@"Navigate"];

    NSMenuItem *nextItem = [[NSMenuItem alloc] initWithTitle:@"Next Difference"
                                                      action:@selector(nextDiff:)
                                               keyEquivalent:@""];
    nextItem.keyEquivalent = [NSString stringWithFormat:@"%C", (unichar)NSDownArrowFunctionKey];
    nextItem.keyEquivalentModifierMask = NSEventModifierFlagCommand;
    [navMenu addItem:nextItem];

    NSMenuItem *prevItem = [[NSMenuItem alloc] initWithTitle:@"Previous Difference"
                                                      action:@selector(prevDiff:)
                                               keyEquivalent:@""];
    prevItem.keyEquivalent = [NSString stringWithFormat:@"%C", (unichar)NSUpArrowFunctionKey];
    prevItem.keyEquivalentModifierMask = NSEventModifierFlagCommand;
    [navMenu addItem:prevItem];

    navMenuItem.submenu = navMenu;
    [mainMenu addItem:navMenuItem];

    // Window menu
    NSMenuItem *windowMenuItem = [[NSMenuItem alloc] init];
    NSMenu *windowMenu = [[NSMenu alloc] initWithTitle:@"Window"];
    [windowMenu addItemWithTitle:@"Minimize"
                          action:@selector(performMiniaturize:)
                   keyEquivalent:@"m"];
    [windowMenu addItemWithTitle:@"Zoom"
                          action:@selector(performZoom:)
                   keyEquivalent:@""];
    windowMenuItem.submenu = windowMenu;
    [mainMenu addItem:windowMenuItem];
    [NSApp setWindowsMenu:windowMenu];

    [NSApp setMainMenu:mainMenu];
}

#pragma mark - Actions

- (void)openFiles:(id)sender {
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    panel.canChooseFiles = YES;
    panel.canChooseDirectories = NO;
    panel.allowsMultipleSelection = YES;
    panel.message = @"Select two files to compare";
    panel.allowedContentTypes = @[UTTypeText, UTTypePlainText, UTTypeSourceCode];

    [panel beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse result) {
        if (result == NSModalResponseOK && panel.URLs.count >= 2) {
            NSString *leftPath = panel.URLs[0].path;
            NSString *rightPath = panel.URLs[1].path;
            [self.diffViewController compareLeftFile:leftPath rightFile:rightPath];
        }
    }];
}

- (void)nextDiff:(id)sender {
    [self.diffViewController navigateToNextDiff];
}

- (void)prevDiff:(id)sender {
    [self.diffViewController navigateToPrevDiff];
}

@end
