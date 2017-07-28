module fyooz.sqlite3;

import std.conv;
import std.stdio;
import etc.c.sqlite3;

struct db
{
    invariant
    {
        assert(db != null);
    }

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
        handleError(ret);
    }

    ~this()
    {
        stderr.writeln("eh");
        sqlite3_close(db);
    }

    void exec(const(char)* sql)
    {
        auto ret = sqlite3_exec(db, sql, null, null, null);
        handleError(ret);
    }

    private void handleError(int err)
    {
        if (err != SQLITE_OK)
        {
            string msg = to!string(sqlite3_errmsg(db));
            throw new Sqlite3Exception(msg, err);
        }
    }
}

struct stmt
{
    invariant
    {
        assert(_stmt != null);
        assert(_db != null);
    }

    db* _db;
    sqlite3_stmt* _stmt;

    @disable this();
    @disable this(this);
    this(ref db db, const(char)* zSql)
    {
        _db = &db;
        auto ret = sqlite3_prepare_v2(db.db, zSql, -1, &_stmt, null);
        db.handleError(ret);
    }

    ~this()
    {
        auto ret = sqlite3_finalize(_stmt);
        _db.handleError(ret);
    }

    int opApply(int delegate(ref string) operations)
    {
        sqlite3_reset(_stmt);
        while (true)
        {
            auto ret = sqlite3_step(_stmt);
            switch (ret)
            {
            case SQLITE_ROW:
                string col1;
                col1 = to!string(sqlite3_column_text(_stmt, 0));
                auto result = operations(col1);
                if (result != 0)
                {
                    return result;
                }
                break;
            case SQLITE_DONE:
                return 0;
                // done;
            default:
                _db.handleError(ret);
                break;
            }
        }
    }
}

class Sqlite3Exception : Exception
{
    invariant
    {
        assert(code != SQLITE_OK);
    }

    immutable int code;
    this(string message, immutable int code)
    {
        this.code = code;
        super(message);
    }
}
