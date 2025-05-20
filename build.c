#include <ctype.h>
#include <dirent.h>
#include <errno.h>
#include <time.h>

#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <fts.h>
#include <ftw.h>
#include <sys/stat.h>
#include <sys/types.h>

#ifndef _SITE_EXT_TARGET_DIR
#define _SITE_EXT_TARGET_DIR "/docs"
#endif

#define _SITE_TITLE            "Max's Homepage"
#define _SITE_SOURCE_DIR       "src/"
#define _SITE_INDEX_PATH       "index.html"
#define _SITE_STYLE_SHEET_PATH "style.css"
#define _SITE_PATH_MAX         100
#define _SITE_PAGES_MAX        50



typedef struct {
        const char *title;
        const char *subtitle;
        char created[26];       // ISO-8601 UTC -> 2023-11-19T20:44:13+09:00
        char updated[26];       // ISO-8601 UTC -> 2023-11-19T20:44:13+09:00
        char created_short[11]; // YYYY-MM-DD -> 2023-11-19
        char updated_short[11]; // YYYY-MM-DD -> 2023-11-19
        struct meta {
                char path[_SITE_PATH_MAX];
        } meta;
} page_header;

typedef struct {
        page_header *elems[_SITE_PAGES_MAX];
        int len;
} page_header_arr;

// utils
int __copy_file(const char *, const char *);
void __shorten_date(char *, char *, size_t);
FTS *__init_fts(const char *);
int __create_output_dirs(void);

// work with page headers
int compare_page_header(const void *, const void *);
int parse_page_header(FILE *, page_header *);

// main routines
page_header *process_page_file(FTSENT *);
int process_index_file(char *, page_header_arr *);
int create_html_page(page_header *, char *, const char *);
int create_html_index(char *, const char *, page_header_arr *);

int __copy_file(const char *from, const char *to) {
        FILE *from_file = NULL;
        FILE *to_file   = NULL;

        if ((from_file = fopen(from, "r")) == NULL) {
                fprintf(stderr, "from_file: %s\n\t%s (errno: %d, line: %d)\n", from,
                        strerror(errno), errno, __LINE__);
                return -1;
        }

        if ((to_file = fopen(to, "w")) == NULL) {
                fprintf(stderr, "to_file: %s\n\t%s (errno: %d, line: %d)\n", to, strerror(errno),
                        errno, __LINE__);
                fclose(from_file);
                return -1;
        }

        char *line     = NULL;
        size_t bufsize = 0;
        ssize_t len;
        int result = 0;
        while ((len = getline(&line, &bufsize, from_file)) > 0) {
                if (fwrite(line, 1, (size_t)len, to_file) != (size_t)len) {
                        fprintf(stderr, "%s (errno: %d, line: %d)\n", strerror(errno), errno,
                                __LINE__);
                        result = -1;
                        break;
                }
        }

        if (len < 0 && !feof(from_file) && ferror(from_file)) {
                fprintf(stderr, "%s (errno: %d, line: %d)\n", strerror(errno), errno, __LINE__);
                result = -1;
        }

        free(line);
        fclose(from_file);
        fclose(to_file);

        return result;
}

int __create_output_dirs(void) {
        mode_t mode = S_IRWXU | S_IRGRP | S_IXGRP | S_IROTH | S_IXOTH;

        if (mkdir(_SITE_EXT_TARGET_DIR, mode) != 0 && errno != EEXIST) {
                fprintf(stderr, "%s (errno: %d, line: %d)\n", strerror(errno), errno, __LINE__);
                return -1;
        }

        if (mkdir(_SITE_EXT_TARGET_DIR, mode) != 0 && errno != EEXIST) {
                fprintf(stderr, "%s (errno: %d, line: %d)\n", strerror(errno), errno, __LINE__);
                return -1;
        }
        return 0;
}

FTS *__init_fts(const char *source) {
        FTS *ftsp        = NULL;
        char *paths[]    = {(char *)source, NULL};
        int _fts_options = FTS_COMFOLLOW | FTS_LOGICAL | FTS_NOCHDIR;

        if ((ftsp = fts_open(paths, _fts_options, NULL)) == NULL) {
                fprintf(stderr, "%s (errno: %d, line: %d)\n", strerror(errno), errno, __LINE__);
                return NULL;
        }

        if (fts_children(ftsp, 0) == NULL) {
                printf("No pages to convert. Aborting\n");
                return NULL;
        }

        return ftsp;
}

int compare_page_header(const void *a, const void *b) {
        const page_header *header_a = (const page_header *)a;
        const page_header *header_b = (const page_header *)b;

        return strcmp(header_a->created, header_b->created);
}

void __shorten_date(char *in, char *out, size_t size) {
        int year, month, day;
        sscanf(in, "%d-%d-%d", &year, &month, &day);
        snprintf(out, size, "%04d-%02d-%02d", year, month, day);
}

int parse_page_header(FILE *file, page_header *header) {
        char *line    = NULL;
        size_t len    = 0;
        ssize_t read  = 0;
        ssize_t readt = 0;

        bool in_header = true;
        while (in_header && (readt += read = getline(&line, &len, file))) {
                // newline
                if (read <= 1 || line[0] == '\n') {
                        in_header = false;
                        return (int)readt;
                }

                // remove newline
                if (line[read - 1] == '\n') {
                        line[read - 1] = '\0';
                }

                // split fields
                char *colon = strchr(line, ':');
                if (!colon) continue;
                *colon      = '\0';
                char *key   = line;
                char *value = colon + 1;

                while (isspace(*value)) {
                        value++;
                }

                if (!value) {
                        value = "";
                }

                if (strncmp(key, "title", read) == 0) header->title = strdup(value);
                else if (strncmp(key, "subtitle", read) == 0) header->subtitle = strdup(value);
                else if (strncmp(key, "updated", read) == 0) strcpy(header->updated, value);
                else if (strncmp(key, "created", read) == 0) strcpy(header->created, value);

                char date_created_short[11] = "";
                __shorten_date(header->created, date_created_short, sizeof(date_created_short));
                strcpy(header->created_short, date_created_short);

                char date_updated_short[11] = "";
                __shorten_date(header->updated, date_updated_short, sizeof(date_updated_short));
                strcpy(header->updated_short, date_updated_short);
        }

        return (int)readt;
}

int create_html_index(char *page_content, const char *output_path, page_header_arr *header_arr) {
        // html destination
        FILE *dest_file = fopen(output_path, "w");
        if (dest_file == NULL) {
                fprintf(stderr, "Failed to create %s: %s\n", output_path, strerror(errno));
                return -1;
        }

        int fprintf_ret = 0;

        fprintf_ret = fprintf(
            dest_file,
            "<!DOCTYPE html>\n"
            "<html lang=\"en\">\n"
            "<head>\n"
            "	<meta charset=\"utf-8\">\n"
            "    	<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">\n"
            "    	<link href=\"/atom.xml\" type=\"application/atom+xml\" rel=\"alternate\">\n"
            "    	<link rel=\"stylesheet\" href=\"%s\" type=\"text/css\">\n"
            "		<link rel=\"preconnect\" href=\"https://fonts.googleapis.com\"\n>"
            "		<link rel=\"preconnect\" href=\"https://fonts.gstatic.com\" crossorigin>\n"
            "		<link "
            // clang-format off
            "		<link href=\"https://fonts.googleapis.com/css2?family=Source+Serif+4:ital,opsz,wght@0,8..60,200..900;1,8..60,200..900&display=swap\" rel=\"stylesheet\">\n"
            // clang-format on
            "    	<title>%s</title>\n"
            "</head>\n"
            "<body>\n"
            "	<main>\n",
            _SITE_STYLE_SHEET_PATH, _SITE_TITLE);

        // content
        char *dest_line = strtok((char *)page_content, "\n");
        while (dest_line) {
                if (!*dest_line) continue;
                fprintf_ret = fprintf(dest_file, "%s\n", dest_line);
                dest_line   = strtok(NULL, "\n");
        }

        // sort by creation time
        qsort(header_arr->elems, header_arr->len, sizeof(page_header), compare_page_header);

        // add a list of posts to the index
        fprintf_ret = fprintf(dest_file, "<section class=\"index-block\">\n"
                                         "<h3 id=\"entries\">Entries</h3>\n "
                                         "<dl id=\"post-list\">\n");

        for (int i = 0; i < header_arr->len; i++) {
                fprintf_ret = fprintf(dest_file,
                                      "<dt><b><a href=\"%s\">%s</a></b></dt>\n"
                                      "<dd>%s</dd>\n",
                                      header_arr->elems[i]->meta.path, header_arr->elems[i]->title,
                                      header_arr->elems[i]->subtitle);
        }
        fprintf_ret = fprintf(dest_file, "</dl>\n"
                                         "</section>\n");

        // close <main>
        fprintf_ret = fprintf(dest_file, "	</main>\n"
                                         "</body>\n"
                                         "</html>\n");

        if (fprintf_ret < 0) {
                fprintf(stderr, "%s (errno: %d, line: %d)\n", strerror(errno), errno, __LINE__);
                fclose(dest_file);
                return -1;
        }

        fclose(dest_file);

        return 0;
}

int create_html_page(page_header *header, char *page_content, const char *output_path) {
        // html destination
        FILE *dest_file = fopen(output_path, "w");
        if (dest_file == NULL) {
                fprintf(stderr, "Failed to create %s: %s\n", output_path, strerror(errno));
                free(header);
                return -1;
        }

        int fprintf_ret = 0;

        struct tm tm;

        // UTC encoded ISO-8601 full timestamp: 2023-11-19T20:44:13+09:00
        char created_formatted[256];
        strptime(header->created, "%Y-%m-%dT%H:%M:%S%z", &tm);
        strftime(created_formatted, sizeof(created_formatted), "%d %b %Y", &tm);

        fprintf_ret = fprintf(
            dest_file,
            "<!DOCTYPE html>\n"
            "<html lang=\"en\">\n"
            "<head>\n"
            "	<meta charset=\"utf-8\">\n"
            "    	<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">\n"
            "    	<link href=\"/atom.xml\" type=\"application/atom+xml\" rel=\"alternate\">\n"
            "    	<link rel=\"stylesheet\" href=\"%s\" type=\"text/css\">\n"
            "		<link rel=\"preconnect\" href=\"https://fonts.googleapis.com\"\n>"
            "		<link rel=\"preconnect\" href=\"https://fonts.gstatic.com\" crossorigin>\n"
            // clang-format off
            "		<link href=\"https://fonts.googleapis.com/css2?family=Source+Serif+4:ital,opsz,wght@0,8..60,200..900;1,8..60,200..900&display=swap\" rel=\"stylesheet\">\n"
            // clang-format on
            "    	<title>%s</title>\n"
            "</head>\n"
            "<body>\n"
            "	<header>\n"
            "		<a href=\"/\">%s</a>\n"
            "	</header>\n"
            "	<main>\n",
            _SITE_STYLE_SHEET_PATH, header->title, created_formatted);

        // add (sub)title
        if (header->title) {
                fprintf_ret = fprintf(dest_file, "<h1>%s</h1>\n", header->title);
        }
        if (header->subtitle) {
                fprintf_ret = fprintf(dest_file, "<p>%s</p>\n", header->subtitle);
        }

        // content
        char *line = strtok((char *)page_content, "\n");
        while (line) {
                if (!*line) continue;
                fprintf_ret = fprintf(dest_file, "%s\n", line);
                line        = strtok(NULL, "\n");
        }

        // close <main>
        fprintf(dest_file,
                "	</main>\n"
                "	<footer>\n"
                "		<small id=\"date-updated\">Last Updated on %s</small>\n"
                "	</footer>\n"
                "</body>\n"
                "</html>\n",
                header->updated_short);

        if (fprintf_ret < 0) {
                fprintf(stderr, "%s (errno: %d, line: %d)\n", strerror(errno), errno, __LINE__);
                fclose(dest_file);
                return -1;
        }

        fclose(dest_file);

        return 0;
}

page_header *process_page_file(FTSENT *ftsentp) {
        int iserror = false;

        FILE *source_file = fopen(ftsentp->fts_path, "r");
        if (source_file == NULL) {
                fprintf(stderr, "Failed to open source %s: %s (errno: %d, line: %d)\n",
                        ftsentp->fts_path, strerror(errno), errno, __LINE__);
                return NULL;
        }

        // output path
        char page_path[_SITE_PATH_MAX];
        snprintf(page_path, sizeof(page_path), "%s/%s", _SITE_EXT_TARGET_DIR, ftsentp->fts_name);

        page_header *header = calloc(1, sizeof(page_header));
        if (header == NULL) {
                fprintf(stderr, "Memory allocation failed\n");
                free(header);
                fclose(source_file);
                return NULL;
        }
        char page_href[100] = "/";
        strcat(page_href, ftsentp->fts_name);
        strncpy(header->meta.path, page_href, _SITE_PATH_MAX - 1);

        // read content
        int header_len      = parse_page_header(source_file, header);
        size_t content_size = ftsentp->fts_statp->st_size - header_len;
        char *page_content  = malloc(content_size + 1);
        if (page_content == NULL) {
                fprintf(stderr, "Memory allocation failed for content\n");
                iserror = true;
        }
        size_t bytes_read = fread(page_content, 1, content_size, source_file);
        if (bytes_read != content_size) {
                if (feof(source_file)) {
                        printf("Page has no content. Aborting.\n");
                        iserror = true;
                } else if (ferror(source_file)) {
                        fprintf(stderr, "Failed to open source %s: %s (errno: %d, line: %d)\n",
                                ftsentp->fts_path, strerror(errno), errno, __LINE__);
                        iserror = true;
                }
        }

        // create valid html file
        if (create_html_page(header, page_content, page_path) != 0) {
        };

        // cleanup
        fclose(source_file);

        return iserror ? NULL : header;
}

int process_index_file(char *index_file_path, page_header_arr *header_arr) {
        int result = 0;

        FILE *source_file = fopen(index_file_path, "r");
        if (source_file == NULL) {
                fprintf(stderr, "Failed to open source %s: %s (errno: %d, line: %d)\n",
                        index_file_path, strerror(errno), errno, __LINE__);
                result = -1;
        }

        struct stat source_file_stat;
        if (stat(index_file_path, &source_file_stat) != 0) {
                fprintf(stderr, "%s (errno: %d, line: %d)\n", strerror(errno), errno, __LINE__);
                fclose(source_file);
                result = -1;
        }

        // output path
        char page_path[_SITE_PATH_MAX];
        const char *filename = strrchr(index_file_path, '/');
        filename ? filename++ : (filename = index_file_path);
        snprintf(page_path, sizeof(page_path), "%s/%s", _SITE_EXT_TARGET_DIR, filename);

        page_header *header = calloc(1, sizeof(page_header));
        if (header == NULL) {
                fprintf(stderr, "Memory allocation failed\n");
                fclose(source_file);
                result = -1;
        }

        // read content
        int header_len      = parse_page_header(source_file, header);
        size_t content_size = source_file_stat.st_size - header_len;
        char *page_content  = malloc(content_size + 1);
        if (page_content == NULL) {
                fprintf(stderr, "Memory allocation failed for content\n");
                result = -1;
        }

        ssize_t bytes_read = fread(page_content, 1, source_file_stat.st_size, source_file);
        if (bytes_read != source_file_stat.st_size - header_len) {
                if (feof(source_file)) {
                        printf("Unexpected EOF. Read %zu bytes, expected %jd\n", bytes_read,
                               (intmax_t)source_file_stat.st_size);
                        result = -1;
                } else if (ferror(source_file)) {
                        fprintf(stderr, "Failed to read from source %s: %s (errno: %d, line: %d)\n",
                                index_file_path, strerror(errno), errno, __LINE__);
                        result = -1;
                }
                free(page_content);
                fclose(source_file);
                return result;
        }
        page_content[bytes_read] = '\0';

        result = create_html_index(page_content, page_path, header_arr);

        // cleanup
        free(page_content);
        fclose(source_file);

        return result;
}

int main(void) {
        int result = 0;

        FTS *ftsp       = NULL;
        FTSENT *ftsentp = NULL;

        page_header_arr header_arr = {
            .elems = {0},
            .len   = 0,
        };

        if (__create_output_dirs() != 0) {
                result = -1;
        }

        if (__copy_file(_SITE_SOURCE_DIR _SITE_STYLE_SHEET_PATH,
                        _SITE_EXT_TARGET_DIR _SITE_STYLE_SHEET_PATH) != 0) {
                result = -1;
        }

        if ((ftsp = __init_fts(_SITE_SOURCE_DIR)) == NULL) {
                result = -1;
        }

        while ((ftsentp = fts_read(ftsp)) != NULL) {
                // we only care for plain non-hidden files
                if (ftsentp->fts_info != FTS_F) continue;
                if (ftsentp->fts_name[0] == '.') continue;

                char *dot = strrchr(ftsentp->fts_name, '.');
                if (dot == NULL) continue;
                char *ext = dot + 1;

                // non-html files
                if (strcmp(ext, "html") != 0) {
                        char to_path[_SITE_PATH_MAX];
                        to_path[0] = '\0';

                        strlcat(to_path, _SITE_EXT_TARGET_DIR, sizeof(to_path));
                        size_t path_len = strlen(to_path);

                        // possibly add path separator
                        if (path_len > 0 && to_path[path_len - 1] != '/' &&
                            path_len + 1 < sizeof(to_path)) {
                                to_path[path_len]     = '/';
                                to_path[path_len + 1] = '\0';
                        }

                        strlcat(to_path, ftsentp->fts_name, sizeof(to_path));

                        __copy_file(ftsentp->fts_path, to_path);
                        continue;
                }

                // ignore index for now
                if (strcmp(ftsentp->fts_name, _SITE_INDEX_PATH) == 0) {
                        continue;
                }

                page_header *header = NULL;
                if ((header = process_page_file(ftsentp)) == NULL) {
                        result = -1;
                } else {
                        header_arr.elems[header_arr.len] = header;
                        header_arr.len++;
                }
        }

        if (process_index_file(_SITE_SOURCE_DIR _SITE_INDEX_PATH, &header_arr) != 0) {
                fts_close(ftsp);
                result = -1;
        }

        fts_close(ftsp);

        for (int i = 0; i < header_arr.len; i++) {
                free((char *)header_arr.elems[i]->title);
                free((char *)header_arr.elems[i]->subtitle);
                free(header_arr.elems[i]);
        }

        return result;
}
