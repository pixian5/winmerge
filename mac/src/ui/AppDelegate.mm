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
    if (args.count >= 4) {
        NSString *basePath = args[1];
        NSString *leftPath = args[2];
        NSString *rightPath = args[3];
        [self.diffViewController mergeBaseFile:basePath leftFile:leftPath rightFile:rightPath];
    } else if (args.count >= 3) {
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
    [fileMenu addItemWithTitle:@"Open 3-Way Merge…"
                        action:@selector(openThreeWayMerge:)
                 keyEquivalent:@"O"];
    [fileMenu addItem:[NSMenuItem separatorItem]];
    [fileMenu addItemWithTitle:@"Save Left File"
                        action:@selector(saveLeftFile:)
                 keyEquivalent:@"s"];
    [fileMenu addItemWithTitle:@"Save Right File"
                        action:@selector(saveRightFile:)
                 keyEquivalent:@"S"];
    [fileMenu addItem:[NSMenuItem separatorItem]];
    [fileMenu addItemWithTitle:@"Close Window"
                        action:@selector(performClose:)
                 keyEquivalent:@"w"];
    fileMenuItem.submenu = fileMenu;
    [mainMenu addItem:fileMenuItem];

    // Edit menu
    NSMenuItem *editMenuItem = [[NSMenuItem alloc] init];
    NSMenu *editMenu = [[NSMenu alloc] initWithTitle:@"Edit"];
    [editMenu addItemWithTitle:@"Copy"
                        action:@selector(copy:)
                 keyEquivalent:@"c"];
    [editMenu addItemWithTitle:@"Select All"
                        action:@selector(selectAll:)
                 keyEquivalent:@"a"];
    [editMenu addItem:[NSMenuItem separatorItem]];
    [editMenu addItemWithTitle:@"Find…"
                        action:@selector(performFindPanelAction:)
                 keyEquivalent:@"f"];
    [editMenu addItemWithTitle:@"Find Next"
                        action:@selector(performFindPanelAction:)
                 keyEquivalent:@"g"];
    [editMenu addItemWithTitle:@"Find Previous"
                        action:@selector(performFindPanelAction:)
                 keyEquivalent:@"G"];
    [editMenu addItem:[NSMenuItem separatorItem]];
    [editMenu addItemWithTitle:@"Go to Line…"
                        action:@selector(goToLine:)
                 keyEquivalent:@"l"];
    editMenuItem.submenu = editMenu;
    [mainMenu addItem:editMenuItem];
    [NSApp setServicesMenu:editMenu];

    // Navigate menu
    NSMenuItem *navMenuItem = [[NSMenuItem alloc] init];
    NSMenu *navMenu = [[NSMenu alloc] initWithTitle:@"Navigate"];

    NSMenuItem *nextItem = [[NSMenuItem alloc] initWithTitle:@"Next Difference"
                                                      action:@selector(nextDiff:)
                                               keyEquivalent:@""];
    nextItem.keyEquivalent = [NSString stringWithFormat:@"%C", (unichar)NSDownArrowFunctionKey];
    nextItem.keyEquivalentModifierMask = NSEventModifierFlagCommand;
    [navMenu addItem:nextItem];
    NSMenuItem *nextConflictItem = [[NSMenuItem alloc] initWithTitle:@"Next Conflict"
                                                              action:@selector(nextConflict:)
                                                       keyEquivalent:@""];
    nextConflictItem.keyEquivalent = [NSString stringWithFormat:@"%C", (unichar)NSDownArrowFunctionKey];
    nextConflictItem.keyEquivalentModifierMask = NSEventModifierFlagCommand | NSEventModifierFlagShift;
    [navMenu addItem:nextConflictItem];

    NSMenuItem *prevItem = [[NSMenuItem alloc] initWithTitle:@"Previous Difference"
                                                      action:@selector(prevDiff:)
                                               keyEquivalent:@""];
    prevItem.keyEquivalent = [NSString stringWithFormat:@"%C", (unichar)NSUpArrowFunctionKey];
    prevItem.keyEquivalentModifierMask = NSEventModifierFlagCommand;
    [navMenu addItem:prevItem];
    NSMenuItem *prevConflictItem = [[NSMenuItem alloc] initWithTitle:@"Previous Conflict"
                                                              action:@selector(prevConflict:)
                                                       keyEquivalent:@""];
    prevConflictItem.keyEquivalent = [NSString stringWithFormat:@"%C", (unichar)NSUpArrowFunctionKey];
    prevConflictItem.keyEquivalentModifierMask = NSEventModifierFlagCommand | NSEventModifierFlagShift;
    [navMenu addItem:prevConflictItem];

    navMenuItem.submenu = navMenu;
    [mainMenu addItem:navMenuItem];

    // Merge menu
    NSMenuItem *mergeMenuItem = [[NSMenuItem alloc] init];
    NSMenu *mergeMenu = [[NSMenu alloc] initWithTitle:@"Merge"];
    [mergeMenu addItemWithTitle:@"Copy Selection to Right"
                         action:@selector(copyToRight:)
                  keyEquivalent:@"]"];
    [mergeMenu addItemWithTitle:@"Copy Selection to Left"
                         action:@selector(copyToLeft:)
                  keyEquivalent:@"["];
    NSMenuItem *takeLeft = [[NSMenuItem alloc] initWithTitle:@"Take Current Conflict From Left"
                                                      action:@selector(takeConflictFromLeft:)
                                               keyEquivalent:@"["];
    takeLeft.keyEquivalentModifierMask = NSEventModifierFlagCommand | NSEventModifierFlagOption;
    [mergeMenu addItem:takeLeft];
    NSMenuItem *takeRight = [[NSMenuItem alloc] initWithTitle:@"Take Current Conflict From Right"
                                                       action:@selector(takeConflictFromRight:)
                                                keyEquivalent:@"]"];
    takeRight.keyEquivalentModifierMask = NSEventModifierFlagCommand | NSEventModifierFlagOption;
    [mergeMenu addItem:takeRight];
    NSMenuItem *takeBase = [[NSMenuItem alloc] initWithTitle:@"Take Current Conflict From Base"
                                                      action:@selector(takeConflictFromBase:)
                                               keyEquivalent:@"b"];
    takeBase.keyEquivalentModifierMask = NSEventModifierFlagCommand | NSEventModifierFlagOption;
    [mergeMenu addItem:takeBase];
    [mergeMenu addItem:[NSMenuItem separatorItem]];
    [mergeMenu addItemWithTitle:@"Open Selected Folder Item Diff"
                         action:@selector(openSelectedFolderItemDiff:)
                  keyEquivalent:@"\r"];
    mergeMenuItem.submenu = mergeMenu;
    [mainMenu addItem:mergeMenuItem];

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
    panel.canChooseDirectories = YES;
    panel.allowsMultipleSelection = YES;
    panel.message = @"Select two files or two folders to compare";
    panel.allowedContentTypes = nil;

    [panel beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse result) {
        if (result == NSModalResponseOK && panel.URLs.count >= 2) {
            NSString *leftPath = panel.URLs[0].path;
            NSString *rightPath = panel.URLs[1].path;
            [self.diffViewController compareLeftFile:leftPath rightFile:rightPath];
        }
    }];
}

- (void)openThreeWayMerge:(id)sender {
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    panel.canChooseFiles = YES;
    panel.canChooseDirectories = NO;
    panel.allowsMultipleSelection = YES;
    panel.message = @"Select base, left, and right files for 3-way merge";
    panel.allowedContentTypes = @[UTTypeText, UTTypePlainText, UTTypeSourceCode];

    [panel beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse result) {
        if (result == NSModalResponseOK && panel.URLs.count >= 3) {
            NSString *basePath = panel.URLs[0].path;
            NSString *leftPath = panel.URLs[1].path;
            NSString *rightPath = panel.URLs[2].path;
            [self.diffViewController mergeBaseFile:basePath leftFile:leftPath rightFile:rightPath];
        }
    }];
}

- (void)nextDiff:(id)sender {
    [self.diffViewController navigateToNextDiff];
}

- (void)prevDiff:(id)sender {
    [self.diffViewController navigateToPrevDiff];
}

- (void)goToLine:(id)sender {
    [self.diffViewController presentGoToLineDialog];
}

- (void)nextConflict:(id)sender {
    [self.diffViewController navigateToNextConflict];
}

- (void)prevConflict:(id)sender {
    [self.diffViewController navigateToPrevConflict];
}

- (void)saveLeftFile:(id)sender {
    [self.diffViewController saveLeftFile];
}

- (void)saveRightFile:(id)sender {
    [self.diffViewController saveRightFile];
}

- (void)copyToLeft:(id)sender {
    [self.diffViewController copySelectionToLeft];
}

- (void)copyToRight:(id)sender {
    [self.diffViewController copySelectionToRight];
}

- (void)takeConflictFromLeft:(id)sender {
    [self.diffViewController takeCurrentConflictFromLeft];
}

- (void)takeConflictFromRight:(id)sender {
    [self.diffViewController takeCurrentConflictFromRight];
}

- (void)takeConflictFromBase:(id)sender {
    [self.diffViewController takeCurrentConflictFromBase];
}

- (void)openSelectedFolderItemDiff:(id)sender {
    [self.diffViewController openSelectedFolderItemComparison];
}

@end
