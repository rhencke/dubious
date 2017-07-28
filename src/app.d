import std.stdio;
import std.format;
import std.algorithm;
import std.string;
import std.conv;
import std.array;
import std.math;

import core.stdc.stdlib : cfree = free;
import core.stdc.string : cstrlen = strlen, cstrcmp = strcmp;
import core.sys.posix.sys.types : off_t, ino_t;
import core.sys.posix.sys.stat : stat_t, S_IFDIR, S_IFREG;
import core.sys.posix.sys.statvfs : statvfs_t;
import core.stdc.errno;

import fyooz.sqlite3;
import fyooz.c.fuse.fuse_lowlevel;
import fyooz.fuse;

//void main()
//{
//    auto db = db("test.db");
//    db.exec("PRAGMA journal_mode=WAL;");
//    //   auto stmt = db.stmt("PRAGMA journal_mode=WAL;");
//}
//class SqliteFs : Operations
//{
//    db database;
//    stmt getFiles;
//    stmt findFile;
//
//    this(const(char)* dbPath)
//    {
//        database = db(dbPath);
//        getFiles = database.stmt("select name from files");
//        findFile = database.stmt("
//WITH RECURSIVE ls(id, depth) AS (
//	SELECT
//		1 as id, 0 as depth
//	UNION ALL
//	SELECT
//		 files.id, depth+1 as depth
//	FROM
//		files
//	JOIN
//		ls
//	ON
//		ls.id = files.parent_id
//	JOIN
//		readdir
//	ON
//		readdir.id = depth+1
//		AND readdir.name = files.name
//) SELECT
//	ls.id
//FROM
//	ls
//WHERE
//	ls.depth = (select max(id) from readdir)
//        ");
//    }
//
//    override void getattr(const(char)[] path, ref stat_t s)
//    {
//        if (path == "/")
//        {
//            s.st_mode = S_IFDIR | octal!755;
//            s.st_size = 0;
//            return;
//        }
//
//        //        if (path.among("/a", "/b"))
//        //        {
//        s.st_mode = S_IFREG | octal!644;
//        s.st_size = 42;
//        return;
//        //        }
//
//        //throw new FuseException(errno.ENOENT);
//    }
//
//    override string[] readdir(const(char)[] path)
//    {
//        db.exec("begin tran");
//        scope (failure)
//            db.exec("rollback tran");
//
//        throw new FuseException(errno.ENOENT);
//    }
//}

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
    override void getattr(fuse_ino_t ino, fuse_file_info* fi)
    {
        stat_t stbuf;
        switch (ino)
        {
        case 1:
            stbuf.st_mode = S_IFDIR | octal!755;
            stbuf.st_nlink = 2;
            fuse_reply_attr(req, &stbuf, 1);
            break;
        case 2:
            stbuf.st_mode = S_IFREG | octal!444;
            stbuf.st_nlink = 1;
            stbuf.st_size = cstrlen(hello_str);
            fuse_reply_attr(req, &stbuf, 1);
            break;
        default:
            fuse_reply_err(req, ENOENT);
            break;
        }
    }

    override void lookup(fuse_ino_t parent, const(char)* name)
    {
        fuse_entry_param e;
        writeln(to!string(name));
        switch (parent)
        {
        case 1:
            if (cstrcmp(name, hello_name) != 0)
                goto default;
            e.ino = 2;
            e.attr_timeout = 1.0;
            e.entry_timeout = 1.0;
            e.attr.st_mode = S_IFREG | octal!444;
            e.attr.st_nlink = 1;
            e.attr.st_size = cstrlen(hello_str);
            fuse_reply_entry(req, &e);
            break;
        default:
            fuse_reply_err(req, ENOTDIR);
            break;
        }
    }

    override void readdir(fuse_ino_t ino, size_t size, off_t off, fuse_file_info* fi)
    {
        // opendir = prepare statement?
        // readdir = iterate?
        // closedir = finalize?

        char[] dirbuf = new char[size];
        uint len = 0;
        writeln("s_readdir");
        writeln("off is " ~ to!string(off));
        writeln("size is " ~ to!string(size));

        void addEnt(const(char)* name, ino_t ino)
        {
            stat_t stbuf;
            stbuf.st_ino = ino;
            ulong entsize = fuse_add_direntry(req, null, 0, name, null, 0);
            if (len + entsize > dirbuf.length)
            {
                dirbuf.length = nextPow2(len + entsize);
            }
            auto dirslice = dirbuf[len .. $];
            auto offNext = cast(long)(dirslice.length + entsize);
            fuse_add_direntry(req, dirslice.ptr, dirslice.length, name, &stbuf, offNext);
            len += entsize;
        }

        switch (ino)
        {
        case 1:
            // todo: error checking, yada yada
            // todo: overflow?
            //        addEnt("..", 1);
            //        addEnt(".", 1);
            addEnt(hello_name, 2);
            dirbuf.length = len;
            if (off < len)
            {
                auto dirslice = dirbuf[off .. len];
                if (size < dirslice.length)
                {
                    dirslice.length = size;
                }
                fuse_reply_buf(req, dirslice.ptr, dirslice.length);
            }
            else
            {
                fuse_reply_buf(req, null, 0);
            }
            break;
        default:
            fuse_reply_err(req, ENOTDIR);
        }
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

    auto fs = new SqliteFileSystem();
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
