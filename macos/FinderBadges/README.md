# Finder branch badges

The optional macOS Finder Sync extension displays `1`, `2`, etc. for the
highest-priority branch containing an item. Branch 1 is the first branch in the
mount command. Files receive `+` when at least one lower non-directory entry
exists at the same path. Folders receive `+` when the same directory exists in
an eligible lower branch, including empty directories. A lower file does not
count as a folder copy, or vice versa. The indicator does not require that the
lower folder contributes unique visible children. Contents are not compared;
this is not version history.
Whiteouts (including ancestor whiteouts) exclude suppressed lower entries when
copy-on-write is enabled. Symlinks are inspected without following the final link.

## Build and enable

Requires macOS 11 or later, Apple Command Line Tools, and macFUSE.
From the repository root:

```sh
cmake -S . -B build -DWITH_XATTR=ON
cmake --build build
ctest --test-dir build --output-on-failure
./macos/FinderBadges/build.sh
open 'build/finder-badges/UnionFS Finder Badges.app'
```

The app opens Finder extension settings when you click **Manage Finder
Extensions**. Enable **UnionFS Finder Badges** there. Keep the app bundle in a
stable location (you can copy it to Applications before opening it).
The build script signs locally with an ad-hoc identity; set `SIGN_IDENTITY` to a
signing certificate for a signed distribution. It does not install or enable the
extension automatically. Managed macOS policies may require a trusted signature.

Existing mounts keep running their old unionfs process. Unmount and remount them
using `build/src/unionfs` before expecting badges. Preserve your existing branch
order and mount options. Mounts must expose extended attributes.

Mounts are discovered automatically by probing FUSE mount roots for the badge
attribute. The extension checks requested items every three seconds, so changes
to lower branches are also reflected. Slow backing storage can delay refreshes;
filesystem reads run on a serial background queue. Closing a directory removes
its requested items from the refresh set. Finder controls the badge's placement
and may vary presentation between view modes or when other extensions compete.

The sandboxed extension has a read-only filesystem exception because union
mounts can be anywhere, including outside `/Volumes`. It reads only the computed
badge attribute on FUSE roots and items requested by Finder. It has no filesystem
write or network entitlement. This local-development entitlement setup is not an
App Store distribution configuration.

## Metadata interface

With xattr support enabled, unionfs serves `user.unionfs.branch-badge` on demand.
Its ASCII value is the one-based branch number and optional `+`, without a NUL
terminator. The attribute is virtual, not stored on backing files, and is queried
by name (it is not added to `listxattr` output). Attempts to set or remove it fail
with `EPERM` before any copy-on-write work. Other attributes retain their existing
behavior. Unreadable lower entries produce an error rather than a false no-copy
badge; the extension clears badges when the query fails.

```sh
xattr -p user.unionfs.branch-badge /path/to/mount/file
```

The callback tests exercise number changes, copy presence, directories,
file/directory conflicts, dangling symlinks, whiteouts, buffer sizing, and
read-only enforcement without requiring a mounted filesystem.
