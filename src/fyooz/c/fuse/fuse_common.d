module fyooz.c.fuse.fuse_common;
/*
  FUSE: Filesystem in Userspace
  Copyright (C) 2001-2007  Miklos Szeredi <miklos@szeredi.hu>

  This program can be distributed under the terms of the GNU LGPLv2.
  See the file COPYING.LIB.
*/

public import fyooz.c.fuse.fuse_opt;

import core.stdc.config;
import core.sys.posix.sys.types;
import core.sys.posix.time;

import std.bitmanip;

extern (System) nothrow __gshared:

/*
 * Copyright (c) 2006-2008 Amit Singh/Google Inc.
 * Copyright (c) 2011-2012 Benjamin Fleischer
 */

/** @file */

/** Major version of FUSE library interface */
enum FUSE_MAJOR_VERSION = 2;

/** Minor version of FUSE library interface */
enum FUSE_MINOR_VERSION = 9;

extern (D) auto FUSE_MAKE_VERSION(T0, T1)(auto ref T0 maj, auto ref T1 min)
{
    return maj * 10 + min;
}

enum FUSE_VERSION = FUSE_MAKE_VERSION(FUSE_MAJOR_VERSION, FUSE_MINOR_VERSION);

/* This interface uses 64 bit off_t */

/* The following bits must be in lockstep with those in fuse_lowlevel.h */

extern (D) auto SETATTR_WANTS_MODE(T)(auto ref T attr)
{
    return attr.valid & (1 << 0);
}

extern (D) auto SETATTR_WANTS_UID(T)(auto ref T attr)
{
    return attr.valid & (1 << 1);
}

extern (D) auto SETATTR_WANTS_GID(T)(auto ref T attr)
{
    return attr.valid & (1 << 2);
}

extern (D) auto SETATTR_WANTS_SIZE(T)(auto ref T attr)
{
    return attr.valid & (1 << 3);
}

extern (D) auto SETATTR_WANTS_ACCTIME(T)(auto ref T attr)
{
    return attr.valid & (1 << 4);
}

extern (D) auto SETATTR_WANTS_MODTIME(T)(auto ref T attr)
{
    return attr.valid & (1 << 5);
}

extern (D) auto SETATTR_WANTS_CRTIME(T)(auto ref T attr)
{
    return attr.valid & (1 << 28);
}

extern (D) auto SETATTR_WANTS_CHGTIME(T)(auto ref T attr)
{
    return attr.valid & (1 << 29);
}

extern (D) auto SETATTR_WANTS_BKUPTIME(T)(auto ref T attr)
{
    return attr.valid & (1 << 30);
}

extern (D) auto SETATTR_WANTS_FLAGS(T)(auto ref T attr)
{
    return attr.valid & (1 << 31);
}

struct setattr_x
{
    int valid;
    mode_t mode;
    uid_t uid;
    gid_t gid;
    off_t size;
    timespec acctime;
    timespec modtime;
    timespec crtime;
    timespec chgtime;
    timespec bkuptime;
    uint flags;
}

/* __APPLE__ */

/**
 * Information about open files
 *
 * Changed in version 2.5
 */
struct fuse_file_info
{
    /** Open flags.	 Available in open() and release() */
    int flags;

    /** Old file handle, don't use */
    c_ulong fh_old;

    /** In case of a write operation indicates if this was caused by a
    	    writepage */
    int writepage;

    mixin(bitfields!(uint, "_direct_io", 1, uint, "_keep_cache", 1, uint,
            "_flush", 1, uint, "_nonseekable", 1, uint, "_flock_release", 1, uint,
            "_padding", 25, uint, "_purge_attr", 1, uint, "_purge_ubc", 1));
    // TODO wrapper properties so we keep docs.
    //    /** Can be filled in by open, to use direct I/O on this file.
    //    	    Introduced in version 2.4 */
    //    uint direct_io;
    //
    //    /** Can be filled in by open, to indicate, that cached file data
    //    	    need not be invalidated.  Introduced in version 2.4 */
    //    uint keep_cache;
    //
    //    /** Indicates a flush operation.  Set in flush operation, also
    //    	    maybe set in highlevel lock operation and lowlevel release
    //    	    operation.	Introduced in version 2.6 */
    //    uint flush;
    //
    //    /** Can be filled in by open, to indicate that the file is not
    //    	    seekable.  Introduced in version 2.8 */
    //    uint nonseekable;
    //
    //    /* Indicates that flock locks for this file should be
    //    	   released.  If set, lock_owner shall contain a valid value.
    //    	   May only be set in ->release().  Introduced in version
    //    	   2.9 */
    //    uint flock_release;
    //
    //    /** Padding.  Do not use*/
    //    uint padding;
    //    uint purge_attr;
    //    uint purge_ubc;
    //    /* !__APPLE__ */
    //    /** Padding.  Do not use*/
    //
    //    /* __APPLE__ */

    /** File handle.  May be filled in by filesystem in open().
    	    Available in all other file operations */
    ulong fh;

    /** Lock owner id.  Available in locking operations and flush */
    ulong lock_owner;
}

/**
 * Capability bits for 'fuse_conn_info.capable' and 'fuse_conn_info.want'
 *
 * FUSE_CAP_ASYNC_READ: filesystem supports asynchronous read requests
 * FUSE_CAP_POSIX_LOCKS: filesystem supports "remote" locking
 * FUSE_CAP_ATOMIC_O_TRUNC: filesystem handles the O_TRUNC open flag
 * FUSE_CAP_EXPORT_SUPPORT: filesystem handles lookups of "." and ".."
 * FUSE_CAP_BIG_WRITES: filesystem can handle write size larger than 4kB
 * FUSE_CAP_DONT_MASK: don't apply umask to file mode on create operations
 * FUSE_CAP_SPLICE_WRITE: ability to use splice() to write to the fuse device
 * FUSE_CAP_SPLICE_MOVE: ability to move data to the fuse device with splice()
 * FUSE_CAP_SPLICE_READ: ability to use splice() to read from the fuse device
 * FUSE_CAP_IOCTL_DIR: ioctl support on directories
 */
enum FUSE_CAP_ASYNC_READ = 1 << 0;
enum FUSE_CAP_POSIX_LOCKS = 1 << 1;
enum FUSE_CAP_ATOMIC_O_TRUNC = 1 << 3;
enum FUSE_CAP_EXPORT_SUPPORT = 1 << 4;
enum FUSE_CAP_BIG_WRITES = 1 << 5;
enum FUSE_CAP_DONT_MASK = 1 << 6;
enum FUSE_CAP_SPLICE_WRITE = 1 << 7;
enum FUSE_CAP_SPLICE_MOVE = 1 << 8;
enum FUSE_CAP_SPLICE_READ = 1 << 9;
enum FUSE_CAP_FLOCK_LOCKS = 1 << 10;
enum FUSE_CAP_IOCTL_DIR = 1 << 11;
enum FUSE_CAP_ALLOCATE = 1 << 27;
enum FUSE_CAP_EXCHANGE_DATA = 1 << 28;
enum FUSE_CAP_CASE_INSENSITIVE = 1 << 29;
enum FUSE_CAP_VOL_RENAME = 1 << 30;
enum FUSE_CAP_XTIMES = 1 << 31;

/**
 * Ioctl flags
 *
 * FUSE_IOCTL_COMPAT: 32bit compat ioctl on 64bit machine
 * FUSE_IOCTL_UNRESTRICTED: not restricted to well-formed ioctls, retry allowed
 * FUSE_IOCTL_RETRY: retry with new iovecs
 * FUSE_IOCTL_DIR: is a directory
 *
 * FUSE_IOCTL_MAX_IOV: maximum of in_iovecs + out_iovecs
 */
enum FUSE_IOCTL_COMPAT = 1 << 0;
enum FUSE_IOCTL_UNRESTRICTED = 1 << 1;
enum FUSE_IOCTL_RETRY = 1 << 2;
enum FUSE_IOCTL_DIR = 1 << 4;

enum FUSE_IOCTL_MAX_IOV = 256;

/**
 * Connection information, passed to the ->init() method
 *
 * Some of the elements are read-write, these can be changed to
 * indicate the value requested by the filesystem.  The requested
 * value must usually be smaller than the indicated value.
 */
struct fuse_conn_info
{
    /**
    	 * Major version of the protocol (read-only)
    	 */
    uint proto_major;

    /**
    	 * Minor version of the protocol (read-only)
    	 */
    uint proto_minor;

    /**
    	 * Is asynchronous read supported (read-write)
    	 */
    uint async_read;

    /**
    	 * Maximum size of the write buffer
    	 */
    uint max_write;

    /**
    	 * Maximum readahead
    	 */
    uint max_readahead;

    /*
    	 * Deprecated, use capability flags instead
    	 */
    struct _Anonymous_0
    {
        mixin(bitfields!(uint, "case_insensitive", 1, uint, "setvolname", 1,
                uint, "xtimes", 1, uint, "", 5));
    }

    _Anonymous_0 enable;
    /* __APPLE__ */

    /**
    	 * Capability flags, that the kernel supports
    	 */
    uint capable;

    /**
    	 * Capability flags, that the filesystem wants to enable
    	 */
    uint want;

    /**
    	 * Maximum number of backgrounded requests
    	 */
    uint max_background;

    /**
    	 * Kernel congestion threshold parameter
    	 */
    uint congestion_threshold;

    /**
    	 * For future use.
    	 */

    uint[22] reserved;
}

/*
 * Deprecated, use capability flags directly
 */

struct fuse_session;
struct fuse_chan;
struct fuse_pollhandle;

/**
 * Create a FUSE mountpoint
 *
 * Returns a control file descriptor suitable for passing to
 * fuse_new()
 *
 * @param mountpoint the mount point path
 * @param args argument vector
 * @return the communication channel on success, NULL on failure
 */
fuse_chan* fuse_mount(const(char)* mountpoint, fuse_args* args);

/**
 * Umount a FUSE mountpoint
 *
 * @param mountpoint the mount point path
 * @param ch the communication channel
 */
void fuse_unmount(const(char)* mountpoint, fuse_chan* ch);

/**
 * Parse common options
 *
 * The following options are parsed:
 *
 *   '-f'	     foreground
 *   '-d' '-odebug'  foreground, but keep the debug option
 *   '-s'	     single threaded
 *   '-h' '--help'   help
 *   '-ho'	     help without header
 *   '-ofsname=..'   file system name, if not present, then set to the program
 *		     name
 *
 * All parameters may be NULL
 *
 * @param args argument vector
 * @param mountpoint the returned mountpoint, should be freed after use
 * @param multithreaded set to 1 unless the '-s' option is present
 * @param foreground set to 1 if one of the relevant options is present
 * @return 0 on success, -1 on failure
 */
int fuse_parse_cmdline(fuse_args* args, char** mountpoint, int* multithreaded, int* foreground);

/**
 * Go into the background
 *
 * @param foreground if true, stay in the foreground
 * @return 0 on success, -1 on failure
 */
int fuse_daemonize(int foreground);

/**
 * Get the version of the library
 *
 * @return the version
 */
int fuse_version();

/**
 * Destroy poll handle
 *
 * @param ph the poll handle
 */
void fuse_pollhandle_destroy(fuse_pollhandle* ph);

/* ----------------------------------------------------------- *
 * Data buffer						       *
 * ----------------------------------------------------------- */

/**
 * Buffer flags
 */
enum fuse_buf_flags
{
    /**
    	 * Buffer contains a file descriptor
    	 *
    	 * If this flag is set, the .fd field is valid, otherwise the
    	 * .mem fields is valid.
    	 */
    FUSE_BUF_IS_FD = 2,

    /**
    	 * Seek on the file descriptor
    	 *
    	 * If this flag is set then the .pos field is valid and is
    	 * used to seek to the given offset before performing
    	 * operation on file descriptor.
    	 */
    FUSE_BUF_FD_SEEK = 4,

    /**
    	 * Retry operation on file descriptor
    	 *
    	 * If this flag is set then retry operation on file descriptor
    	 * until .size bytes have been copied or an error or EOF is
    	 * detected.
    	 */
    FUSE_BUF_FD_RETRY = 8
}

/**
 * Buffer copy flags
 */
enum fuse_buf_copy_flags
{
    /**
    	 * Don't use splice(2)
    	 *
    	 * Always fall back to using read and write instead of
    	 * splice(2) to copy data from one file descriptor to another.
    	 *
    	 * If this flag is not set, then only fall back if splice is
    	 * unavailable.
    	 */
    FUSE_BUF_NO_SPLICE = 2,

    /**
    	 * Force splice
    	 *
    	 * Always use splice(2) to copy data from one file descriptor
    	 * to another.  If splice is not available, return -EINVAL.
    	 */
    FUSE_BUF_FORCE_SPLICE = 4,

    /**
    	 * Try to move data with splice.
    	 *
    	 * If splice is used, try to move pages from the source to the
    	 * destination instead of copying.  See documentation of
    	 * SPLICE_F_MOVE in splice(2) man page.
    	 */
    FUSE_BUF_SPLICE_MOVE = 8,

    /**
    	 * Don't block on the pipe when copying data with splice
    	 *
    	 * Makes the operations on the pipe non-blocking (if the pipe
    	 * is full or empty).  See SPLICE_F_NONBLOCK in the splice(2)
    	 * man page.
    	 */
    FUSE_BUF_SPLICE_NONBLOCK = 16
}

/**
 * Single data buffer
 *
 * Generic data buffer for I/O, extended attributes, etc...  Data may
 * be supplied as a memory pointer or as a file descriptor
 */
struct fuse_buf
{
    /**
    	 * Size of data in bytes
    	 */
    size_t size;

    /**
    	 * Buffer flags
    	 */
    fuse_buf_flags flags;

    /**
    	 * Memory pointer
    	 *
    	 * Used unless FUSE_BUF_IS_FD flag is set.
    	 */
    void* mem;

    /**
    	 * File descriptor
    	 *
    	 * Used if FUSE_BUF_IS_FD flag is set.
    	 */
    int fd;

    /**
    	 * File position
    	 *
    	 * Used if FUSE_BUF_FD_SEEK flag is set.
    	 */
    off_t pos;
}

/**
 * Data buffer vector
 *
 * An array of data buffers, each containing a memory pointer or a
 * file descriptor.
 *
 * Allocate dynamically to add more than one buffer.
 */
struct fuse_bufvec
{
    /**
    	 * Number of buffers in the array
    	 */
    size_t count;

    /**
    	 * Index of current buffer within the array
    	 */
    size_t idx;

    /**
    	 * Current offset within the current buffer
    	 */
    size_t off;

    /**
    	 * Array of buffers
    	 */
    fuse_buf[1] buf;
}

/* Initialize bufvec with a single buffer of given size */

/* .count= */
/* .idx =  */
/* .off =  */
/* .buf =  */ /* [0] = */
/* .size =  */
/* .flags = */
/* .mem =   */
/* .fd =    */
/* .pos =   */

/**
 * Get total size of data in a fuse buffer vector
 *
 * @param bufv buffer vector
 * @return size of data
 */
size_t fuse_buf_size(const(fuse_bufvec)* bufv);

/**
 * Copy data from one buffer vector to another
 *
 * @param dst destination buffer vector
 * @param src source buffer vector
 * @param flags flags controlling the copy
 * @return actual number of bytes copied or -errno on error
 */
ssize_t fuse_buf_copy(fuse_bufvec* dst, fuse_bufvec* src, fuse_buf_copy_flags flags);

/* ----------------------------------------------------------- *
 * Signal handling					       *
 * ----------------------------------------------------------- */

/**
 * Exit session on HUP, TERM and INT signals and ignore PIPE signal
 *
 * Stores session in a global variable.	 May only be called once per
 * process until fuse_remove_signal_handlers() is called.
 *
 * @param se the session to exit
 * @return 0 on success, -1 on failure
 */
int fuse_set_signal_handlers(fuse_session* se);

/**
 * Restore default signal handlers
 *
 * Resets global session.  After this fuse_set_signal_handlers() may
 * be called again.
 *
 * @param se the same session as given in fuse_set_signal_handlers()
 */
void fuse_remove_signal_handlers(fuse_session* se);

/* ----------------------------------------------------------- *
 * Compatibility stuff					       *
 * ----------------------------------------------------------- */

/* __APPLE__ */

/* _FUSE_COMMON_H_ */
