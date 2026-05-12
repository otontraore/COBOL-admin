      *> Builds the list page: fetches data from API, renders table
       IDENTIFICATION DIVISION.
       PROGRAM-ID. PAGE-LIST.

       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-URL               PIC X(512).
       01 WS-URL-Z             PIC X(512).
       01 WS-C-RESULT          PIC S9(9) COMP-5 VALUE 0.
       01 WS-C-TOTAL           PIC S9(9) COMP-5 VALUE 0.
       01 WS-FETCH-OK          PIC 9 VALUE 1.
       01 WS-FOPEN-MODE        PIC X(4) VALUE Z"r".
       01 WS-FILE-PTR          USAGE POINTER.
       01 WS-FGETS-PTR         USAGE POINTER.
       01 WS-DATA-LINE         PIC X(2048).
       01 WS-READ-DONE         PIC 9 VALUE 0.
       01 WS-FIELD-IDX         PIC 99 VALUE 0.
       01 WS-DATA-FILE         PIC X(256)
           VALUE Z"/tmp/listdata.tsv".
       01 WS-CELL-START        PIC 9(4) COMP-5 VALUE 0.
       01 WS-CELL-END          PIC 9(4) COMP-5 VALUE 0.
       01 WS-SCAN              PIC 9(4) COMP-5 VALUE 0.
       01 WS-LINE-LEN          PIC 9(4) COMP-5 VALUE 0.
       01 WS-PAGE-STR          PIC ZZ9.
       01 WS-PERPAGE-STR       PIC ZZ9.
       01 WS-PERPAGE-OPTION    PIC 999 VALUE 0.
       01 WS-PERPAGE-OPT-STR   PIC ZZ9.
       01 WS-TOTAL-STR         PIC ZZZZZ9.
       01 WS-ID-COL            PIC 99 VALUE 0.
       01 WS-COL-IDX           PIC 99 VALUE 0.
       01 WS-ROW-ID            PIC X(10).
       01 WS-FIELDS-CSV        PIC X(512).
       01 WS-FIELDS-PTR        PIC 9(4) COMP-5 VALUE 0.
       01 WS-RESP-FILE         PIC X(256)
           VALUE Z"/tmp/listresponse.json".
       01 WS-HEADER-FILE       PIC X(256)
           VALUE Z"/tmp/headers.txt".
       01 WS-TSV-FILE-Z        PIC X(256)
           VALUE Z"/tmp/listdata.tsv".
       01 WS-ARRAY-MODE        PIC X(8) VALUE Z"array".
    01 WS-CAN-CREATE        PIC S9(9) COMP-5 VALUE 0.
    01 WS-CREATE-ACTION     PIC X(16) VALUE "create".

      *> HTML escaping
       01 WS-ESC-INPUT         PIC X(2048).
       01 WS-ESC-INPUT-LEN     PIC 9(4) COMP-5 VALUE 0.
       01 WS-ESC-OUTPUT        PIC X(4096).
       01 WS-ESC-OUTPUT-LEN    PIC 9(4) COMP-5 VALUE 0.

      *> Reference detection per column
       01 WS-COL-REF-TABLE.
          05 WS-COL-REFS OCCURS 20 TIMES.
             10 WS-COL-REF-RES PIC X(64).
       01 WS-REF-RESULT        PIC X(64).
       01 WS-CELL-VALUE        PIC X(256).
    01 WS-SKIP-COL          PIC 9 VALUE 0.

       LINKAGE SECTION.
       01 LS-HTML-BODY         PIC X(32768).
       01 LS-HTML-LEN          PIC 9(8) COMP-5.
       01 LS-RESOURCE-NAME     PIC X(64).
       01 LS-API-URL           PIC X(256).
       01 LS-PAGE              PIC 999.
       01 LS-PER-PAGE          PIC 999.
       01 LS-TOTAL-COUNT       PIC 99999.
       01 LS-RESOURCE-TABLE.
          05 LS-RESOURCE-COUNT PIC 99.
          05 LS-RESOURCES OCCURS 20 TIMES.
             10 LS-RES-NAME    PIC X(64).
             10 LS-RES-FIELD-COUNT PIC 99.
             10 LS-RES-FIELDS OCCURS 20 TIMES.
                15 LS-RES-FIELD-NAME PIC X(64).
                15 LS-RES-FIELD-TYPE PIC X(16).
                15 LS-RES-FIELD-EDIT PIC 9.
       01 LS-RES-IDX           PIC 99.
       01 LS-AUTH-PERMISSIONS  PIC X(4096).

       PROCEDURE DIVISION USING
           LS-HTML-BODY LS-HTML-LEN
           LS-RESOURCE-NAME LS-API-URL
           LS-PAGE LS-PER-PAGE LS-TOTAL-COUNT
           LS-RESOURCE-TABLE LS-RES-IDX
           LS-AUTH-PERMISSIONS.

       MAIN-LOGIC.
           MOVE 1 TO WS-FETCH-OK
           PERFORM FETCH-DATA
           IF WS-FETCH-OK = 0
               STRING
                   "<h1>" DELIMITED BY SIZE
                   LS-RESOURCE-NAME DELIMITED BY SPACE
                   "</h1>" DELIMITED BY SIZE
                   "<p class='error'>Failed to load data"
                       DELIMITED BY SIZE
                   " from API.</p>" DELIMITED BY SIZE
                   INTO LS-HTML-BODY WITH POINTER LS-HTML-LEN
               END-STRING
           ELSE
               PERFORM BUILD-PAGE
           END-IF
           GOBACK.

      *> Fetch paginated data from API using C helpers
       FETCH-DATA.
           MOVE LS-PAGE TO WS-PAGE-STR
           MOVE LS-PER-PAGE TO WS-PERPAGE-STR

      *> Build URL with pagination params
           MOVE LOW-VALUE TO WS-URL-Z
           STRING
               FUNCTION TRIM(LS-API-URL) DELIMITED BY SIZE
               "/" DELIMITED BY SIZE
               LS-RESOURCE-NAME DELIMITED BY SPACE
               "?page=" DELIMITED BY SIZE
               FUNCTION TRIM(WS-PAGE-STR)
                   DELIMITED BY SIZE
               "&perPage=" DELIMITED BY SIZE
               FUNCTION TRIM(WS-PERPAGE-STR)
                   DELIMITED BY SIZE
               LOW-VALUE DELIMITED BY SIZE
               INTO WS-URL-Z
           END-STRING

      *> HTTP GET
           CALL "cobol_http_get" USING
               BY REFERENCE WS-URL-Z
               BY REFERENCE WS-RESP-FILE
               BY REFERENCE WS-HEADER-FILE
               RETURNING WS-C-RESULT
           END-CALL

           IF WS-C-RESULT NOT = 0
               MOVE 0 TO WS-FETCH-OK
               GOBACK
           END-IF

      *> Extract total count from headers
           CALL "cobol_extract_total" USING
               BY REFERENCE WS-HEADER-FILE
               BY REFERENCE WS-C-TOTAL
               RETURNING WS-C-RESULT
           END-CALL
           MOVE WS-C-TOTAL TO LS-TOTAL-COUNT

      *> Build CSV field list for JSON-to-TSV conversion
           MOVE LOW-VALUE TO WS-FIELDS-CSV
           MOVE 1 TO WS-FIELDS-PTR
           PERFORM VARYING WS-FIELD-IDX FROM 1 BY 1
               UNTIL WS-FIELD-IDX >
                   LS-RES-FIELD-COUNT(LS-RES-IDX)
               IF WS-FIELD-IDX > 1
                   STRING "," DELIMITED BY SIZE
                       INTO WS-FIELDS-CSV
                       WITH POINTER WS-FIELDS-PTR
                   END-STRING
               END-IF
               STRING
                   LS-RES-FIELD-NAME(LS-RES-IDX, WS-FIELD-IDX)
                       DELIMITED BY SPACE
                   INTO WS-FIELDS-CSV
                       WITH POINTER WS-FIELDS-PTR
               END-STRING
           END-PERFORM
      *> Null-terminate
           MOVE LOW-VALUE TO WS-FIELDS-CSV(WS-FIELDS-PTR:1)

      *> Convert JSON array to TSV
           CALL "cobol_json_to_tsv" USING
               BY REFERENCE WS-RESP-FILE
               BY REFERENCE WS-TSV-FILE-Z
               BY REFERENCE WS-ARRAY-MODE
               BY REFERENCE WS-FIELDS-CSV
               RETURNING WS-C-RESULT
           END-CALL
           .

      *> Build HTML: heading, perPage selector, table, pagination
       BUILD-PAGE.
           CALL "cobol_auth_can" USING
               BY REFERENCE LS-AUTH-PERMISSIONS
               BY REFERENCE LS-RESOURCE-NAME
               BY REFERENCE WS-CREATE-ACTION
               RETURNING WS-CAN-CREATE
           END-CALL

      *> Heading with Create button
           STRING
               "<div class='show-header'>"
                   DELIMITED BY SIZE
               "<h1>" DELIMITED BY SIZE
               LS-RESOURCE-NAME DELIMITED BY SPACE
               "</h1>" DELIMITED BY SIZE
               INTO LS-HTML-BODY WITH POINTER LS-HTML-LEN
           END-STRING

           IF WS-CAN-CREATE = 1
               STRING
                   "<a class='btn' href='/create/"
                       DELIMITED BY SIZE
                   LS-RESOURCE-NAME DELIMITED BY SPACE
                   "'>Create</a>" DELIMITED BY SIZE
                   INTO LS-HTML-BODY WITH POINTER LS-HTML-LEN
               END-STRING
           END-IF

           STRING "</div>" DELIMITED BY SIZE
               INTO LS-HTML-BODY WITH POINTER LS-HTML-LEN
           END-STRING

      *> Per-page selector
           STRING
               "<div class='list-toolbar'>"
                   DELIMITED BY SIZE
               "<span class='perpage-selector'>"
                   DELIMITED BY SIZE
               "Show " DELIMITED BY SIZE
               INTO LS-HTML-BODY WITH POINTER LS-HTML-LEN
           END-STRING
           MOVE 10 TO WS-PERPAGE-OPTION
           PERFORM BUILD-PERPAGE-LINK
           MOVE 25 TO WS-PERPAGE-OPTION
           PERFORM BUILD-PERPAGE-LINK
           MOVE 50 TO WS-PERPAGE-OPTION
           PERFORM BUILD-PERPAGE-LINK
           MOVE 100 TO WS-PERPAGE-OPTION
           PERFORM BUILD-PERPAGE-LINK
           STRING
               "</span>"
                   DELIMITED BY SIZE
               "<span class='total'>"
                   DELIMITED BY SIZE
               INTO LS-HTML-BODY WITH POINTER LS-HTML-LEN
           END-STRING
           MOVE LS-TOTAL-COUNT TO WS-TOTAL-STR
           STRING
               FUNCTION TRIM(WS-TOTAL-STR)
                   DELIMITED BY SIZE
               " total</span></div>" DELIMITED BY SIZE
               INTO LS-HTML-BODY WITH POINTER LS-HTML-LEN
           END-STRING

      *> Find id column and build reference map per column
           MOVE 0 TO WS-ID-COL
           INITIALIZE WS-COL-REF-TABLE
           PERFORM VARYING WS-FIELD-IDX FROM 1 BY 1
               UNTIL WS-FIELD-IDX >
                   LS-RES-FIELD-COUNT(LS-RES-IDX)
               IF LS-RES-FIELD-NAME(LS-RES-IDX, WS-FIELD-IDX)
                   = "id"
                   MOVE WS-FIELD-IDX TO WS-ID-COL
               END-IF
      *> Check if field is a reference
               CALL "REF-DETECT" USING
                   LS-RES-FIELD-NAME(LS-RES-IDX, WS-FIELD-IDX)
                   LS-RESOURCE-TABLE
                   WS-REF-RESULT
               END-CALL
               IF WS-REF-RESULT NOT = SPACES
                   MOVE WS-REF-RESULT
                       TO WS-COL-REF-RES(WS-FIELD-IDX)
               END-IF
           END-PERFORM

      *> Table header
           STRING
               "<table>"
                   DELIMITED BY SIZE
               "<thead><tr>" DELIMITED BY SIZE
               INTO LS-HTML-BODY WITH POINTER LS-HTML-LEN
           END-STRING

           PERFORM VARYING WS-FIELD-IDX FROM 1 BY 1
               UNTIL WS-FIELD-IDX > LS-RES-FIELD-COUNT(LS-RES-IDX)
               MOVE 0 TO WS-SKIP-COL
               IF LS-RESOURCE-NAME = "users"
                   AND LS-RES-FIELD-NAME(
                       LS-RES-IDX, WS-FIELD-IDX) = "roleId"
                   MOVE 1 TO WS-SKIP-COL
               END-IF
               IF WS-SKIP-COL = 0
                   STRING
                       "<th>" DELIMITED BY SIZE
                       LS-RES-FIELD-NAME(LS-RES-IDX, WS-FIELD-IDX)
                           DELIMITED BY SPACE
                       "</th>" DELIMITED BY SIZE
                       INTO LS-HTML-BODY WITH POINTER LS-HTML-LEN
                   END-STRING
               END-IF
           END-PERFORM

           STRING
               "</tr></thead><tbody>" DELIMITED BY SIZE
               INTO LS-HTML-BODY WITH POINTER LS-HTML-LEN
           END-STRING

      *> Table rows from TSV file
           CALL "fopen" USING WS-DATA-FILE WS-FOPEN-MODE
               RETURNING WS-FILE-PTR
           END-CALL
           IF WS-FILE-PTR NOT = NULL
               MOVE 0 TO WS-READ-DONE
               PERFORM READ-DATA-ROW
                   UNTIL WS-READ-DONE = 1
               CALL "fclose" USING BY VALUE WS-FILE-PTR
               END-CALL
           END-IF

           STRING
               "</tbody></table>" DELIMITED BY SIZE
               INTO LS-HTML-BODY WITH POINTER LS-HTML-LEN
           END-STRING

      *> Pagination links
           PERFORM BUILD-PAGINATION
           .

       READ-DATA-ROW.
           MOVE LOW-VALUE TO WS-DATA-LINE
           CALL "fgets" USING
               BY REFERENCE WS-DATA-LINE
               BY VALUE 2048
               BY VALUE WS-FILE-PTR
               RETURNING WS-FGETS-PTR
           END-CALL

           IF WS-FGETS-PTR = NULL
               MOVE 1 TO WS-READ-DONE
           ELSE
               INSPECT WS-DATA-LINE
                   REPLACING ALL X"0A" BY SPACE
               INSPECT WS-DATA-LINE
                   REPLACING ALL X"0D" BY SPACE

      *> First pass: find id value for the row link
               MOVE 1 TO WS-COL-IDX
               MOVE SPACES TO WS-ROW-ID
               MOVE 0 TO WS-LINE-LEN
               INSPECT WS-DATA-LINE TALLYING WS-LINE-LEN
                   FOR CHARACTERS BEFORE INITIAL LOW-VALUE
               IF WS-LINE-LEN = 0
                   MOVE FUNCTION LENGTH(
                       FUNCTION TRIM(WS-DATA-LINE TRAILING))
                       TO WS-LINE-LEN
               END-IF
               MOVE 1 TO WS-CELL-START
               PERFORM VARYING WS-SCAN FROM 1 BY 1
                   UNTIL WS-SCAN > WS-LINE-LEN
                   IF WS-DATA-LINE(WS-SCAN:1) = X"09"
                       IF WS-COL-IDX = WS-ID-COL
                           COMPUTE WS-CELL-END =
                               WS-SCAN - WS-CELL-START
                           MOVE WS-DATA-LINE(
                               WS-CELL-START:WS-CELL-END)
                               TO WS-ROW-ID
                       END-IF
                       COMPUTE WS-CELL-START = WS-SCAN + 1
                       ADD 1 TO WS-COL-IDX
                   END-IF
               END-PERFORM
               IF WS-COL-IDX = WS-ID-COL
                   COMPUTE WS-CELL-END =
                       WS-LINE-LEN - WS-CELL-START + 1
                   MOVE WS-DATA-LINE(
                       WS-CELL-START:WS-CELL-END)
                       TO WS-ROW-ID
               END-IF

      *> Write <tr>
               STRING "<tr>" DELIMITED BY SIZE
                   INTO LS-HTML-BODY
                       WITH POINTER LS-HTML-LEN
               END-STRING

               MOVE 0 TO WS-LINE-LEN
               INSPECT WS-DATA-LINE TALLYING WS-LINE-LEN
                   FOR CHARACTERS BEFORE INITIAL LOW-VALUE
               IF WS-LINE-LEN = 0
                   MOVE FUNCTION LENGTH(
                       FUNCTION TRIM(WS-DATA-LINE TRAILING))
                       TO WS-LINE-LEN
               END-IF

      *> Second pass: write cells with links
               MOVE 1 TO WS-COL-IDX
               MOVE 1 TO WS-CELL-START
               PERFORM VARYING WS-SCAN FROM 1 BY 1
                   UNTIL WS-SCAN > WS-LINE-LEN
                   IF WS-DATA-LINE(WS-SCAN:1) = X"09"
                       COMPUTE WS-CELL-END =
                           WS-SCAN - WS-CELL-START
                       PERFORM WRITE-CELL
                       COMPUTE WS-CELL-START = WS-SCAN + 1
                       ADD 1 TO WS-COL-IDX
                   END-IF
               END-PERFORM
      *> Last cell
               COMPUTE WS-CELL-END =
                   WS-LINE-LEN - WS-CELL-START + 1
               IF WS-CELL-END > 0
                   PERFORM WRITE-CELL
               END-IF

               STRING "</tr>" DELIMITED BY SIZE
                   INTO LS-HTML-BODY WITH POINTER LS-HTML-LEN
               END-STRING
           END-IF
           .

       WRITE-CELL.
           IF LS-RESOURCE-NAME = "users"
               AND LS-RES-FIELD-NAME(LS-RES-IDX, WS-COL-IDX)
                   = "roleId"
               EXIT PARAGRAPH
           END-IF

           STRING "<td>" DELIMITED BY SIZE
               INTO LS-HTML-BODY WITH POINTER LS-HTML-LEN
           END-STRING

      *> Extract cell value for link target
           MOVE SPACES TO WS-CELL-VALUE
           IF WS-CELL-END > 0
               MOVE WS-DATA-LINE(WS-CELL-START:WS-CELL-END)
                   TO WS-CELL-VALUE
           END-IF

      *> Determine link: reference field → ref resource,
      *>                  otherwise → current resource show
           IF WS-COL-REF-RES(WS-COL-IDX) NOT = SPACES
               STRING
                   "<a class='ref-link' href='/show/"
                       DELIMITED BY SIZE
                   WS-COL-REF-RES(WS-COL-IDX)
                       DELIMITED BY SPACE
                   "/" DELIMITED BY SIZE
                   WS-CELL-VALUE DELIMITED BY SPACE
                   "'>" DELIMITED BY SIZE
                   INTO LS-HTML-BODY WITH POINTER LS-HTML-LEN
               END-STRING
           ELSE
               IF WS-ID-COL > 0
                   STRING
                       "<a href='/show/" DELIMITED BY SIZE
                       LS-RESOURCE-NAME DELIMITED BY SPACE
                       "/" DELIMITED BY SIZE
                       WS-ROW-ID DELIMITED BY SPACE
                       "'>" DELIMITED BY SIZE
                       INTO LS-HTML-BODY
                           WITH POINTER LS-HTML-LEN
                   END-STRING
               END-IF
           END-IF

           IF WS-CELL-END > 0
               MOVE WS-DATA-LINE(WS-CELL-START:WS-CELL-END)
                   TO WS-ESC-INPUT
               MOVE WS-CELL-END TO WS-ESC-INPUT-LEN
               CALL "HTML-ESCAPE" USING
                   WS-ESC-INPUT WS-ESC-INPUT-LEN
                   WS-ESC-OUTPUT WS-ESC-OUTPUT-LEN
               END-CALL
               IF WS-ESC-OUTPUT-LEN > 0
                   STRING
                       WS-ESC-OUTPUT(1:WS-ESC-OUTPUT-LEN)
                           DELIMITED BY SIZE
                       INTO LS-HTML-BODY
                           WITH POINTER LS-HTML-LEN
                   END-STRING
               END-IF
           END-IF

      *> Close link
           IF WS-COL-REF-RES(WS-COL-IDX) NOT = SPACES
               STRING "</a>" DELIMITED BY SIZE
                   INTO LS-HTML-BODY WITH POINTER LS-HTML-LEN
               END-STRING
           ELSE
               IF WS-ID-COL > 0
                   STRING "</a>" DELIMITED BY SIZE
                       INTO LS-HTML-BODY
                           WITH POINTER LS-HTML-LEN
                   END-STRING
               END-IF
           END-IF

           STRING "</td>" DELIMITED BY SIZE
               INTO LS-HTML-BODY WITH POINTER LS-HTML-LEN
           END-STRING
           .

       BUILD-PAGINATION.
           CALL "PAGINATION" USING
               LS-HTML-BODY LS-HTML-LEN
               LS-RESOURCE-NAME
               LS-PAGE LS-PER-PAGE LS-TOTAL-COUNT
           END-CALL
           .

       BUILD-PERPAGE-LINK.
           MOVE WS-PERPAGE-OPTION TO WS-PERPAGE-OPT-STR
           IF LS-PER-PAGE = WS-PERPAGE-OPTION
               STRING
                   "<strong class='active'>"
                       DELIMITED BY SIZE
                   FUNCTION TRIM(WS-PERPAGE-OPT-STR)
                       DELIMITED BY SIZE
                   "</strong>" DELIMITED BY SIZE
                   INTO LS-HTML-BODY WITH POINTER LS-HTML-LEN
               END-STRING
           ELSE
               STRING
                   "<a href='/list/" DELIMITED BY SIZE
                   LS-RESOURCE-NAME DELIMITED BY SPACE
                   "?perPage=" DELIMITED BY SIZE
                   FUNCTION TRIM(WS-PERPAGE-OPT-STR)
                       DELIMITED BY SIZE
                   "'>" DELIMITED BY SIZE
                   FUNCTION TRIM(WS-PERPAGE-OPT-STR)
                       DELIMITED BY SIZE
                   "</a>" DELIMITED BY SIZE
                   INTO LS-HTML-BODY WITH POINTER LS-HTML-LEN
               END-STRING
           END-IF
           .
