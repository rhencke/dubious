import std.stdio;
import std.format;
import std.algorithm;
import std.exception;
import std.string;
import std.conv;
import std.array;
import std.math;

import core.stdc.stdlib : cfree = free;
import core.stdc.string : cstrlen = strlen, cstrcmp = strcmp;
import core.sys.posix.sys.types : off_t, ino_t;
import core.sys.posix.sys.stat : stat_t, mode_t, S_IFDIR, S_ISDIR, S_IFREG;
import core.sys.posix.sys.statvfs : statvfs_t;
import core.sys.posix.fcntl : O_RDONLY, O_RDWR, O_WRONLY;
import core.stdc.errno;

//import fyooz.sqlite3;
import fyooz.c.fuse.fuse_lowlevel;
import fyooz.fuse;

import d2sqlite3;
import d2sqlite3.sqlite3;

static immutable(char*) hello_str = "Hello World!\n";
static immutable(char*) hello_name = "hello";

fuse_args args_from_d_args(string[] args)
{
    typeof(return) ret;
    auto zargs = map!(toStringz)(args).array;
    ret.argc = cast(int) zargs.length;
    ret.argv = cast(char**) zargs.ptr;
    return ret;
}

class SqliteFileSystem : FileSystem
{
    Database db;
    Statement findFilesQ;
    Statement findFilesParentQ;
    Statement getAttrQ;
    Statement lookupQ;
    Statement openQ;

    this(string path)
    {
        db = Database(path);

        findFilesParentQ = db.prepare("select mode from files where id = ?");
        findFilesQ = db.prepare(
                "select id, name, mode from files where parent_id = ? order by id limit -1 offset ?");
        getAttrQ = db.prepare(
                "select mode, coalesce(length(b.content), 0) from files f left join blobs b on f.id = b.id where f.id = ?");
        openQ = db.prepare("select mode from files where id = ?");
        lookupQ = db.prepare("select f.id, mode, coalesce(length(b.content), 0) from files f left join blobs b on f.id = b.id where parent_id = ? and name = ?");
    }

    override void getattr(fuse_ino_t ino, fuse_file_info* fi)
    {
        getAttrQ.reset();
        getAttrQ.bind(1, ino);
        auto result = getAttrQ.execute();
        if (result.empty)
        {
            fuse_reply_err(req, ENOENT);
        }
        else
        {
            stat_t stbuf;
            auto row = result.front;
            stbuf.st_ino = ino;
            stbuf.st_mode = row.peek!ushort(0);
            stbuf.st_nlink = 1; // TODO
            stbuf.st_size = row.peek!long(1);
            fuse_reply_attr(req, &stbuf, 1);
        }
    }

    override void lookup(fuse_ino_t parent, const(char)* name)
    {
        const(char)[] nameStr = name[0 .. cstrlen(name)];
        lookupQ.reset();
        lookupQ.bind(1, parent);
        lookupQ.bind(2, nameStr);
        auto result = lookupQ.execute();
        if (result.empty)
        {
            stderr.writeln("Hmm, directory with inode " ~ to!string(
                    parent) ~ " didn't have a file called " ~ nameStr);
            fuse_reply_err(req, ENOENT);
        }
        else
        {
            auto row = result.front;
            fuse_entry_param e;
            e.ino = row.peek!long(0);
            e.attr_timeout = 1.0;
            e.entry_timeout = 1.0;
            e.attr.st_mode = row.peek!ushort(1);
            e.attr.st_nlink = 1; // TODO
            e.attr.st_size = row.peek!long(2);
            fuse_reply_entry(req, &e);
        }
    }

    private enum O_ACCMODE = 3;
    override void open(fuse_ino_t ino, fuse_file_info* fi)
    {
        openQ.reset();
        openQ.bind(1, ino);
        auto rows = openQ.execute();

        if (rows.empty)
            throw new FuseException(ENOENT);

        auto row = rows.front;
        auto requestedAccess = fi.flags & O_ACCMODE;

        if (S_ISDIR(row.peek!ushort(0)) && (requestedAccess == O_RDWR || requestedAccess == O_WRONLY))
            throw new FuseException(EISDIR);

        sqlite3_blob* blob;
        auto ret = sqlite3_blob_open(db.handle(), "main", "blobs", "content",
                ino, requestedAccess, &blob);
        if (ret == SQLITE_ERROR)
        {
            throw new FuseException(EIO); // TODO
        }
        fi.fh = cast(ulong) blob;
        fuse_reply_open(req, fi);
    }

    override void read(fuse_ino_t ino, size_t size, off_t off, fuse_file_info* fi)
    {
        if (fi.fh == 0)
        {
            throw new FuseException(EBADF);
        }
        sqlite3_blob* blob = cast(sqlite3_blob*) fi.fh;

        // SQLite will return an error if we attempt to read past the end of a blob.
        // So, we must determine up front how much is safe to read.
        // todo: dealing with stuff out of range of int, and diffs in what read vs sqlite_read use for sizes.
        auto blobSize = cast(ulong) sqlite3_blob_bytes(blob);

        if (off >= blobSize)
        {
            // read at or past end of blob - EOF.
            fuse_reply_buf(req, null, 0);
            return;
        }
        // Read the minimum of either:
        // * size requested
        // * bytes left in the blob
        size = min(size, blobSize - off);
        auto buf = new char[size];
        auto ret = sqlite3_blob_read(blob, buf.ptr, cast(int) size, cast(int) off);
        if (ret != SQLITE_OK)
        {
            throw new FuseException(EIO); // TODO
        }
        fuse_reply_buf(req, buf.ptr, buf.length);
    }

    override void release(fuse_ino_t ino, fuse_file_info* fi)
    {
        if (fi.fh == 0)
        {
            throw new FuseException(EBADF);
        }
        sqlite3_blob* blob = cast(sqlite3_blob*) fi.fh;
        sqlite3_blob_close(blob);
        fuse_reply_err(req, 0); // OK
    }

    override void flush(fuse_ino_t ino, fuse_file_info* fi)
    {
        fuse_reply_err(req, 0); // OK
    }

    override void readdir(fuse_ino_t ino, size_t size, off_t off, fuse_file_info* fi)
    {
        // TODO stress-test and ensure offset mechanism, size limits work right.
        char[] dirbuf = new char[size];
        uint len = 0;

        bool addEnt(const(char)* name, ino_t ino, mode_t mode)
        {
            stat_t stbuf;
            stbuf.st_ino = ino;
            stbuf.st_mode = mode;
            ulong entsize = fuse_add_direntry(req, null, 0, name, null, 0);
            if (len + entsize > size)
            {
                return false; // Buffer will not hold this entry
            }
            if (len + entsize > dirbuf.length)
            {
                dirbuf.length = min(nextPow2(len + entsize), size);
            }
            auto dirslice = dirbuf[len .. $];
            off++;
            fuse_add_direntry(req, dirslice.ptr, dirslice.length, name, &stbuf, off);
            len += entsize;
            return true;
        }

        findFilesParentQ.reset();
        findFilesParentQ.bind(1, ino);

        auto rows = findFilesParentQ.execute();

        // * Verify this inode exists at all
        // * Verify if it exists, it is a directory
        if (rows.empty || !S_ISDIR(rows.oneValue!ushort))
        {
            fuse_reply_err(req, ENOTDIR);
            return;
        }

        findFilesQ.reset();
        findFilesQ.bind(1, ino);
        findFilesQ.bind(2, off);
        auto filesInDir = findFilesQ.execute();

        // The remaining rows are the files in this directory, if any.
        foreach (row; filesInDir)
        {
            auto inode = row.peek!long(0);
            auto name = row.peek!string(1);
            auto mode = row.peek!ushort(2);
            if (!addEnt(toStringz(name), inode, mode))
                break;
        }
        fuse_reply_buf(req, dirbuf.ptr, len);
    }

    override void statfs(fuse_ino_t ino)
    {
        statvfs_ fs;
        fuse_reply_statfs(req, &fs);
    }
}

int main(string[] args)
{
    auto fargs = args_from_d_args(args);
    char* mountpoint;
    auto cmdret = fuse_parse_cmdline(&fargs, &mountpoint, null, null);
    if (cmdret == -1)
    {
        return cmdret;
    }
    if (!mountpoint)
    {
        stderr.writeln("You must provide a mountpoint (see -h)");
        return -1;
    }
    scope (exit)
        cfree(mountpoint);
    auto ch = fuse_mount(mountpoint, &fargs);
    scope (exit)
        fuse_unmount(mountpoint, ch);
    assert(ch != null);

    scope auto fs = new SqliteFileSystem("test.db");
    // TODO: hide session creation in a struct?
    // less bad ops handling
    fuse_lowlevel_ops ops;
    FileSystem.hookOps(&ops);
    auto session = fuse_lowlevel_new(&fargs, &ops, ops.sizeof, cast(void*) fs);
    if (session == null)
    {
        stderr.writeln("Unable to create a session?");
        return -1;
    }
    scope (exit)
        fuse_session_destroy(session);

    auto ret = fuse_set_signal_handlers(session);
    assert(ret == 0);
    scope (exit)
        fuse_remove_signal_handlers(session);

    fuse_session_add_chan(session, ch);
    scope (exit)
        fuse_session_remove_chan(ch);

    //  auto fs = new Fuse("SimpleFS", true, false);
    //    scope auto sfs = new SqliteFs("test.db");
    //fs.mount(sfs, "/Users/rhencke/gas", []);

    return fuse_session_loop(session);
}
