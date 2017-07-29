module fyooz.fuse;

import std.exception : enforce;
import std.conv : to;
import std.file : FileException;
import std.format;
import std.stdio;
import core.stdc.errno;

import fyooz.c.fuse.fuse_lowlevel;

private template paramDecl(T, string name, Ts...)
{
    static if (Ts.length == 0)
        enum suffix = "";
    else
        enum suffix = ", " ~ paramDecl!(Ts);
    enum paramDecl = T.stringof ~ " " ~ name ~ suffix;
}

private template paramNames(T, string name, Ts...)
{
    static if (Ts.length == 0)
        enum suffix = "";
    else
        enum suffix = ", " ~ paramNames!(Ts);
    enum paramNames = name ~ suffix;
}

private template callback(string name, Ts...)
{
    enum
    {
        args = paramDecl!(Ts),
        argNames = paramNames!(Ts),
        callback = "
    void " ~ name ~ "(" ~ args ~ ") {
	    notImpl();
    }
    
    extern (System) nothrow  static __gshared private
    void _" ~ name
            ~ "(fuse_req_t req, " ~ args ~ ") {
        invoke(req, fs => fs."
            ~ name ~ "(" ~ argNames ~ "));
    }"
    }

}

class FuseException : Exception
{
    immutable ushort errno;
    this(ushort errno, string file = __FILE__, size_t line = __LINE__)
    {
        super(":(", file, line);
        this.errno = errno;
    }
}

abstract class FileSystem
{
    // TODO: figure out threading crap
    protected __gshared fuse_req_t req;

    mixin(callback!("open", fuse_ino_t, "ino", fuse_file_info*, "fi"));
    mixin(callback!("lookup", fuse_ino_t, "parent", const(char)*, "name"));
    mixin(callback!("getattr", fuse_ino_t, "ino", fuse_file_info*, "fi"));
    mixin(callback!("readdir", fuse_ino_t, "ino", size_t, "size", off_t,
            "off", fuse_file_info*, "fi"));
    mixin(callback!("read", fuse_ino_t, "ino", size_t, "size", off_t, "off",
            fuse_file_info*, "fi"));
    mixin(callback!("statfs", fuse_ino_t, "ino"));
    mixin(callback!("release", fuse_ino_t, "ino", fuse_file_info*, "fi"));
    mixin(callback!("flush", fuse_ino_t, "ino", fuse_file_info*, "fi"));

    // TODO: work into mixins
    static void hookOps(fuse_lowlevel_ops* ops)
    {
        ops.lookup = &_lookup;
        ops.getattr = &_getattr;
        ops.readdir = &_readdir;
        ops.open = &_open;
        ops.read = &_read;
        ops.statfs = &_statfs;
        ops.release = &_release;
    }

    private void notImpl()
    {
        throw new FileException("", EOPNOTSUPP);
    }

    nothrow private static __gshared invoke(fuse_req_t req, void delegate(FileSystem) cb)
    {
        auto us = fuse_req_userdata(req);
        auto usfs = cast(FileSystem) us;
        try
        {
            // TODO: reply structs as params that only allow valid replies?
            usfs.req = req;
            scope (exit)
                usfs.req = null;
            cb(usfs);
        }
        catch (Throwable t)
        {
            int err = EIO;
            if (auto fe = cast(FuseException) t)
            {
                err = cast(int) fe.errno;
            }
            else
            {
                try
                {
                    stderr.writeln(
                            "An unhandled exception occurred.  This is being reported to FUSE as EIO:");
                    stderr.writeln(t.toString());
                }
                catch (Throwable t)
                {
                }
            }
            auto ret = fuse_reply_err(req, err);
            if (ret == 0)
            {
                // TODO?  We couldn't report our error.
                // We can't throw... can stop the class from handling more?
            }
        }
    }
}
