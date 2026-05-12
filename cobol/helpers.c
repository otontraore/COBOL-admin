/*
 * C helper library for COBOL Admin
 * Provides HTTP (libcurl) and JSON (cJSON) functions
 * callable from GnuCOBOL via CALL "function-name"
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include <curl/curl.h>
#include "cJSON.h"

static void copy_cobol_string(char *dest, size_t dest_size,
                              const char *src, size_t src_size) {
    size_t len = 0;
    while (len < src_size && src[len] && src[len] != '\0') len++;
    while (len > 0 && (src[len - 1] == ' ' || src[len - 1] == '\0')) len--;
    if (len >= dest_size) len = dest_size - 1;
    memcpy(dest, src, len);
    dest[len] = 0;
}

static void blank_cobol_field(char *field, size_t field_size) {
    memset(field, ' ', field_size);
}

static void write_cobol_field(char *field, size_t field_size,
                              const char *value) {
    blank_cobol_field(field, field_size);
    if (!value) return;
    size_t len = strlen(value);
    if (len > field_size) len = field_size;
    memcpy(field, value, len);
}

static int permission_list_has(const char *permissions,
                               const char *needle) {
    if (!permissions || !needle || !needle[0]) return 0;
    size_t needle_len = strlen(needle);
    const char *cursor = permissions;
    while (*cursor) {
        while (*cursor == ' ' || *cursor == ',') cursor++;
        const char *start = cursor;
        while (*cursor && *cursor != ',') cursor++;
        const char *end = cursor;
        while (end > start && isspace((unsigned char)end[-1])) end--;
        if ((size_t)(end - start) == needle_len &&
            strncmp(start, needle, needle_len) == 0) {
            return 1;
        }
    }
    return 0;
}

static void add_form_value(cJSON *obj, const char *key, const char *val) {
    int force_array = 0;
    char clean_key[256];
    strncpy(clean_key, key, sizeof(clean_key) - 1);
    clean_key[sizeof(clean_key) - 1] = 0;

    size_t key_len = strlen(clean_key);
    if (key_len > 2 && strcmp(clean_key + key_len - 2, "[]") == 0) {
        clean_key[key_len - 2] = 0;
        force_array = 1;
    }

    cJSON *existing = cJSON_GetObjectItem(obj, clean_key);
    if (force_array) {
        cJSON *array = existing && cJSON_IsArray(existing) ? existing : NULL;
        if (!array) {
            array = cJSON_CreateArray();
            if (existing) cJSON_DeleteItemFromObject(obj, clean_key);
            cJSON_AddItemToObject(obj, clean_key, array);
        }

        char value_copy[2048];
        strncpy(value_copy, val, sizeof(value_copy) - 1);
        value_copy[sizeof(value_copy) - 1] = 0;
        char *token = strtok(value_copy, ",");
        while (token) {
            while (*token == ' ') token++;
            char *end = token + strlen(token);
            while (end > token && isspace((unsigned char)end[-1])) *--end = 0;
            if (*token) cJSON_AddItemToArray(array, cJSON_CreateString(token));
            token = strtok(NULL, ",");
        }
        return;
    }

    if (existing) {
        cJSON *array = NULL;
        if (cJSON_IsArray(existing)) {
            array = existing;
        } else {
            array = cJSON_CreateArray();
            cJSON_AddItemToArray(array, cJSON_Duplicate(existing, 1));
            cJSON_DeleteItemFromObject(obj, clean_key);
            cJSON_AddItemToObject(obj, clean_key, array);
        }
        cJSON_AddItemToArray(array, cJSON_CreateString(val));
    } else {
        cJSON_AddStringToObject(obj, clean_key, val);
    }
}

static const char *find_case_insensitive(const char *haystack,
                                         const char *needle) {
    size_t needle_len = strlen(needle);
    if (needle_len == 0) return haystack;
    for (const char *cursor = haystack; *cursor; cursor++) {
        size_t idx = 0;
        while (idx < needle_len && cursor[idx] &&
               tolower((unsigned char)cursor[idx]) ==
               tolower((unsigned char)needle[idx])) {
            idx++;
        }
        if (idx == needle_len) return cursor;
    }
    return NULL;
}

/* --- HTTP helpers using libcurl --- */

int cobol_http_get(const char *url, const char *response_file,
                   const char *header_file) {
    CURL *curl = curl_easy_init();
    if (!curl) return -1;

    FILE *resp = fopen(response_file, "w");
    if (!resp) { curl_easy_cleanup(curl); return -2; }

    FILE *hdrs = NULL;
    if (header_file && header_file[0]) {
        hdrs = fopen(header_file, "w");
    }

    curl_easy_setopt(curl, CURLOPT_URL, url);
    curl_easy_setopt(curl, CURLOPT_WRITEDATA, resp);
    if (hdrs) {
        curl_easy_setopt(curl, CURLOPT_HEADERDATA, hdrs);
    }
    curl_easy_setopt(curl, CURLOPT_FOLLOWLOCATION, 1L);
    curl_easy_setopt(curl, CURLOPT_TIMEOUT, 10L);

    CURLcode res = curl_easy_perform(curl);

    long http_code = 0;
    curl_easy_getinfo(curl, CURLINFO_RESPONSE_CODE, &http_code);

    fclose(resp);
    if (hdrs) fclose(hdrs);
    curl_easy_cleanup(curl);

    if (res != CURLE_OK) return -3;
    if (http_code >= 400) return (int)http_code;
    return 0;
}

int cobol_http_put(const char *url, const char *json_file) {
    /* Read JSON body from file */
    FILE *f = fopen(json_file, "r");
    if (!f) return -2;
    fseek(f, 0, SEEK_END);
    long len = ftell(f);
    fseek(f, 0, SEEK_SET);
    char *body = malloc(len + 1);
    if (!body) { fclose(f); return -4; }
    fread(body, 1, len, f);
    body[len] = 0;
    fclose(f);

    CURL *curl = curl_easy_init();
    if (!curl) { free(body); return -1; }

    struct curl_slist *headers = NULL;
    headers = curl_slist_append(headers, "Content-Type: application/json");

    curl_easy_setopt(curl, CURLOPT_URL, url);
    curl_easy_setopt(curl, CURLOPT_CUSTOMREQUEST, "PUT");
    curl_easy_setopt(curl, CURLOPT_POSTFIELDS, body);
    curl_easy_setopt(curl, CURLOPT_HTTPHEADER, headers);
    curl_easy_setopt(curl, CURLOPT_TIMEOUT, 10L);

    /* Discard response body */
    FILE *devnull = fopen("/dev/null", "w");
    if (devnull) curl_easy_setopt(curl, CURLOPT_WRITEDATA, devnull);

    CURLcode res = curl_easy_perform(curl);

    long http_code = 0;
    curl_easy_getinfo(curl, CURLINFO_RESPONSE_CODE, &http_code);

    if (devnull) fclose(devnull);
    curl_slist_free_all(headers);
    curl_easy_cleanup(curl);
    free(body);

    if (res != CURLE_OK) return -3;
    if (http_code >= 400) return (int)http_code;
    return 0;
}

int cobol_http_delete(const char *url) {
    CURL *curl = curl_easy_init();
    if (!curl) return -1;

    curl_easy_setopt(curl, CURLOPT_URL, url);
    curl_easy_setopt(curl, CURLOPT_CUSTOMREQUEST, "DELETE");
    curl_easy_setopt(curl, CURLOPT_TIMEOUT, 10L);

    FILE *devnull = fopen("/dev/null", "w");
    if (devnull) curl_easy_setopt(curl, CURLOPT_WRITEDATA, devnull);

    CURLcode res = curl_easy_perform(curl);

    long http_code = 0;
    curl_easy_getinfo(curl, CURLINFO_RESPONSE_CODE, &http_code);

    if (devnull) fclose(devnull);
    curl_easy_cleanup(curl);

    if (res != CURLE_OK) return -3;
    if (http_code >= 400) return (int)http_code;
    return 0;
}

int cobol_http_post(const char *url, const char *json_file,
                    const char *response_file) {
    /* Read JSON body from file */
    FILE *f = fopen(json_file, "r");
    if (!f) return -2;
    fseek(f, 0, SEEK_END);
    long len = ftell(f);
    fseek(f, 0, SEEK_SET);
    char *body = malloc(len + 1);
    if (!body) { fclose(f); return -4; }
    fread(body, 1, len, f);
    body[len] = 0;
    fclose(f);

    CURL *curl = curl_easy_init();
    if (!curl) { free(body); return -1; }

    struct curl_slist *headers = NULL;
    headers = curl_slist_append(headers, "Content-Type: application/json");

    FILE *resp = fopen(response_file, "w");
    if (!resp) { free(body); curl_easy_cleanup(curl); return -2; }

    curl_easy_setopt(curl, CURLOPT_URL, url);
    curl_easy_setopt(curl, CURLOPT_POSTFIELDS, body);
    curl_easy_setopt(curl, CURLOPT_HTTPHEADER, headers);
    curl_easy_setopt(curl, CURLOPT_WRITEDATA, resp);
    curl_easy_setopt(curl, CURLOPT_TIMEOUT, 10L);

    CURLcode res = curl_easy_perform(curl);

    long http_code = 0;
    curl_easy_getinfo(curl, CURLINFO_RESPONSE_CODE, &http_code);

    fclose(resp);
    curl_slist_free_all(headers);
    curl_easy_cleanup(curl);
    free(body);

    if (res != CURLE_OK) return -3;
    if (http_code >= 400) return (int)http_code;
    return 0;
}

/*
 * Extract "id" field from a JSON file, return as integer
 */
int cobol_json_extract_id(const char *json_file, int *id_out) {
    *id_out = 0;
    FILE *f = fopen(json_file, "r");
    if (!f) return -1;
    fseek(f, 0, SEEK_END);
    long len = ftell(f);
    fseek(f, 0, SEEK_SET);
    char *data = malloc(len + 1);
    if (!data) { fclose(f); return -2; }
    fread(data, 1, len, f);
    data[len] = 0;
    fclose(f);

    cJSON *root = cJSON_Parse(data);
    free(data);
    if (!root) return -3;

    cJSON *id = cJSON_GetObjectItem(root, "id");
    if (id && cJSON_IsNumber(id)) {
        *id_out = id->valueint;
    }
    cJSON_Delete(root);
    return 0;
}

/* --- JSON helpers using cJSON --- */

/*
 * Convert a JSON object to TSV: key<tab>value per line
 * Arrays are joined with ", "
 * Mode: "object" = single object, "array" = array of objects
 */
int cobol_json_to_tsv(const char *json_file, const char *tsv_file,
                      const char *mode, const char *fields_csv) {
    FILE *f = fopen(json_file, "r");
    if (!f) return -1;
    fseek(f, 0, SEEK_END);
    long len = ftell(f);
    fseek(f, 0, SEEK_SET);
    char *data = malloc(len + 1);
    if (!data) { fclose(f); return -2; }
    fread(data, 1, len, f);
    data[len] = 0;
    fclose(f);

    cJSON *root = cJSON_Parse(data);
    free(data);
    if (!root) return -3;

    FILE *out = fopen(tsv_file, "w");
    if (!out) { cJSON_Delete(root); return -4; }

    if (strcmp(mode, "object") == 0) {
        /* Single object: output key<tab>value per property */
        cJSON *item;
        cJSON_ArrayForEach(item, root) {
            if (cJSON_IsArray(item)) {
                fprintf(out, "%s\t", item->string);
                int first = 1;
                cJSON *el;
                cJSON_ArrayForEach(el, item) {
                    if (!first) fprintf(out, ", ");
                    if (cJSON_IsString(el))
                        fprintf(out, "%s", el->valuestring);
                    else {
                        char *s = cJSON_PrintUnformatted(el);
                        fprintf(out, "%s", s);
                        free(s);
                    }
                    first = 0;
                }
                fprintf(out, "\n");
            } else if (cJSON_IsString(item)) {
                fprintf(out, "%s\t%s\n", item->string,
                        item->valuestring);
            } else {
                char *s = cJSON_PrintUnformatted(item);
                fprintf(out, "%s\t%s\n", item->string, s);
                free(s);
            }
        }
    } else if (strcmp(mode, "array") == 0 && fields_csv) {
        /* Array of objects: output field values as TSV rows */
        /* Parse fields_csv into array */
        char fields_buf[2048];
        strncpy(fields_buf, fields_csv, sizeof(fields_buf) - 1);
        fields_buf[sizeof(fields_buf) - 1] = 0;

        char *field_names[64];
        int field_count = 0;
        char *tok = strtok(fields_buf, ",");
        while (tok && field_count < 64) {
            /* trim leading spaces */
            while (*tok == ' ') tok++;
            field_names[field_count++] = tok;
            tok = strtok(NULL, ",");
        }

        cJSON *row;
        cJSON_ArrayForEach(row, root) {
            for (int i = 0; i < field_count; i++) {
                if (i > 0) fprintf(out, "\t");
                cJSON *val = cJSON_GetObjectItem(row,
                                                  field_names[i]);
                if (!val || cJSON_IsNull(val)) {
                    /* empty */
                } else if (cJSON_IsString(val)) {
                    fprintf(out, "%s", val->valuestring);
                } else if (cJSON_IsArray(val)) {
                    int first = 1;
                    cJSON *el;
                    cJSON_ArrayForEach(el, val) {
                        if (!first) fprintf(out, ", ");
                        if (cJSON_IsString(el))
                            fprintf(out, "%s", el->valuestring);
                        else {
                            char *s = cJSON_PrintUnformatted(el);
                            fprintf(out, "%s", s);
                            free(s);
                        }
                        first = 0;
                    }
                } else {
                    char *s = cJSON_PrintUnformatted(val);
                    fprintf(out, "%s", s);
                    free(s);
                }
            }
            fprintf(out, "\n");
        }
    }

    fclose(out);
    cJSON_Delete(root);
    return 0;
}

/*
 * Extract unique base resource paths from OpenAPI JSON
 * Reads .paths keys, splits on "/", takes [1], deduplicates
 * Outputs one resource name per line, sorted
 */
int cobol_json_resources(const char *json_file,
                         const char *output_file) {
    FILE *f = fopen(json_file, "r");
    if (!f) return -1;
    fseek(f, 0, SEEK_END);
    long len = ftell(f);
    fseek(f, 0, SEEK_SET);
    char *data = malloc(len + 1);
    if (!data) { fclose(f); return -2; }
    fread(data, 1, len, f);
    data[len] = 0;
    fclose(f);

    cJSON *root = cJSON_Parse(data);
    free(data);
    if (!root) return -3;

    cJSON *paths = cJSON_GetObjectItem(root, "paths");
    if (!paths) { cJSON_Delete(root); return -4; }

    /* Collect unique resource names */
    char resources[100][64];
    int count = 0;

    cJSON *path;
    cJSON_ArrayForEach(path, paths) {
        const char *key = path->string;
        if (key[0] == '/') key++;
        /* Extract first segment */
        char seg[64] = {0};
        int i = 0;
        while (key[i] && key[i] != '/' && i < 63) {
            seg[i] = key[i];
            i++;
        }
        seg[i] = 0;
        if (seg[0] == 0) continue;
        if (strcmp(seg, "auth") == 0) continue;

        /* Check for duplicate */
        int dup = 0;
        for (int j = 0; j < count; j++) {
            if (strcmp(resources[j], seg) == 0) { dup = 1; break; }
        }
        if (!dup && count < 100) {
            strcpy(resources[count++], seg);
        }
    }

    /* Sort */
    for (int i = 0; i < count - 1; i++)
        for (int j = i + 1; j < count; j++)
            if (strcmp(resources[i], resources[j]) > 0) {
                char tmp[64];
                strcpy(tmp, resources[i]);
                strcpy(resources[i], resources[j]);
                strcpy(resources[j], tmp);
            }

    FILE *out = fopen(output_file, "w");
    if (!out) { cJSON_Delete(root); return -5; }
    for (int i = 0; i < count; i++)
        fprintf(out, "%s\n", resources[i]);
    fclose(out);

    cJSON_Delete(root);
    return 0;
}

/*
 * Extract fields for a resource from OpenAPI schema
 * Resolves $ref from the GET response, reads properties
 * Checks if *Input schema has the field (editable flag)
 * Output: name<tab>type<tab>editable(1/0) per line
 */
int cobol_json_fields(const char *json_file, const char *resource,
                      const char *output_file) {
    FILE *f = fopen(json_file, "r");
    if (!f) return -1;
    fseek(f, 0, SEEK_END);
    long len = ftell(f);
    fseek(f, 0, SEEK_SET);
    char *data = malloc(len + 1);
    if (!data) { fclose(f); return -2; }
    fread(data, 1, len, f);
    data[len] = 0;
    fclose(f);

    cJSON *root = cJSON_Parse(data);
    free(data);
    if (!root) return -3;

    /* Build path key: /{resource} */
    char path_key[128];
    snprintf(path_key, sizeof(path_key), "/%s", resource);

    cJSON *paths = cJSON_GetObjectItem(root, "paths");
    cJSON *path_obj = cJSON_GetObjectItem(paths, path_key);
    if (!path_obj) { cJSON_Delete(root); return -4; }

    /* Navigate: .get.responses.200.content.application/json.schema */
    cJSON *get_op = cJSON_GetObjectItem(path_obj, "get");
    if (!get_op) { cJSON_Delete(root); return -4; }
    cJSON *responses = cJSON_GetObjectItem(get_op, "responses");
    cJSON *r200 = cJSON_GetObjectItem(responses, "200");
    cJSON *content = cJSON_GetObjectItem(r200, "content");
    cJSON *json_ct = cJSON_GetObjectItem(content,
                                          "application/json");
    cJSON *schema = cJSON_GetObjectItem(json_ct, "schema");

    /* Resolve $ref from items or directly */
    cJSON *ref = NULL;
    cJSON *items = cJSON_GetObjectItem(schema, "items");
    if (items) ref = cJSON_GetObjectItem(items, "$ref");
    if (!ref) ref = cJSON_GetObjectItem(schema, "$ref");
    if (!ref || !cJSON_IsString(ref)) {
        cJSON_Delete(root);
        return -5;
    }

    /* Extract schema name from "#/components/schemas/Name" */
    const char *ref_str = ref->valuestring;
    const char *schema_name = strrchr(ref_str, '/');
    if (!schema_name) { cJSON_Delete(root); return -5; }
    schema_name++; /* skip '/' */

    /* Get the schema */
    cJSON *components = cJSON_GetObjectItem(root, "components");
    cJSON *schemas = cJSON_GetObjectItem(components, "schemas");
    cJSON *the_schema = cJSON_GetObjectItem(schemas, schema_name);
    if (!the_schema) { cJSON_Delete(root); return -6; }

    cJSON *properties = cJSON_GetObjectItem(the_schema,
                                             "properties");
    if (!properties) { cJSON_Delete(root); return -6; }

    /* Build Input schema name */
    char input_name[128];
    snprintf(input_name, sizeof(input_name), "%sInput", schema_name);
    cJSON *input_schema = cJSON_GetObjectItem(schemas, input_name);
    cJSON *input_props = input_schema ?
        cJSON_GetObjectItem(input_schema, "properties") : NULL;

    FILE *out = fopen(output_file, "w");
    if (!out) { cJSON_Delete(root); return -7; }

    cJSON *prop;
    cJSON_ArrayForEach(prop, properties) {
        const char *name = prop->string;
        cJSON *type_obj = cJSON_GetObjectItem(prop, "type");
        const char *type = type_obj && cJSON_IsString(type_obj) ?
            type_obj->valuestring : "string";
        int editable = input_props &&
            cJSON_GetObjectItem(input_props, name) ? 1 : 0;
        fprintf(out, "%s\t%s\t%d\n", name, type, editable);
    }

    fclose(out);
    cJSON_Delete(root);
    return 0;
}

/*
 * Convert URL-encoded form data to JSON
 * Reads from input_file, writes JSON to output_file
 */
int cobol_form_to_json(const char *input_file,
                       const char *output_file) {
    FILE *f = fopen(input_file, "r");
    if (!f) return -1;
    fseek(f, 0, SEEK_END);
    long len = ftell(f);
    fseek(f, 0, SEEK_SET);
    char *data = malloc(len + 1);
    if (!data) { fclose(f); return -2; }
    fread(data, 1, len, f);
    data[len] = 0;
    fclose(f);

    /* Trim trailing whitespace/nulls */
    while (len > 0 && (data[len-1] == ' ' || data[len-1] == '\n'
           || data[len-1] == '\r' || data[len-1] == 0))
        data[--len] = 0;

    cJSON *obj = cJSON_CreateObject();
    if (!obj) { free(data); return -3; }

    /* Parse key=value&key=value */
    char *ptr = data;
    while (ptr && *ptr) {
        char *amp = strchr(ptr, '&');
        if (amp) *amp = 0;

        char *eq = strchr(ptr, '=');
        if (eq) {
            *eq = 0;
            char *key = ptr;
            char *val = eq + 1;

            /* URL-decode value in-place */
            char *src = val, *dst = val;
            while (*src) {
                if (*src == '+') {
                    *dst++ = ' ';
                    src++;
                } else if (*src == '%' && src[1] && src[2]) {
                    char hex[3] = { src[1], src[2], 0 };
                    *dst++ = (char)strtol(hex, NULL, 16);
                    src += 3;
                } else {
                    *dst++ = *src++;
                }
            }
            *dst = 0;

            /* URL-decode key in-place */
            src = key; dst = key;
            while (*src) {
                if (*src == '+') {
                    *dst++ = ' ';
                    src++;
                } else if (*src == '%' && src[1] && src[2]) {
                    char hex[3] = { src[1], src[2], 0 };
                    *dst++ = (char)strtol(hex, NULL, 16);
                    src += 3;
                } else {
                    *dst++ = *src++;
                }
            }
            *dst = 0;

            add_form_value(obj, key, val);
        }

        ptr = amp ? amp + 1 : NULL;
    }

    char *json = cJSON_PrintUnformatted(obj);
    cJSON_Delete(obj);
    free(data);

    if (!json) return -4;

    FILE *out = fopen(output_file, "w");
    if (!out) { free(json); return -5; }
    fputs(json, out);
    fclose(out);
    free(json);

    return 0;
}

struct memory_response {
    char *data;
    size_t size;
};

static size_t write_memory_callback(void *contents, size_t size,
                                    size_t nmemb, void *userp) {
    size_t real_size = size * nmemb;
    struct memory_response *mem = (struct memory_response *)userp;
    char *ptr = realloc(mem->data, mem->size + real_size + 1);
    if (!ptr) return 0;
    mem->data = ptr;
    memcpy(&(mem->data[mem->size]), contents, real_size);
    mem->size += real_size;
    mem->data[mem->size] = 0;
    return real_size;
}

static int http_json_request(const char *url, const char *method,
                             const char *body, const char *session_id,
                             char **response_out) {
    *response_out = NULL;
    CURL *curl = curl_easy_init();
    if (!curl) return -1;

    struct memory_response response = { malloc(1), 0 };
    if (!response.data) { curl_easy_cleanup(curl); return -2; }
    response.data[0] = 0;

    struct curl_slist *headers = NULL;
    headers = curl_slist_append(headers, "Content-Type: application/json");
    char cookie_header[256];
    if (session_id && session_id[0]) {
        snprintf(cookie_header, sizeof(cookie_header), "Cookie: sid=%s", session_id);
        headers = curl_slist_append(headers, cookie_header);
    }

    curl_easy_setopt(curl, CURLOPT_URL, url);
    curl_easy_setopt(curl, CURLOPT_HTTPHEADER, headers);
    curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, write_memory_callback);
    curl_easy_setopt(curl, CURLOPT_WRITEDATA, &response);
    curl_easy_setopt(curl, CURLOPT_TIMEOUT, 10L);

    if (strcmp(method, "POST") == 0) {
        curl_easy_setopt(curl, CURLOPT_POSTFIELDS, body ? body : "{}");
    } else if (strcmp(method, "GET") != 0) {
        curl_easy_setopt(curl, CURLOPT_CUSTOMREQUEST, method);
        if (body) curl_easy_setopt(curl, CURLOPT_POSTFIELDS, body);
    }

    CURLcode res = curl_easy_perform(curl);
    long http_code = 0;
    curl_easy_getinfo(curl, CURLINFO_RESPONSE_CODE, &http_code);

    curl_slist_free_all(headers);
    curl_easy_cleanup(curl);

    if (res != CURLE_OK) { free(response.data); return -3; }
    if (http_code >= 400) { free(response.data); return (int)http_code; }

    *response_out = response.data;
    return 0;
}

int cobol_extract_session_cookie(const char *request, char *session_out) {
    write_cobol_field(session_out, 128, "");
    const char *cookie = find_case_insensitive(request, "\r\nCookie:");
    if (!cookie) cookie = find_case_insensitive(request, "\nCookie:");
    if (!cookie) return 0;

    cookie = strchr(cookie, ':');
    if (!cookie) return 0;
    cookie++;
    const char *line_end = strpbrk(cookie, "\r\n");
    if (!line_end) line_end = cookie + strlen(cookie);

    const char *sid = strstr(cookie, "sid=");
    if (!sid || sid >= line_end) return 0;
    sid += 4;
    const char *end = sid;
    while (end < line_end && *end && *end != ';' && !isspace((unsigned char)*end)) end++;

    char value[128];
    size_t len = (size_t)(end - sid);
    if (len >= sizeof(value)) len = sizeof(value) - 1;
    memcpy(value, sid, len);
    value[len] = 0;
    write_cobol_field(session_out, 128, value);
    return value[0] ? 1 : 0;
}

static void populate_auth_fields(cJSON *root, char *user_out,
                                 char *role_out, char *permissions_out) {
    write_cobol_field(user_out, 64, "");
    write_cobol_field(role_out, 64, "");
    write_cobol_field(permissions_out, 4096, "");

    cJSON *user = cJSON_GetObjectItem(root, "user");
    cJSON *display = user ? cJSON_GetObjectItem(user, "displayName") : NULL;
    cJSON *username = user ? cJSON_GetObjectItem(user, "username") : NULL;
    if (display && cJSON_IsString(display))
        write_cobol_field(user_out, 64, display->valuestring);
    else if (username && cJSON_IsString(username))
        write_cobol_field(user_out, 64, username->valuestring);

    cJSON *role = cJSON_GetObjectItem(root, "role");
    cJSON *role_name = role ? cJSON_GetObjectItem(role, "name") : NULL;
    if (role_name && cJSON_IsString(role_name))
        write_cobol_field(role_out, 64, role_name->valuestring);

    cJSON *permissions = cJSON_GetObjectItem(root, "permissions");
    char buffer[4096] = {0};
    size_t offset = 0;
    if (permissions && cJSON_IsArray(permissions)) {
        cJSON *permission;
        cJSON_ArrayForEach(permission, permissions) {
            if (!cJSON_IsString(permission)) continue;
            int written = snprintf(buffer + offset, sizeof(buffer) - offset,
                                   "%s%s", offset ? "," : "",
                                   permission->valuestring);
            if (written < 0 || (size_t)written >= sizeof(buffer) - offset) break;
            offset += (size_t)written;
        }
    }
    write_cobol_field(permissions_out, 4096, buffer);
}

int cobol_auth_login(const char *api_url_cobol, const char *form_body,
                     int body_len, char *session_out, char *user_out,
                     char *role_out, char *permissions_out) {
    char api_url[256];
    copy_cobol_string(api_url, sizeof(api_url), api_url_cobol, 256);

    char body[4096];
    int len = body_len;
    if (len < 0) len = 0;
    if (len > 4095) len = 4095;
    memcpy(body, form_body, (size_t)len);
    body[len] = 0;

    char username[256] = {0};
    char password[256] = {0};
    char *cursor = body;
    while (cursor && *cursor) {
        char *amp = strchr(cursor, '&');
        if (amp) *amp = 0;
        char *eq = strchr(cursor, '=');
        if (eq) {
            *eq = 0;
            char *key = cursor;
            char *val = eq + 1;
            for (char *p = val, *d = val; ; p++, d++) {
                if (*p == '+') *d = ' ';
                else if (*p == '%' && p[1] && p[2]) {
                    char hex[3] = { p[1], p[2], 0 };
                    *d = (char)strtol(hex, NULL, 16);
                    p += 2;
                } else *d = *p;
                if (*d == 0) break;
            }
            if (strcmp(key, "username") == 0) strncpy(username, val, sizeof(username) - 1);
            if (strcmp(key, "password") == 0) strncpy(password, val, sizeof(password) - 1);
        }
        cursor = amp ? amp + 1 : NULL;
    }

    cJSON *payload = cJSON_CreateObject();
    cJSON_AddStringToObject(payload, "username", username);
    cJSON_AddStringToObject(payload, "password", password);
    char *json = cJSON_PrintUnformatted(payload);
    cJSON_Delete(payload);
    if (!json) return -4;

    char url[512];
    snprintf(url, sizeof(url), "%s/auth/login", api_url);
    char *response = NULL;
    int result = http_json_request(url, "POST", json, NULL, &response);
    free(json);
    if (result != 0) return result;

    cJSON *root = cJSON_Parse(response);
    free(response);
    if (!root) return -5;
    cJSON *session = cJSON_GetObjectItem(root, "sessionId");
    if (!session || !cJSON_IsString(session)) {
        cJSON_Delete(root);
        return -6;
    }

    write_cobol_field(session_out, 128, session->valuestring);
    populate_auth_fields(root, user_out, role_out, permissions_out);
    cJSON_Delete(root);
    return 0;
}

int cobol_auth_me(const char *api_url_cobol, const char *session_cobol,
                  char *user_out, char *role_out, char *permissions_out) {
    char api_url[256];
    char session_id[128];
    copy_cobol_string(api_url, sizeof(api_url), api_url_cobol, 256);
    copy_cobol_string(session_id, sizeof(session_id), session_cobol, 128);
    if (!session_id[0]) return 401;

    char url[512];
    snprintf(url, sizeof(url), "%s/auth/me", api_url);
    char *response = NULL;
    int result = http_json_request(url, "GET", NULL, session_id, &response);
    if (result != 0) return result;

    cJSON *root = cJSON_Parse(response);
    free(response);
    if (!root) return -5;
    populate_auth_fields(root, user_out, role_out, permissions_out);
    cJSON_Delete(root);
    return 0;
}

int cobol_auth_can(const char *permissions_cobol, const char *resource_cobol,
                   const char *action_cobol) {
    char permissions[4096];
    char resource[64];
    char action[16];
    copy_cobol_string(permissions, sizeof(permissions), permissions_cobol, 4096);
    copy_cobol_string(resource, sizeof(resource), resource_cobol, 64);
    copy_cobol_string(action, sizeof(action), action_cobol, 16);

    if (permission_list_has(permissions, "admin.access")) return 1;
    if (permission_list_has(permissions, "rbac.manage") &&
        (strcmp(resource, "users") == 0 || strcmp(resource, "roles") == 0 ||
         strcmp(resource, "permissions") == 0)) return 1;

    char key[128];
    snprintf(key, sizeof(key), "%s.%s", resource, action);
    if (permission_list_has(permissions, key)) return 1;
    snprintf(key, sizeof(key), "%s.manage", resource);
    return permission_list_has(permissions, key) ? 1 : 0;
}

int cobol_auth_check(const char *permissions_cobol,
                     const char *resource_cobol,
                     const char *route_type_cobol,
                     const char *method_cobol) {
    char route_type[16];
    char method[16];
    char action[16] = "read";
    copy_cobol_string(route_type, sizeof(route_type), route_type_cobol, 10);
    copy_cobol_string(method, sizeof(method), method_cobol, 10);

    if (strcmp(route_type, "HOME") == 0 || strcmp(route_type, "STATIC") == 0 ||
        strcmp(route_type, "LOGIN") == 0 || strcmp(route_type, "LOGOUT") == 0) {
        return 1;
    }
    if (strcmp(route_type, "CREATE") == 0) strcpy(action, "create");
    else if (strcmp(route_type, "EDIT") == 0) strcpy(action, "update");
    else if (strcmp(route_type, "DELETE") == 0) strcpy(action, "delete");
    else strcpy(action, "read");

    (void)method;
    return cobol_auth_can(permissions_cobol, resource_cobol, action);
}

/*
 * Clean up all temp files used during request processing
 */
void cobol_cleanup_temp(void) {
    const char *files[] = {
        "/tmp/response.json",
        "/tmp/showdata.tsv",
        "/tmp/listresponse.json",
        "/tmp/listdata.tsv",
        "/tmp/headers.txt",
        "/tmp/formbody.txt",
        "/tmp/formjson.json",
        "/tmp/create_response.json",
        NULL
    };
    for (int i = 0; files[i]; i++) {
        remove(files[i]);
    }
}

/*
 * Extract X-Total-Count from HTTP header file
 */
int cobol_extract_total(const char *header_file, int *total) {
    *total = 0;
    FILE *f = fopen(header_file, "r");
    if (!f) return -1;

    char line[512];
    while (fgets(line, sizeof(line), f)) {
        if (strncasecmp(line, "x-total-count:", 14) == 0) {
            *total = atoi(line + 14);
            break;
        }
    }
    fclose(f);
    return 0;
}
