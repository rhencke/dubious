module dubious.sqlite3_db;

import std.conv;
import etc.c.sqlite3;

struct sqlite3_db
{
    sqlite3* db;

    @disable this();
    @disable this(this);
    this(const(char)* filename)
    {
        auto ret = sqlite3_open(filename, &db);
        scope (failure)
        {
            this.__dtor();
        }
        if (ret != SQLITE_OK)
        {
            throw new Exception(to!string(sqlite3_errmsg(db)));
        }
    }

    ~this()
    {
        sqlite3_close(db);
    }
}
