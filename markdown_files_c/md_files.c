#include <sqlite3ext.h>
SQLITE_EXTENSION_INIT1

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <dirent.h>
#include <yaml.h>
#include <cmark-gfm.h>
#include <time.h>
#include <errno.h>
#include <stdbool.h>
#include <limits.h>
#include <unistd.h>
#include <libgen.h>

// On some systems, realpath might need explicit declaration
extern char *realpath(const char *restrict path, char *restrict resolved_path);

// ---------------------------------------------------------------------------
// Virtual Table Implementation
// ---------------------------------------------------------------------------

typedef struct {
  sqlite3_vtab base;
  char *root_dir;
} VTab;

// A directory entry in our stack for traversal
typedef struct DirEntry {
  DIR *dir;
  char *path;
  struct DirEntry *next;
} DirEntry;

typedef struct {
  DirEntry *dir_stack;      // Stack of directories to process
  struct dirent *entry;     // Current directory entry
  struct stat stat_buf;     // Stat buffer for current file
  char *current_path;       // Current file path
  bool has_stat;            // Whether stat_buf is valid
} CursorState;

typedef struct {
  sqlite3_vtab_cursor base;
  sqlite3_int64 row_id;
  CursorState *state;
} Cursor;

// Add a directory to the traversal stack
static bool push_dir(CursorState *state, DIR *dir, const char *path) {
  if (!dir || !path) return false;
  
  DirEntry *entry = malloc(sizeof(DirEntry));
  if (!entry) return false;
  
  entry->dir = dir;
  entry->path = sqlite3_malloc(strlen(path) + 1);
  if (!entry->path) {
    free(entry);
    return false;
  }
  strcpy(entry->path, path);
  
  // Add to front of stack
  entry->next = state->dir_stack;
  state->dir_stack = entry;
  
  return true;
}

// Remove and free the top directory from the stack
static void pop_dir(CursorState *state) {
  if (!state || !state->dir_stack) return;
  
  DirEntry *entry = state->dir_stack;
  state->dir_stack = entry->next;
  
  if (entry->dir) closedir(entry->dir);
  sqlite3_free(entry->path);
  free(entry);
}

// Clean up all directories in the stack
static void free_dir_stack(CursorState *state) {
  if (!state) return;
  
  while (state->dir_stack) {
    pop_dir(state);
  }
}

// Path manipulation function
static char* path_join(const char *dir, const char *file) {
  size_t dir_len = strlen(dir);
  size_t file_len = strlen(file);
  size_t need_slash = (dir_len > 0 && dir[dir_len - 1] != '/') ? 1 : 0;
  
  char *result = sqlite3_malloc(dir_len + need_slash + file_len + 1);
  if (!result) return NULL;
  
  strcpy(result, dir);
  if (need_slash) result[dir_len] = '/';
  strcpy(result + dir_len + need_slash, file);
  
  return result;
}

// Check if file has a markdown extension (.md or .markdown)
static bool is_markdown_file(const char *path) {
  size_t len = strlen(path);
  return (len > 3 && strcmp(&path[len-3], ".md") == 0) ||
         (len > 9 && strcmp(&path[len-9], ".markdown") == 0);
}

// Get the next markdown file to process
static bool get_next_file(CursorState *state) {
  if (!state) return false;
  
  // Free previous path
  if (state->current_path) {
    sqlite3_free(state->current_path);
    state->current_path = NULL;
  }
  
  // Reset stat flag
  state->has_stat = false;
  
  while (state->dir_stack) {
    DIR *current_dir = state->dir_stack->dir;
    const char *current_path = state->dir_stack->path;
    
    struct dirent *entry;
    while ((entry = readdir(current_dir)) != NULL) {
      const char *name = entry->d_name;
      
      // Skip . and ..
      if (strcmp(name, ".") == 0 || strcmp(name, "..") == 0)
        continue;
      
      // Build full path
      char *full_path = path_join(current_path, name);
      if (!full_path) continue;
      
      // Get file stat
      struct stat st;
      if (stat(full_path, &st) != 0) {
        sqlite3_free(full_path);
        continue;
      }
      
      if (S_ISDIR(st.st_mode)) {
        // It's a directory - add to stack for later traversal
        DIR *subdir = opendir(full_path);
        if (subdir) {
          if (!push_dir(state, subdir, full_path)) {
            // Failed to add to stack
            closedir(subdir);
            sqlite3_free(full_path);
          }
        } else {
          sqlite3_free(full_path);
        }
      } else if (S_ISREG(st.st_mode) && is_markdown_file(full_path)) {
        // Found a markdown file
        state->current_path = full_path;
        state->entry = entry; // Just a reference - do not free
        
        // Copy stat info
        memcpy(&state->stat_buf, &st, sizeof(struct stat));
        state->has_stat = true;
        return true;
      } else {
        // Not a directory or markdown file
        sqlite3_free(full_path);
      }
    }
    
    // No more entries in current directory, pop and continue
    pop_dir(state);
  }
  
  return false; // No more files
}

static int vtabConnect(sqlite3 *db, void *aux, int argc, const char *const *argv, 
                      sqlite3_vtab **pp_vtab, char **pz_err) {
  (void)aux;
  
  if (argc > 4) {
    *pz_err = sqlite3_mprintf("Can specify at most one argument: the root directory "
                             "for markdown files (received %d).", argc - 3);
    return SQLITE_ERROR;
  }
  
  VTab *new_vtab = sqlite3_malloc(sizeof(VTab));
  if (!new_vtab) return SQLITE_NOMEM;
  memset(new_vtab, 0, sizeof(VTab));
  
  int rc = sqlite3_declare_vtab(db, 
      "CREATE TABLE x(path,basename,size_bytes,ctime_s,mtime_s,atime_s)");
  if (rc != SQLITE_OK) {
    sqlite3_free(new_vtab);
    return rc;
  }
  
  char real_path[4096]; // Use fixed size instead of PATH_MAX
  char tmp_path[4096];

  if (argc == 4) {
    const char *path_arg = argv[3];
    
    // Convert relative paths to absolute paths
    if (path_arg[0] != '/') {
      // For relative paths like '.' or './', get current directory first
      if (getcwd(tmp_path, sizeof(tmp_path)) == NULL) {
        *pz_err = sqlite3_mprintf("Could not determine current working directory!");
        sqlite3_free(new_vtab);
        return SQLITE_ERROR;
      }
      
      // If it's just "." or "./", use the current directory path directly
      if (strcmp(path_arg, ".") == 0 || strcmp(path_arg, "./") == 0) {
        strncpy(real_path, tmp_path, sizeof(real_path) - 1);
        real_path[sizeof(real_path) - 1] = '\0';
      } else {
        // For other relative paths, construct an absolute path
        size_t tmp_len = strlen(tmp_path);
        
        // Check if we need a separator
        if (tmp_path[tmp_len-1] != '/' && path_arg[0] != '/') {
          snprintf(real_path, sizeof(real_path), "%s/%s", tmp_path, path_arg);
        } else {
          snprintf(real_path, sizeof(real_path), "%s%s", tmp_path, path_arg);
        }
        
        // Verify the directory exists
        struct stat st;
        if (stat(real_path, &st) != 0 || !S_ISDIR(st.st_mode)) {
          *pz_err = sqlite3_mprintf("Directory does not exist: `%s`", real_path);
          sqlite3_free(new_vtab);
          return SQLITE_ERROR;
        }
      }
    } else {
      // For absolute paths, use realpath directly
      if (realpath(path_arg, real_path) == NULL) {
        *pz_err = sqlite3_mprintf("Couldn't resolve directory! `%s`", path_arg);
        sqlite3_free(new_vtab);
        return SQLITE_ERROR;
      }
    }
    
    // Allocate and copy the resolved path
    new_vtab->root_dir = sqlite3_malloc(strlen(real_path) + 1);
    if (!new_vtab->root_dir) {
      sqlite3_free(new_vtab);
      return SQLITE_NOMEM;
    }
    strcpy(new_vtab->root_dir, real_path);
  } else {
    // No path provided, use current directory
    if (getcwd(real_path, sizeof(real_path)) == NULL) {
      *pz_err = sqlite3_mprintf("Could not determine current working directory!");
      sqlite3_free(new_vtab);
      return SQLITE_ERROR;
    }
    new_vtab->root_dir = sqlite3_malloc(strlen(real_path) + 1);
    if (!new_vtab->root_dir) {
      sqlite3_free(new_vtab);
      return SQLITE_NOMEM;
    }
    strcpy(new_vtab->root_dir, real_path);
  }
  
  *pp_vtab = &new_vtab->base;
  return rc;
}

static int vtabDisconnect(sqlite3_vtab *p_vtab) {
  VTab *p = (VTab*)p_vtab;
  sqlite3_free(p->root_dir);
  sqlite3_free(p);
  return SQLITE_OK;
}

static int vtabOpen(sqlite3_vtab *p_vtab, sqlite3_vtab_cursor **pp_cursor) {
  VTab *vtab = (VTab*)p_vtab;
  
  // Create cursor
  Cursor *new_cursor = sqlite3_malloc(sizeof(Cursor));
  if (!new_cursor) return SQLITE_NOMEM;
  memset(new_cursor, 0, sizeof(Cursor));
  
  // Create cursor state
  CursorState *state = sqlite3_malloc(sizeof(CursorState));
  if (!state) {
    sqlite3_free(new_cursor);
    return SQLITE_NOMEM;
  }
  memset(state, 0, sizeof(CursorState));
  
  // Open root directory
  DIR *root_dir = opendir(vtab->root_dir);
  if (!root_dir) {
    sqlite3_free(state);
    sqlite3_free(new_cursor);
    return SQLITE_ERROR;
  }
  
  // Initialize the directory stack with root directory
  if (!push_dir(state, root_dir, vtab->root_dir)) {
    closedir(root_dir);
    sqlite3_free(state);
    sqlite3_free(new_cursor);
    return SQLITE_NOMEM;
  }
  
  // Get first file
  if (!get_next_file(state)) {
    // No files found
    free_dir_stack(state);
    sqlite3_free(state);
    sqlite3_free(new_cursor);
    return SQLITE_EMPTY;
  }
  
  new_cursor->state = state;
  new_cursor->row_id = 1;
  *pp_cursor = &new_cursor->base;
  
  return SQLITE_OK;
}

static int vtabClose(sqlite3_vtab_cursor *p_base) {
  Cursor *cur = (Cursor*)p_base;
  CursorState *state = cur->state;
  
  if (state) {
    // Free directory stack
    free_dir_stack(state);
    
    // Free current path
    if (state->current_path) {
      sqlite3_free(state->current_path);
    }
    
    // Free state
    sqlite3_free(state);
  }
  
  sqlite3_free(cur);
  return SQLITE_OK;
}

static int vtabNext(sqlite3_vtab_cursor *p_cur_base) {
  Cursor *cursor = (Cursor*)p_cur_base;
  cursor->row_id += 1;
  
  // Get the next file
  if (!get_next_file(cursor->state)) {
    // No more files, set EOF
    cursor->state->current_path = NULL;
  }
  
  return SQLITE_OK;
}

static int vtabColumn(sqlite3_vtab_cursor *p_cur, sqlite3_context *ctx, int i) {
  Cursor *cur = (Cursor*)p_cur;
  CursorState *state = cur->state;
  
  if (!state->current_path) {
    sqlite3_result_null(ctx);
    return SQLITE_OK;
  }
  
  switch(i) {
    case 0: // path
      sqlite3_result_text(ctx, state->current_path, -1, SQLITE_TRANSIENT);
      break;
    case 1: // basename
      {
        // Get the basename from the path
        char *path_copy = strdup(state->current_path);
        if (!path_copy) {
          sqlite3_result_error(ctx, "Out of memory", -1);
          return SQLITE_NOMEM;
        }
        
        char *base = basename(path_copy);
        sqlite3_result_text(ctx, base, -1, SQLITE_TRANSIENT);
        free(path_copy);
      }
      break;
    case 2: // size_bytes
      sqlite3_result_int64(ctx, state->stat_buf.st_size);
      break;
    case 3: // ctime_s
      sqlite3_result_int64(ctx, state->stat_buf.st_ctime);
      break;
    case 4: // mtime_s
      sqlite3_result_int64(ctx, state->stat_buf.st_mtime);
      break;
    case 5: // atime_s
      sqlite3_result_int64(ctx, state->stat_buf.st_atime);
      break;
    default:
      sqlite3_result_int64(ctx, cur->row_id);
      break;
  }
  
  return SQLITE_OK;
}

static int vtabRowid(sqlite3_vtab_cursor *cur, sqlite_int64 *pRowid) {
  Cursor *pCur = (Cursor*)cur;
  *pRowid = pCur->row_id;
  return SQLITE_OK;
}

static int vtabEof(sqlite3_vtab_cursor *p_base) {
  Cursor *cur = (Cursor*)p_base;
  CursorState *state = cur->state;
  return state->current_path == NULL;
}

static int vtabFilter(sqlite3_vtab_cursor *p_vtab_cursor, int idxNum, const char *idxStr,
                    int argc, sqlite3_value **argv) {
  (void)idxNum;
  (void)idxStr;
  (void)argc;
  (void)argv;
  
  Cursor *cur = (Cursor*)p_vtab_cursor;
  cur->row_id = 1;
  return SQLITE_OK;
}

static int vtabBestIndex(sqlite3_vtab *tab, sqlite3_index_info *pIdxInfo) {
  (void)tab;
  pIdxInfo->estimatedCost = 10.0;
  pIdxInfo->estimatedRows = 10;
  return SQLITE_OK;
}

// ---------------------------------------------------------------------------
// Front Matter Parsing 
// ---------------------------------------------------------------------------

char* parse_front_matter(const char *abs_path, const char *field) {
  FILE *file = fopen(abs_path, "r");
  if (!file) return NULL;
  
  char line[4096];
  char *raw_yaml = NULL;
  size_t yaml_len = 0;
  bool first = true;
  bool in_frontmatter = false;
  
  // Extract front matter block
  while (fgets(line, sizeof(line), file)) {
    // Check for front matter delimiter
    if (first && strncmp(line, "---", 3) == 0) {
      in_frontmatter = true;
      first = false;
      continue;
    } else if (!first && in_frontmatter && strncmp(line, "---", 3) == 0) {
      break;
    } else if (in_frontmatter) {
      // Append line to YAML content
      size_t line_len = strlen(line);
      char *new_yaml = realloc(raw_yaml, yaml_len + line_len + 1);
      if (!new_yaml) {
        free(raw_yaml);
        fclose(file);
        return NULL;
      }
      raw_yaml = new_yaml;
      memcpy(raw_yaml + yaml_len, line, line_len + 1);
      yaml_len += line_len;
    } else if (first) {
      // No front matter
      break;
    }
  }
  
  fclose(file);
  
  if (!raw_yaml) return NULL;
  
  // Parse YAML front matter
  yaml_parser_t parser;
  yaml_event_t event;
  char *result = NULL;
  bool return_next_token = false;
  
  if (!yaml_parser_initialize(&parser)) {
    free(raw_yaml);
    return NULL;
  }
  
  yaml_parser_set_input_string(&parser, (const unsigned char *)raw_yaml, yaml_len);
  
  // First pass: find the field
  while (1) {
    if (!yaml_parser_parse(&parser, &event)) {
      yaml_parser_delete(&parser);
      free(raw_yaml);
      return NULL;
    }
    
    if (event.type == YAML_SCALAR_EVENT) {
      char *key = (char *)event.data.scalar.value;
      if (strcmp(key, field) == 0) {
        return_next_token = true;
      }
    } else if (event.type == YAML_STREAM_END_EVENT) {
      yaml_event_delete(&event);
      break;
    }
    
    yaml_event_delete(&event);
    
    if (return_next_token) break;
  }
  
  if (!return_next_token) {
    yaml_parser_delete(&parser);
    free(raw_yaml);
    return NULL;
  }
  
  // Parse next event (the value)
  if (!yaml_parser_parse(&parser, &event)) {
    yaml_parser_delete(&parser);
    free(raw_yaml);
    return NULL;
  }
  
  if (event.type == YAML_SCALAR_EVENT) {
    result = strdup((char *)event.data.scalar.value);
  }
  
  yaml_event_delete(&event);
  yaml_parser_delete(&parser);
  free(raw_yaml);
  
  return result;
}

// ---------------------------------------------------------------------------
// Content Handling Functions
// ---------------------------------------------------------------------------

static void md_contents_func(sqlite3_context *ctx, int argc, sqlite3_value **pp_value) {
  if (argc != 1) {
    sqlite3_result_error(ctx, "md_contents() requires exactly one argument", -1);
    return;
  }
  
  const char *abs_path = (const char *)sqlite3_value_text(pp_value[0]);
  if (!abs_path) {
    sqlite3_result_null(ctx);
    return;
  }
  
  // Read file contents
  FILE *file = fopen(abs_path, "rb");
  if (!file) {
    char *msg = sqlite3_mprintf("Could not read contents of %s: %s", 
                             abs_path, strerror(errno));
    sqlite3_result_error(ctx, msg, -1);
    sqlite3_free(msg);
    return;
  }
  
  // Get file size
  fseek(file, 0, SEEK_END);
  long file_size = ftell(file);
  fseek(file, 0, SEEK_SET);
  
  // Allocate buffer
  char *contents = sqlite3_malloc(file_size + 1);
  if (!contents) {
    fclose(file);
    sqlite3_result_error(ctx, "Out of memory", -1);
    return;
  }
  
  // Read file contents
  size_t bytes_read = fread(contents, 1, file_size, file);
  fclose(file);
  
  contents[bytes_read] = '\0';
  sqlite3_result_text(ctx, contents, bytes_read, sqlite3_free);
}

static void md_front_matter_func(sqlite3_context *ctx, int argc, sqlite3_value **pp_value) {
  if (argc != 2) {
    sqlite3_result_error(ctx, "md_front_matter() requires exactly two arguments", -1);
    return;
  }
  
  const char *abs_path = (const char *)sqlite3_value_text(pp_value[0]);
  const char *field = (const char *)sqlite3_value_text(pp_value[1]);
  
  if (!abs_path || !field) {
    sqlite3_result_null(ctx);
    return;
  }
  
  char *value = parse_front_matter(abs_path, field);
  
  if (value) {
    sqlite3_result_text(ctx, value, -1, free);
  } else {
    sqlite3_result_null(ctx);
  }
}

static void md_to_html_func(sqlite3_context *ctx, int argc, sqlite3_value **pp_value) {
  if (argc != 1) {
    sqlite3_result_error(ctx, "md_html() requires exactly one argument", -1);
    return;
  }
  
  const char *abs_path = (const char *)sqlite3_value_text(pp_value[0]);
  if (!abs_path) {
    sqlite3_result_null(ctx);
    return;
  }
  
  // Read file contents
  FILE *file = fopen(abs_path, "rb");
  if (!file) {
    char *msg = sqlite3_mprintf("Could not read contents of %s: %s", 
                             abs_path, strerror(errno));
    sqlite3_result_error(ctx, msg, -1);
    sqlite3_free(msg);
    return;
  }
  
  // Process markdown to extract content excluding front matter
  char line[4096];
  char *content = NULL;
  size_t content_len = 0;
  bool in_front_matter = false;
  bool frontmatter_done = false;
  
  // Read file line by line to skip front matter
  while (fgets(line, sizeof(line), file)) {
    size_t line_len = strlen(line);
    
    // Check if we're in front matter
    if (!frontmatter_done && line_len >= 3 && strncmp(line, "---", 3) == 0) {
      if (!in_front_matter) {
        // Start of front matter
        in_front_matter = true;
        continue;
      } else {
        // End of front matter
        in_front_matter = false;
        frontmatter_done = true;
        continue;
      }
    }
    
    // Skip lines in front matter
    if (in_front_matter) {
      continue;
    }
    
    // Add line to content
    if (content == NULL) {
      content = malloc(line_len + 1);
      if (!content) {
        fclose(file);
        sqlite3_result_error(ctx, "Out of memory", -1);
        return;
      }
      strcpy(content, line);
      content_len = line_len;
    } else {
      char *new_content = realloc(content, content_len + line_len + 1);
      if (!new_content) {
        free(content);
        fclose(file);
        sqlite3_result_error(ctx, "Out of memory", -1);
        return;
      }
      content = new_content;
      strcpy(content + content_len, line);
      content_len += line_len;
    }
  }
  
  fclose(file);
  
  if (!content) {
    // Empty file or only front matter
    sqlite3_result_text(ctx, "", 0, SQLITE_TRANSIENT);
    return;
  }
  
  // Convert to HTML
  char *html = cmark_markdown_to_html(content, content_len, 0);
  free(content);
  
  if (html) {
    sqlite3_result_text(ctx, html, -1, free);
  } else {
    sqlite3_result_null(ctx);
  }
}

// ---------------------------------------------------------------------------
// Module Registration
// ---------------------------------------------------------------------------

static const sqlite3_module MarkdownFilesVTabModule = {
  /* iVersion    */ 0,
  /* xCreate     */ vtabConnect,
  /* xConnect    */ vtabConnect,
  /* xBestIndex  */ vtabBestIndex,
  /* xDisconnect */ vtabDisconnect,
  /* xDestroy    */ vtabDisconnect,
  /* xOpen       */ vtabOpen,
  /* xClose      */ vtabClose,
  /* xFilter     */ vtabFilter,
  /* xNext       */ vtabNext,
  /* xEof        */ vtabEof,
  /* xColumn     */ vtabColumn,
  /* xRowid      */ vtabRowid,
  /* xUpdate     */ NULL,
  /* xBegin      */ NULL,
  /* xSync       */ NULL,
  /* xCommit     */ NULL,
  /* xRollback   */ NULL,
  /* xFindFunction */ NULL,
  /* xRename     */ NULL,
  /* xSavepoint  */ NULL,
  /* xRelease    */ NULL,
  /* xRollbackTo */ NULL,
  /* xShadowName */ NULL
};

int sqlite3_mdfiles_init(sqlite3 *db, char **pzErrMsg, 
                        const sqlite3_api_routines *pApi) {
  SQLITE_EXTENSION_INIT2(pApi);
  (void)pzErrMsg;
  
  int rc = sqlite3_initialize();
  if (rc != SQLITE_OK) {
    return rc;
  }
  
  // Register the virtual table module
  rc = sqlite3_create_module(db, "md_files", &MarkdownFilesVTabModule, NULL);
  if (rc != SQLITE_OK) {
    return rc;
  }
  
  // Register scalar functions
  rc = sqlite3_create_function_v2(
    db,
    "md_contents",
    1,
    SQLITE_UTF8,
    NULL,
    md_contents_func,
    NULL,
    NULL,
    NULL
  );
  if (rc != SQLITE_OK) {
    return rc;
  }
  
  rc = sqlite3_create_function_v2(
    db,
    "md_html",
    1,
    SQLITE_UTF8,
    NULL,
    md_to_html_func,
    NULL,
    NULL,
    NULL
  );
  if (rc != SQLITE_OK) {
    return rc;
  }
  
  // Register front matter function
  return sqlite3_create_function_v2(
    db,
    "md_front_matter",
    2,
    SQLITE_UTF8,
    NULL,
    md_front_matter_func,
    NULL,
    NULL,
    NULL
  );
}