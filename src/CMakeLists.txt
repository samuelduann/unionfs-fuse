set(HASHTABLE_SRCS hashtable.c hashtable_itr.c)
set(UNIONFS_SRCS unionfs.c opts.c debug.c findbranch.c readdir.c
    general.c unlink.c cow.c cow_utils.c string.c rmdir.c usyslog.c
    fuse_ops.c)
set(UNIONFSCTL_SRCS unionfsctl.c)

SET(_COMMON_FLAGS "-pipe -W -Wall -D_FORTIFY_SOURCE=2 -D_FILE_OFFSET_BITS=64")
SET(CMAKE_C_FLAGS_RELWITHDEBINFO "-O2 -g ${_COMMON_FLAGS}")
SET(CMAKE_C_FLAGS_RELEASE "-O2 ${_COMMON_FLAGS}")
SET(CMAKE_C_FLAGS_DEBUG "-O0 -g -DDEBUG ${_COMMON_FLAGS}")

add_executable(unionfs ${UNIONFS_SRCS} ${HASHTABLE_SRCS})

option(WITH_LIBFUSE3 "Enable libfuse3 support" ON)

find_package(PkgConfig REQUIRED)

IF (WITH_LIBFUSE3)
	add_definitions(-DFUSE_USE_VERSION=35)
	pkg_check_modules(FUSE REQUIRED fuse3)
ELSE (WITH_LIBFUSE3)
	add_definitions(-DFUSE_USE_VERSION=29)
	pkg_check_modules(FUSE REQUIRED fuse)
	target_link_libraries(unionfs pthread)
ENDIF (WITH_LIBFUSE3)

target_include_directories(unionfs PUBLIC ${FUSE_INCLUDE_DIRS})
target_compile_options(unionfs PUBLIC ${FUSE_CFLAGS_OTHER})
target_link_libraries(unionfs ${FUSE_LIBRARIES})

if(BUILD_TESTING AND WITH_XATTR AND (HAVE_LIBC_XATTR OR HAVE_LIBATTR_XATTR))
    set(BADGE_TEST_SRCS ${UNIONFS_SRCS})
    list(REMOVE_ITEM BADGE_TEST_SRCS unionfs.c)
    add_executable(branch_badges_test ../tests/branch_badges.c ${BADGE_TEST_SRCS} ${HASHTABLE_SRCS})
    # Preserve system <string.h>; project headers use quoted includes.
    target_compile_options(branch_badges_test PRIVATE -iquote${CMAKE_CURRENT_SOURCE_DIR} -UNDEBUG ${FUSE_CFLAGS_OTHER})
    target_include_directories(branch_badges_test PRIVATE ${FUSE_INCLUDE_DIRS})
    target_link_libraries(branch_badges_test ${FUSE_LIBRARIES} pthread)
    add_test(NAME branch_badges COMMAND branch_badges_test)
endif()

add_executable(unionfsctl ${UNIONFSCTL_SRCS})

INSTALL(PROGRAMS ${CMAKE_CURRENT_BINARY_DIR}/unionfs DESTINATION bin)
INSTALL(PROGRAMS ${CMAKE_CURRENT_BINARY_DIR}/unionfsctl DESTINATION bin)
