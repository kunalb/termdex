#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sqlite3.h>

static int callback(void *NotUsed, int argc, char **argv, char **azColName) {
    NotUsed = 0;
    
    for (int i = 0; i < argc; i++) {
        printf("%s = %s\n", azColName[i], argv[i] ? argv[i] : "NULL");
    }
    printf("\n");
    return 0;
}

int main(int argc, char* argv[]) {
    sqlite3 *db;
    char *zErrMsg = 0;
    int rc;
    
    // Open in-memory database
    rc = sqlite3_open(":memory:", &db);
    if (rc) {
        fprintf(stderr, "Can't open database: %s\n", sqlite3_errmsg(db));
        sqlite3_close(db);
        return 1;
    }
    
    // Load the extension
    rc = sqlite3_load_extension(db, "../libmd_files.so", NULL, &zErrMsg);
    if (rc != SQLITE_OK) {
        fprintf(stderr, "Extension loading failed: %s\n", zErrMsg);
        sqlite3_free(zErrMsg);
        sqlite3_close(db);
        return 1;
    }
    
    // Create virtual table to current directory
    rc = sqlite3_exec(db, 
                    "CREATE VIRTUAL TABLE test_files USING md_files('.');", 
                    callback, 0, &zErrMsg);
    if (rc != SQLITE_OK) {
        fprintf(stderr, "SQL error: %s\n", zErrMsg);
        sqlite3_free(zErrMsg);
        sqlite3_close(db);
        return 1;
    }
    
    // Query the table
    printf("Listing files:\n");
    rc = sqlite3_exec(db, "SELECT path, basename, size_bytes FROM test_files;", 
                     callback, 0, &zErrMsg);
    if (rc != SQLITE_OK) {
        fprintf(stderr, "SQL error: %s\n", zErrMsg);
        sqlite3_free(zErrMsg);
        sqlite3_close(db);
        return 1;
    }
    
    sqlite3_close(db);
    return 0;
}