/* Exercise the real FUSE callbacks without requiring a mounted filesystem. */
#include <assert.h>
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>
#include "opts.h"
#include "findbranch.h"

static int badge(const char *path, char *value, size_t size) {
#ifdef __APPLE__
    return unionfs_oper.getxattr(path, UNIONFS_BRANCH_BADGE_XATTR, value, size, 0);
#else
    return unionfs_oper.getxattr(path, UNIONFS_BRANCH_BADGE_XATTR, value, size);
#endif
}
static void expect(const char *path, const char *expected) {
    char value[32] = {0};
    assert(badge(path, NULL, 0) == (int)strlen(expected));
    assert(badge(path, value, sizeof(value)) == (int)strlen(expected));
    assert(strcmp(value, expected) == 0);
}
static void touch(const char *path) {
    FILE *file = fopen(path, "w");
    assert(file);
    assert(fclose(file) == 0);
}
int main(void) {
    char root[] = "/tmp/unionfs-badges-XXXXXX";
    assert(mkdtemp(root));
    assert(chdir(root) == 0);
    assert(mkdir("a", 0700) == 0);
    assert(mkdir("b", 0700) == 0);
    assert(mkdir("c", 0700) == 0);
    uopt_init();
    assert(parse_branches("a=rw:b=ro:c=ro") == 3);
    unionfs_post_opts();
    uopt.cow_enabled = true;

    touch("b/file");
    expect("/file", "2");
    touch("c/file");
    expect("/file", "2+");
    touch("a/file"); /* Copy-up changes both number and indicator. */
    expect("/file", "1+");
    assert(badge("/file", (char[1]){0}, 1) == -ERANGE);
    assert(unlink("a/file") == 0);
    expect("/file", "2+");
    assert(unlink("c/file") == 0);
    expect("/file", "2");
    assert(badge("/missing", NULL, 0) == -ENOENT);
    expect("/", "1+");

    assert(mkdir("a/dir", 0700) == 0);
    expect("/dir", "1");
    touch("c/dir"); /* A lower file is not a directory copy. */
    expect("/dir", "1");
    assert(mkdir("b/dir", 0700) == 0);
    expect("/dir", "1+");
    assert(rmdir("b/dir") == 0);
    expect("/dir", "1");
    assert(mkdir("b/dir", 0700) == 0);
    expect("/dir", "1+");
    assert(mkdir("c/file", 0700) == 0);
    expect("/file", "2"); /* A lower directory is not a file copy. */
    assert(rmdir("c/file") == 0);
    assert(symlink("missing-target", "c/file") == 0);
    expect("/file", "2+"); /* lstat, including dangling symlinks. */

    assert(mkdir("b/.unionfs", 0700) == 0);
    touch("b/.unionfs/file_HIDDEN~");
    expect("/file", "2"); /* Winning layer's whiteout blocks lower copies. */
    uopt.cow_enabled = false;
    expect("/file", "2+");
    uopt.cow_enabled = true;
    assert(unlink("b/.unionfs/file_HIDDEN~") == 0);
    assert(mkdir("a/.unionfs", 0700) == 0);
    touch("a/file");
    touch("b/.unionfs/file_HIDDEN~");
    expect("/file", "1+"); /* A match precedes its own whiteout. */
    assert(unlink("b/file") == 0);
    expect("/file", "1"); /* Intermediate whiteout blocks deeper match. */

    touch("a/dir/child");
    touch("b/dir/child");
    assert(mkdir("a/dir/nested", 0700) == 0);
    assert(mkdir("b/dir/nested", 0700) == 0);
    expect("/dir/nested", "1+");
    expect("/dir/child", "1+");
    touch("a/.unionfs/dir_HIDDEN~");
    expect("/dir", "1"); /* Folder whiteout suppresses lower directories. */
    expect("/dir/nested", "1");
    expect("/dir/child", "1"); /* Ancestor whiteout. */
    uopt.cow_enabled = false;
    expect("/dir", "1+");
    expect("/dir/nested", "1+");
    uopt.cow_enabled = true;

    touch("b/readonly");
#ifdef __APPLE__
    assert(unionfs_oper.setxattr("/readonly", UNIONFS_BRANCH_BADGE_XATTR, "9", 1, 0, 0) == -EPERM);
    assert(unionfs_oper.getxattr("/file", UNIONFS_BRANCH_BADGE_XATTR, NULL, 0, 1) == -EINVAL);
#else
    assert(unionfs_oper.setxattr("/readonly", UNIONFS_BRANCH_BADGE_XATTR, "9", 1, 0) == -EPERM);
#endif
    assert(unionfs_oper.removexattr("/readonly", UNIONFS_BRANCH_BADGE_XATTR) == -EPERM);
    assert(access("a/.unionfs/file_HIDDEN~", F_OK) != 0);
    assert(access("a/readonly", F_OK) != 0);
    expect("/readonly", "2");

    const char *files[] = {"b/readonly", "a/file", "c/file", "c/dir", "a/dir/child", "b/dir/child",
        "a/.unionfs/dir_HIDDEN~", "b/.unionfs/file_HIDDEN~"};
    for (size_t i = 0; i < sizeof(files) / sizeof(files[0]); i++) assert(unlink(files[i]) == 0);
    const char *dirs[] = {"a/dir/nested", "b/dir/nested", "a/dir", "b/dir", "a/.unionfs", "b/.unionfs", "a", "b", "c"};
    for (size_t i = 0; i < sizeof(dirs) / sizeof(dirs[0]); i++) assert(rmdir(dirs[i]) == 0);
    for (int i = 0; i < uopt.nbranches; i++) {
        close(uopt.branches[i].fd);
        free(uopt.branches[i].path);
    }
    free(uopt.branches);
    assert(chdir("/") == 0);
    assert(rmdir(root) == 0);
    puts("Branch badge callbacks: all checks passed");
    return 0;
}
