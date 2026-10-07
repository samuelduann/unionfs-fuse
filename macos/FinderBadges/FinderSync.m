#import <AppKit/AppKit.h>
#import <FinderSync/FinderSync.h>
#include <string.h>
#include <sys/mount.h>
#include <sys/xattr.h>
#include "unionfs.h"

/* All filesystem work is serialized off the Finder callback thread. */
static NSString *ReadBadge(NSURL *url) {
    char value[32];
    ssize_t n = getxattr(url.fileSystemRepresentation, UNIONFS_BRANCH_BADGE_XATTR,
                         value, sizeof(value), 0, XATTR_NOFOLLOW);
    if (n <= 0 || n >= (ssize_t)sizeof(value)) return @"";
    NSString *badge = [[NSString alloc] initWithBytes:value length:(NSUInteger)n
                                            encoding:NSASCIIStringEncoding];
    if (!badge) return @"";
    NSRange match = [badge rangeOfString:@"^[1-9][0-9]*[+]?$"
                                options:NSRegularExpressionSearch];
    return match.location == 0 && match.length == badge.length ? badge : @"";
}

@interface UnionFSFinderSync : FIFinderSync
@property dispatch_queue_t worker;
@property NSMutableSet<NSURL *> *requested;
@property NSMutableDictionary<NSURL *, NSString *> *displayed;
@property NSMutableSet<NSString *> *registered;
@property NSTimer *timer;
@property BOOL refreshing;
@end

@implementation UnionFSFinderSync
- (instancetype)init {
    self = [super init];
    if (self) {
        _worker = dispatch_queue_create("org.unionfs-fuse.badges.lookup", DISPATCH_QUEUE_SERIAL);
        _requested = [NSMutableSet set];
        _displayed = [NSMutableDictionary dictionary];
        _registered = [NSMutableSet set];
        [FIFinderSyncController defaultController].directoryURLs = [NSSet set];
        __weak UnionFSFinderSync *weakSelf = self;
        _timer = [NSTimer scheduledTimerWithTimeInterval:3 repeats:YES block:^(NSTimer *timer) {
            (void)timer;
            [weakSelf refresh];
        }];
        [self refresh];
    }
    return self;
}

- (void)applyBadge:(NSString *)badge toURL:(NSURL *)url {
    FIFinderSyncController *controller = [FIFinderSyncController defaultController];
    if (badge.length && ![self.registered containsObject:badge]) {
        NSImage *image = [[NSImage alloc] initWithSize:NSMakeSize(64, 64)];
        [image lockFocus];
        [[NSColor colorWithSRGBRed:0.12 green:0.35 blue:0.78 alpha:1] setFill];
        [[NSBezierPath bezierPathWithOvalInRect:NSMakeRect(0, 0, 64, 64)] fill];
        CGFloat fontSize = MIN(42.0, 88.0 / badge.length);
        NSDictionary *attributes = @{
            NSFontAttributeName: [NSFont boldSystemFontOfSize:fontSize],
            NSForegroundColorAttributeName: NSColor.whiteColor
        };
        NSSize size = [badge sizeWithAttributes:attributes];
        [badge drawAtPoint:NSMakePoint((64 - size.width) / 2, (64 - size.height) / 2)
            withAttributes:attributes];
        [image unlockFocus];
        [controller setBadgeImage:image label:badge forBadgeIdentifier:badge];
        [self.registered addObject:badge];
    }
    if (![self.displayed[url] isEqualToString:badge]) {
        [controller setBadgeIdentifier:badge forURL:url];
        self.displayed[url] = badge;
    }
}

/* Finder calls these on its own thread; hop to the main queue, which owns
 * requested/displayed/registered.
 */
- (void)requestBadgeIdentifierForURL:(NSURL *)url {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.requested addObject:url];
        dispatch_async(self.worker, ^{
            NSString *badge = ReadBadge(url);
            dispatch_async(dispatch_get_main_queue(), ^{
                if ([self.requested containsObject:url]) [self applyBadge:badge toURL:url];
            });
        });
    });
}

- (void)endObservingDirectoryAtURL:(NSURL *)url {
    NSString *dir = url.path;
    dispatch_async(dispatch_get_main_queue(), ^{
        for (NSURL *item in self.requested.allObjects) {
            if ([item.URLByDeletingLastPathComponent.path isEqualToString:dir]) {
                [self.requested removeObject:item];
                [self.displayed removeObjectForKey:item];
            }
        }
    });
}

/* Poll only requested items, including lower-layer changes that don't generate
 * notifications on the union mount. Discover mounts without user configuration.
 */
- (void)refresh {
    if (self.refreshing) return;
    self.refreshing = YES;
    NSArray<NSURL *> *items = self.requested.allObjects;
    dispatch_async(self.worker, ^{
        NSMutableSet<NSURL *> *roots = [NSMutableSet set];
        struct statfs *mounts;
        int count = getmntinfo(&mounts, MNT_NOWAIT);
        for (int i = 0; i < count; i++) {
            if (!strstr(mounts[i].f_fstypename, "fuse")) continue;
            NSURL *root = [NSURL fileURLWithFileSystemRepresentation:mounts[i].f_mntonname
                                                       isDirectory:YES relativeToURL:nil];
            if (ReadBadge(root).length) [roots addObject:root];
        }
        NSMutableDictionary<NSURL *, NSString *> *values = [NSMutableDictionary dictionary];
        for (NSURL *url in items) values[url] = ReadBadge(url);
        dispatch_async(dispatch_get_main_queue(), ^{
            FIFinderSyncController *controller = [FIFinderSyncController defaultController];
            if (![controller.directoryURLs isEqualToSet:roots]) controller.directoryURLs = roots;
            for (NSURL *url in items) {
                if ([self.requested containsObject:url]) [self applyBadge:values[url] toURL:url];
            }
            self.refreshing = NO;
        });
    });
}
@end
