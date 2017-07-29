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
import core.sys.posix.sys.stat : stat_t, mode_t, S_IFDIR, S_ISDIR, S_IFREG;
import core.sys.posix.sys.statvfs : statvfs_t;
import core.stdc.errno;

import fyooz.sqlite3;
import fyooz.c.fuse.fuse_lowlevel;
import fyooz.fuse;

import d2sqlite3;

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
    Database db;
    Statement findFilesQ;
    Statement findFilesParentQ;
    Statement getAttrQ;
    Statement lookupQ;

    this(string path)
    {
        db = Database(path);

        findFilesParentQ = db.prepare("select mode from files where id = ?");
        findFilesQ = db.prepare(
                "select id, name, mode from files where parent_id = ? order by id limit -1 offset ?");
        getAttrQ = db.prepare("select mode, coalesce(length(content), 0) from files where id = ?");
        lookupQ = db.prepare(
                "select id, mode, coalesce(length(content), 0) from files where parent_id = ? and name = ?");
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
        //        switch (ino)
        //        {
        //        case 1:
        //            stbuf.st_mode = S_IFDIR | octal!755;
        //            stbuf.st_nlink = 2;
        //            fuse_reply_attr(req, &stbuf, 1);
        //            break;
        //        case 2:
        //            stbuf.st_mode = S_IFREG | octal!444;
        //            stbuf.st_nlink = 1;
        //            stbuf.st_size = cstrlen(hello_str);
        //            fuse_reply_attr(req, &stbuf, 1);
        //            break;
        //        default:
        //            fuse_reply_err(req, ENOENT);
        //            break;
        //        }
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
        //        switch (parent)
        //        {
        //        case 1:
        //            if (cstrcmp(name, hello_name) != 0)
        //            {
        //                fuse_reply_err(req, ENOENT);
        //                return;
        //            }
        //            e.ino = 2;
        //            e.attr_timeout = 1.0;
        //            e.entry_timeout = 1.0;
        //            e.attr.st_mode = S_IFREG | octal!444;
        //            e.attr.st_nlink = 1;
        //            e.attr.st_size = cstrlen(hello_str);
        //            fuse_reply_entry(req, &e);
        //            break;
        //        default:
        //            fuse_reply_err(req, ENOTDIR);
        //            break;
        //        }
    }

    override void readdir(fuse_ino_t ino, size_t size, off_t off, fuse_file_info* fi)
    {
        // Offset below 0 is a sign there are no more entries.
        if (off < 0)
        {
            fuse_reply_buf(req, null, 0);
            return;
        }

        // opendir = prepare statement?
        // readdir = iterate?
        // closedir = finalize?
        //        findFiles.reset();
        //        findFiles.bind(1, ino);
        //        foreach (row; findFiles.execute())
        //        {
        //            writeln("id: " ~ to!string(row.peek!long(0)));
        //            writeln("name: " ~ row.peek!string(1));
        //        }

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

        // First row, if it exists, is special.  We use it to:
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
