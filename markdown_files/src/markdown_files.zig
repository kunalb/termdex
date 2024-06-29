const std = @import("std");

// #if !defined(SQLITEINT_H)
// #include "sqlite3ext.h"
// #endif
const c = @cImport({
    @cInclude("/usr/include/sqlite3ext.h");
});

// SQLITE_EXTENSION_INIT1
var sqlite3_api: [*c]const c.sqlite3_api_routines = undefined;

// #include <string.h>
// #include <assert.h>

// #ifdef _WIN32
// __declspec(dllexport)
// #endif
// int sqlite3_templatevtab_init(
// sqlite3 *db,
// char **pzErrMsg,
// const sqlite3_api_routines *pApi
// ){
// int rc = SQLITE_OK;
// SQLITE_EXTENSION_INIT2(pApi);
// rc = sqlite3_create_module(db, "templatevtab", &templatevtabModule, 0);
// return rc;
// }
export fn sqlite3_markdown_files_init(
    db: *c.sqlite3,
    pzErrMsg: [*c][*c]u8,
    pApi: [*c]const c.sqlite3_api_routines,
) c_int {
    sqlite3_api = pApi;
    _ = pzErrMsg;

    return c.sqlite3_create_module(db, "markdown_files", &MarkdownFilesVTabModule, @ptrFromInt(0));
}

// /*
// ** This following structure defines all the methods for the
// ** virtual table.
// */
const MarkdownFilesVTabModule = c.sqlite3_module{
    .iVersion = 0,
    .xCreate = @ptrFromInt(0),
    .xConnect = @ptrFromInt(0),
    .xBestIndex = @ptrFromInt(0),
    .xDestroy = @ptrFromInt(0),
    .xOpen = @ptrFromInt(0),
    .xClose = @ptrFromInt(0),
    .xFilter = @ptrFromInt(0),
    .xNext = @ptrFromInt(0),
    .xEof = @ptrFromInt(0),
    .xColumn = @ptrFromInt(0),
    .xRowid = @ptrFromInt(0),
    .xUpdate = @ptrFromInt(0),
    .xBegin = @ptrFromInt(0),
    .xSync = @ptrFromInt(0),
    .xCommit = @ptrFromInt(0),
    .xRollback = @ptrFromInt(0),
    .xFindFunction = @ptrFromInt(0),
    .xRename = @ptrFromInt(0),
    .xSavepoint = @ptrFromInt(0),
    .xRelease = @ptrFromInt(0),
    .xRollbackTo = @ptrFromInt(0),
    .xShadowName = @ptrFromInt(0),
    // .xIntegrity = 0,
};

//
// /* templatevtab_vtab is a subclass of sqlite3_vtab which is
// ** underlying representation of the virtual table
// */
// typedef struct templatevtab_vtab templatevtab_vtab;
// struct templatevtab_vtab {
// sqlite3_vtab base;  /* Base class - must be first */
// /* Add new fields here, as necessary */
// };
//
// /* templatevtab_cursor is a subclass of sqlite3_vtab_cursor which will
// ** serve as the underlying representation of a cursor that scans
// ** over rows of the result
// */
// typedef struct templatevtab_cursor templatevtab_cursor;
// struct templatevtab_cursor {
// sqlite3_vtab_cursor base;  /* Base class - must be first */
// /* Insert new fields here.  For this templatevtab we only keep track
// ** of the rowid */
// sqlite3_int64 iRowid;      /* The rowid */
// };
//
// /*
// ** The templatevtabConnect() method is invoked to create a new
// ** template virtual table.
// **
// ** Think of this routine as the constructor for templatevtab_vtab objects.
// **
// ** All this routine needs to do is:
// **
// **    (1) Allocate the templatevtab_vtab object and initialize all fields.
// **
// **    (2) Tell SQLite (via the sqlite3_declare_vtab() interface) what the
// **        result set of queries against the virtual table will look like.
// */
// static int templatevtabConnect(
// sqlite3 *db,
// void *pAux,
// int argc, const char *const*argv,
// sqlite3_vtab **ppVtab,
// char **pzErr
// ){
// templatevtab_vtab *pNew;
// int rc;
//
// rc = sqlite3_declare_vtab(db,
// "CREATE TABLE x(a,b)"
// );
// /* For convenience, define symbolic names for the index to each column. */
// #define TEMPLATEVTAB_A  0
// #define TEMPLATEVTAB_B  1
// if( rc==SQLITE_OK ){
// pNew = sqlite3_malloc( sizeof(*pNew) );
// *ppVtab = (sqlite3_vtab*)pNew;
// if( pNew==0 ) return SQLITE_NOMEM;
// memset(pNew, 0, sizeof(*pNew));
// }
// return rc;
// }
//
// /*
// ** This method is the destructor for templatevtab_vtab objects.
// */
// static int templatevtabDisconnect(sqlite3_vtab *pVtab){
// templatevtab_vtab *p = (templatevtab_vtab*)pVtab;
// sqlite3_free(p);
// return SQLITE_OK;
// }
//
// /*
// ** Constructor for a new templatevtab_cursor object.
// */
// static int templatevtabOpen(sqlite3_vtab *p, sqlite3_vtab_cursor **ppCursor){
// templatevtab_cursor *pCur;
// pCur = sqlite3_malloc( sizeof(*pCur) );
// if( pCur==0 ) return SQLITE_NOMEM;
// memset(pCur, 0, sizeof(*pCur));
// *ppCursor = &pCur->base;
// return SQLITE_OK;
// }
//
// /*
// ** Destructor for a templatevtab_cursor.
// */
// static int templatevtabClose(sqlite3_vtab_cursor *cur){
// templatevtab_cursor *pCur = (templatevtab_cursor*)cur;
// sqlite3_free(pCur);
// return SQLITE_OK;
// }
//
//
// /*
// ** Advance a templatevtab_cursor to its next row of output.
// */
// static int templatevtabNext(sqlite3_vtab_cursor *cur){
// templatevtab_cursor *pCur = (templatevtab_cursor*)cur;
// pCur->iRowid++;
// return SQLITE_OK;
// }
//
// /*
// ** Return values of columns for the row at which the templatevtab_cursor
// ** is currently pointing.
// */
// static int templatevtabColumn(
// sqlite3_vtab_cursor *cur,   /* The cursor */
// sqlite3_context *ctx,       /* First argument to sqlite3_result_...() */
// int i                       /* Which column to return */
// ){
// templatevtab_cursor *pCur = (templatevtab_cursor*)cur;
// switch( i ){
// case TEMPLATEVTAB_A:
// sqlite3_result_int(ctx, 1000 + pCur->iRowid);
// break;
// default:
// assert( i==TEMPLATEVTAB_B );
// sqlite3_result_int(ctx, 2000 + pCur->iRowid);
// break;
// }
// return SQLITE_OK;
// }
//
// /*
// ** Return the rowid for the current row.  In this implementation, the
// ** rowid is the same as the output value.
// */
// static int templatevtabRowid(sqlite3_vtab_cursor *cur, sqlite_int64 *pRowid){
// templatevtab_cursor *pCur = (templatevtab_cursor*)cur;
// *pRowid = pCur->iRowid;
// return SQLITE_OK;
// }
//
// /*
// ** Return TRUE if the cursor has been moved off of the last
// ** row of output.
// */
// static int templatevtabEof(sqlite3_vtab_cursor *cur){
// templatevtab_cursor *pCur = (templatevtab_cursor*)cur;
// return pCur->iRowid>=10;
// }
//
// /*
// ** This method is called to "rewind" the templatevtab_cursor object back
// ** to the first row of output.  This method is always called at least
// ** once prior to any call to templatevtabColumn() or templatevtabRowid() or
// ** templatevtabEof().
// */
// static int templatevtabFilter(
// sqlite3_vtab_cursor *pVtabCursor,
// int idxNum, const char *idxStr,
// int argc, sqlite3_value **argv
// ){
// templatevtab_cursor *pCur = (templatevtab_cursor *)pVtabCursor;
// pCur->iRowid = 1;
// return SQLITE_OK;
// }
//
// /*
// ** SQLite will invoke this method one or more times while planning a query
// ** that uses the virtual table.  This routine needs to create
// ** a query plan for each invocation and compute an estimated cost for that
// ** plan.
// */
// static int templatevtabBestIndex(
// sqlite3_vtab *tab,
// sqlite3_index_info *pIdxInfo
// ){
// pIdxInfo->estimatedCost = (double)10;
// pIdxInfo->estimatedRows = 10;
// return SQLITE_OK;
// }
//
//
//
//
