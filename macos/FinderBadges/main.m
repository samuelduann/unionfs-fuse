#import <AppKit/AppKit.h>
#import <FinderSync/FinderSync.h>

int main(void) {
    @autoreleasepool {
        [NSApplication sharedApplication];
        [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
        [NSApp activateIgnoringOtherApps:YES];
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = @"UnionFS Finder Badges";
        alert.informativeText = @"Enable UnionFS Finder Badges in Finder Extensions, then browse a unionfs mount. A badge such as 2 identifies branch 2; 2+ means a file or folder also exists in an eligible lower branch. Mounts must use the updated unionfs binary with extended attributes enabled.";
        [alert addButtonWithTitle:@"Manage Finder Extensions"];
        [alert addButtonWithTitle:@"Close"];
        if ([alert runModal] == NSAlertFirstButtonReturn)
            [FIFinderSyncController showExtensionManagementInterface];
    }
    return 0;
}
