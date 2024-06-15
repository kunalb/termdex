/*
*************************************************************************
** The original author's blessing preserved:
**
**    May you do good and not evil.
**    May you find forgiveness for yourself and forgive others.
**    May you share freely, never taking more than you give.
*************************************************************************
*/
#if !defined(SQLITEINT_H)
#include "sqlite3ext.h"
#endif
SQLITE_EXTENSION_INIT1
#include <stdlib.h>
#include <string.h>
#include <assert.h>

const char* DEFAULT_DIR = ".";

/* Functions defined in Go */
sqlite3_int64 CreateTable(const char* dir);
void DeleteTable(sqlite3_int64 id);
char* TableDeclaration(sqlite3_int64 tableId);

char* CursorFileName(sqlite3_int64 tableId, sqlite3_int64 rowId);
sqlite3_int64 CursorFileLength(sqlite3_int64 tableId, sqlite3_int64 rowId);
sqlite3_int64 CursorModTime(sqlite3_int64 tableId, sqlite3_int64 rowId);
char* CursorFrontMatter(sqlite3_int64 tableId, sqlite3_int64 rowId, int colId);
sqlite3_int64 TableLength(sqlite3_int64 tableId);


typedef struct mdvtab_vtab mdvtab_vtab;
struct mdvtab_vtab {
  sqlite3_vtab base;
  char* zDir;
  sqlite3_int64 iTableid;
};

typedef struct mdvtab_cursor mdvtab_cursor;
struct mdvtab_cursor {
  sqlite3_vtab_cursor base;
  sqlite3_int64 iRowid;
  sqlite_int64 iTableid;
};

static int mdvtabCreate(
  sqlite3 *db,
  void *pAux,
  int argc,
  const char *const*argv,
  sqlite3_vtab **ppVTab,
  char **pzErr
){
  mdvtab_vtab *pNew;
  int rc;

  if (argc > 4) {
    *pzErr = sqlite3_mprintf("Requires at most one argument, the root directory (received %d)", argc - 3);
    return SQLITE_ERROR;
  }

  const char* dir = argc == 4 ? argv[3] : DEFAULT_DIR;

  sqlite3_int64 iTableid = CreateTable(dir);
  char* decl = TableDeclaration(iTableid);
  rc = sqlite3_declare_vtab(db, decl);
  free(decl);

  if( rc==SQLITE_OK ){
    pNew = sqlite3_malloc( sizeof(*pNew) );
    *ppVTab = (sqlite3_vtab*)pNew;
    if( pNew==0 ) return SQLITE_NOMEM;
    memset(pNew, 0, sizeof(*pNew));
    pNew->zDir = sqlite3_mprintf("%s", argv[3]);
    pNew->iTableid = iTableid;
  }

  return rc;
}

static int mdvtabDestroy(sqlite3_vtab *pVtab){
  mdvtab_vtab *p = (mdvtab_vtab*)pVtab;
  DeleteTable(p->iTableid);
  sqlite3_free(p->zDir);
  sqlite3_free(p);
  return SQLITE_OK;
}

static int mdvtabOpen(sqlite3_vtab *p, sqlite3_vtab_cursor **ppCursor){
  mdvtab_cursor *pCur;
  pCur = sqlite3_malloc( sizeof(*pCur) );
  if( pCur==0 ) return SQLITE_NOMEM;
  memset(pCur, 0, sizeof(*pCur));
  *ppCursor = &pCur->base;
  pCur->iTableid = ((mdvtab_vtab*)p)->iTableid;
  return SQLITE_OK;
}

static int mdvtabClose(sqlite3_vtab_cursor *cur){
  mdvtab_cursor *pCur = (mdvtab_cursor*)cur;
  sqlite3_free(pCur);
  return SQLITE_OK;
}

static int mdvtabNext(sqlite3_vtab_cursor *cur){
  mdvtab_cursor *pCur = (mdvtab_cursor*)cur;
  pCur->iRowid++;
  return SQLITE_OK;
}

static int mdvtabColumn(
  sqlite3_vtab_cursor *cur,   /* The cursor */
  sqlite3_context *ctx,       /* First argument to sqlite3_result_...() */
  int i                       /* Which column to return */
                        ){
  mdvtab_cursor *pCur = (mdvtab_cursor*)cur;
  switch( i ){
  case 0:
    sqlite3_result_text(ctx, CursorFileName(pCur->iTableid, pCur->iRowid), -1, free);
      break;
  case 1:
    sqlite3_result_int(ctx, CursorFileLength(pCur->iTableid, pCur->iRowid));
    break;
  case 2:
    sqlite3_result_int(ctx, CursorModTime(pCur->iTableid, pCur->iRowid));
    break;
  default:
    sqlite3_result_text(ctx, CursorFrontMatter(pCur->iTableid, pCur->iRowid, i), -1, free);
  }
  return SQLITE_OK;
}

static int mdvtabRowid(sqlite3_vtab_cursor *cur, sqlite_int64 *pRowid){
  mdvtab_cursor *pCur = (mdvtab_cursor*)cur;
  *pRowid = pCur->iRowid;
  return SQLITE_OK;
}

static int mdvtabEof(sqlite3_vtab_cursor *cur){
  mdvtab_cursor *pCur = (mdvtab_cursor*)cur;
  return pCur->iRowid >= (int)TableLength(pCur->iTableid);
}

static int mdvtabFilter(
  sqlite3_vtab_cursor *pVtabCursor,
  int idxNum, const char *idxStr,
  int argc, sqlite3_value **argv
){
  mdvtab_cursor *pCur = (mdvtab_cursor *)pVtabCursor;
  pCur->iRowid = 0;
  return SQLITE_OK;
}

/*
** SQLite will invoke this method one or more times while planning a query
** that uses the virtual table.  This routine needs to create
** a query plan for each invocation and compute an estimated cost for that
** plan.
** TODO Implement
*/
static int mdvtabBestIndex(
  sqlite3_vtab *tab,
  sqlite3_index_info *pIdxInfo
){
  pIdxInfo->estimatedCost = (double)10;
  pIdxInfo->estimatedRows = 10;
  return SQLITE_OK;
}

static sqlite3_module mdvtabModule = {
  /* iVersion    */ 0,
  /* xCreate     */ mdvtabCreate,
  /* xConnect    */ mdvtabCreate,
  /* xBestIndex  */ mdvtabBestIndex,
  /* xDisconnect */ mdvtabDestroy,
  /* xDestroy    */ mdvtabDestroy,
  /* xOpen       */ mdvtabOpen,
  /* xClose      */ mdvtabClose,
  /* xFilter     */ mdvtabFilter,
  /* xNext       */ mdvtabNext,
  /* xEof        */ mdvtabEof,
  /* xColumn     */ mdvtabColumn,
  /* xRowid      */ mdvtabRowid,
  /* xUpdate     */ 0,
  /* xBegin      */ 0,
  /* xSync       */ 0,
  /* xCommit     */ 0,
  /* xRollback   */ 0,
  /* xFindMethod */ 0,
  /* xRename     */ 0,
  /* xSavepoint  */ 0,
  /* xRelease    */ 0,
  /* xRollbackTo */ 0,
  /* xShadowName */ 0,
};


int sqlite3_mdvtab_init_impl(
  sqlite3 *db,
  char **pzErrMsg,
  const sqlite3_api_routines *pApi
){
  int rc = SQLITE_OK;
  SQLITE_EXTENSION_INIT2(pApi);
  rc = sqlite3_create_module(db, "mdvtab", &mdvtabModule, 0);
  return rc;
}
