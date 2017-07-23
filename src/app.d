import std.stdio;
import std.conv;
import etc.c.sqlite3;
import dubious.sqlite3_db;

import dubious.c.dokan;

void main()
{
    auto db = new sqlite3_db("test.db");

    auto opts = new DOKAN_OPTIONS();
    auto opers = new DOKAN_OPERATIONS();

    switch (DokanMain(opts, opers))
    {
    case DokanMainResult.DOKAN_SUCCESS:
        break; // ok
    default:
        throw new Exception("fuck");
    }
}
