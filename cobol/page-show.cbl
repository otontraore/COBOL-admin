      *> Builds the show page: fetches one item, displays fields
       IDENTIFICATION DIVISION.
       PROGRAM-ID. PAGE-SHOW.

       DATA DIVISION.
       WORKING-STORAGE SECTION.
      *> (WS-CMD removed — fetch-item is now a shared module)
       01 WS-FOPEN-MODE        PIC X(4) VALUE Z"r".
       01 WS-FILE-PTR          USAGE POINTER.
       01 WS-FGETS-PTR         USAGE POINTER.
       01 WS-LINE              PIC X(2048).
       01 WS-READ-DONE         PIC 9 VALUE 0.
       01 WS-FIELD-IDX         PIC 99 VALUE 0.
       01 WS-DATA-FILE         PIC X(256)
           VALUE Z"/tmp/showdata.tsv".
       01 WS-REF-RESULT        PIC X(64).
       01 WS-FIELD-KEY         PIC X(64).
       01 WS-TAB-POS           PIC 9(4) COMP-5 VALUE 0.
       01 WS-VAL-START         PIC 9(4) COMP-5 VALUE 0.
       01 WS-SANITIZE-BUF      PIC X(512).
       01 WS-SANITIZE-LEN      PIC 9(4) COMP-5 VALUE 0.
       01 WS-SANITIZE-OK       PIC 9 VALUE 0.
       01 WS-FETCH-STATUS      PIC 9 VALUE 0.
       01 WS-VAL-LEN           PIC 9(4) COMP-5 VALUE 0.
       01 WS-LINE-LEN          PIC 9(4) COMP-5 VALUE 0.
    01 WS-CAN-UPDATE        PIC S9(9) COMP-5 VALUE 0.
    01 WS-UPDATE-ACTION     PIC X(16) VALUE "update".

      *> HTML escaping
       01 WS-ESC-INPUT         PIC X(2048).
       01 WS-ESC-INPUT-LEN     PIC 9(4) COMP-5 VALUE 0.
       01 WS-ESC-OUTPUT        PIC X(4096).
       01 WS-ESC-OUTPUT-LEN    PIC 9(4) COMP-5 VALUE 0.

       LINKAGE SECTION.
       01 LS-HTML-BODY         PIC X(32768).
       01 LS-HTML-LEN          PIC 9(8) COMP-5.
       01 LS-RESOURCE-NAME     PIC X(64).
       01 LS-RESOURCE-ID       PIC X(10).
       01 LS-API-URL           PIC X(256).
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
           LS-RESOURCE-NAME LS-RESOURCE-ID LS-API-URL
           LS-RESOURCE-TABLE LS-RES-IDX
           LS-AUTH-PERMISSIONS.

       MAIN-LOGIC.
      *> Validate resource ID before using in shell
           MOVE LS-RESOURCE-ID TO WS-SANITIZE-BUF
           MOVE FUNCTION LENGTH(
               FUNCTION TRIM(LS-RESOURCE-ID))
               TO WS-SANITIZE-LEN
           CALL "SHELL-SANITIZE" USING
               WS-SANITIZE-BUF WS-SANITIZE-LEN WS-SANITIZE-OK
           END-CALL
           IF WS-SANITIZE-OK = 0
               STRING "<h1>Invalid ID</h1>" DELIMITED BY SIZE
                   INTO LS-HTML-BODY WITH POINTER LS-HTML-LEN
               END-STRING
               GOBACK
           END-IF

           CALL "FETCH-ITEM" USING
               LS-API-URL LS-RESOURCE-NAME LS-RESOURCE-ID
               WS-FETCH-STATUS
           END-CALL
           IF WS-FETCH-STATUS = 0
               STRING
                   "<h1>Error</h1>"
                       DELIMITED BY SIZE
                   "<p class='error'>Failed to load "
                       DELIMITED BY SIZE
                   LS-RESOURCE-NAME DELIMITED BY SPACE
                   " #" DELIMITED BY SIZE
                   LS-RESOURCE-ID DELIMITED BY SPACE
                   "</p>" DELIMITED BY SIZE
                   INTO LS-HTML-BODY WITH POINTER LS-HTML-LEN
               END-STRING
           ELSE
               PERFORM BUILD-PAGE
           END-IF
           GOBACK.

      *> Build HTML: heading, back link, field table
       BUILD-PAGE.
           CALL "cobol_auth_can" USING
               BY REFERENCE LS-AUTH-PERMISSIONS
               BY REFERENCE LS-RESOURCE-NAME
               BY REFERENCE WS-UPDATE-ACTION
               RETURNING WS-CAN-UPDATE
           END-CALL

      *> Heading + back link
           STRING
               "<div class='show-header'>"
                   DELIMITED BY SIZE
               "<div><h1>" DELIMITED BY SIZE
               LS-RESOURCE-NAME DELIMITED BY SPACE
               " #" DELIMITED BY SIZE
               LS-RESOURCE-ID DELIMITED BY SPACE
               "</h1>" DELIMITED BY SIZE
               "<a href='/list/" DELIMITED BY SIZE
               LS-RESOURCE-NAME DELIMITED BY SPACE
               "'>Back to list</a></div>" DELIMITED BY SIZE
               INTO LS-HTML-BODY WITH POINTER LS-HTML-LEN
           END-STRING

           IF WS-CAN-UPDATE = 1
               STRING
                   "<a class='btn' href='/edit/"
                       DELIMITED BY SIZE
                   LS-RESOURCE-NAME DELIMITED BY SPACE
                   "/" DELIMITED BY SIZE
                   LS-RESOURCE-ID DELIMITED BY SPACE
                   "'>Edit</a>" DELIMITED BY SIZE
                   INTO LS-HTML-BODY WITH POINTER LS-HTML-LEN
               END-STRING
           END-IF

           STRING "</div>" DELIMITED BY SIZE
               INTO LS-HTML-BODY WITH POINTER LS-HTML-LEN
           END-STRING

      *> Field table (key-value pairs)
           STRING
               "<table class='show-table'>"
                   DELIMITED BY SIZE
               "<thead><tr><th>Field</th>"
                   DELIMITED BY SIZE
               "<th>Value</th></tr></thead>"
                   DELIMITED BY SIZE
               "<tbody>" DELIMITED BY SIZE
               INTO LS-HTML-BODY WITH POINTER LS-HTML-LEN
           END-STRING

      *> Read TSV rows (field<tab>value per line)
           CALL "fopen" USING WS-DATA-FILE WS-FOPEN-MODE
               RETURNING WS-FILE-PTR
           END-CALL
           IF WS-FILE-PTR NOT = NULL
               MOVE 0 TO WS-READ-DONE
               PERFORM READ-FIELD-ROW
                   UNTIL WS-READ-DONE = 1
               CALL "fclose" USING BY VALUE WS-FILE-PTR
               END-CALL
           END-IF

           STRING
               "</tbody></table>" DELIMITED BY SIZE
               INTO LS-HTML-BODY WITH POINTER LS-HTML-LEN
           END-STRING
           .

       READ-FIELD-ROW.
           MOVE LOW-VALUE TO WS-LINE
           CALL "fgets" USING
               BY REFERENCE WS-LINE
               BY VALUE 2048
               BY VALUE WS-FILE-PTR
               RETURNING WS-FGETS-PTR
           END-CALL

           IF WS-FGETS-PTR = NULL
               MOVE 1 TO WS-READ-DONE
           ELSE
               INSPECT WS-LINE
                   REPLACING ALL X"0A" BY SPACE
               INSPECT WS-LINE
                   REPLACING ALL X"0D" BY SPACE

      *> Find tab separator
               MOVE 0 TO WS-FIELD-IDX
               INSPECT WS-LINE TALLYING WS-FIELD-IDX
                   FOR CHARACTERS BEFORE INITIAL X"09"

               IF WS-FIELD-IDX > 0
      *> Extract key
                   MOVE SPACES TO WS-FIELD-KEY
                   MOVE WS-LINE(1:WS-FIELD-IDX)
                       TO WS-FIELD-KEY

      *> Compute value position and length
                   COMPUTE WS-VAL-START = WS-FIELD-IDX + 2
                   MOVE 0 TO WS-LINE-LEN
                   INSPECT WS-LINE TALLYING WS-LINE-LEN
                       FOR CHARACTERS
                       BEFORE INITIAL LOW-VALUE
                   IF WS-LINE-LEN = 0
                       MOVE FUNCTION LENGTH(
                           FUNCTION TRIM(WS-LINE TRAILING))
                           TO WS-LINE-LEN
                   END-IF
                   COMPUTE WS-VAL-LEN =
                       WS-LINE-LEN - WS-VAL-START + 1
                   IF WS-VAL-LEN < 0
                       MOVE 0 TO WS-VAL-LEN
                   END-IF

      *> Write key cell
                   STRING
                       "<tr><td>" DELIMITED BY SIZE
                       WS-FIELD-KEY DELIMITED BY SPACE
                       "</td><td>" DELIMITED BY SIZE
                       INTO LS-HTML-BODY
                           WITH POINTER LS-HTML-LEN
                   END-STRING

      *> Check if field is a reference
                   CALL "REF-DETECT" USING
                       WS-FIELD-KEY
                       LS-RESOURCE-TABLE
                       WS-REF-RESULT
                   END-CALL

      *> Escape value for display
                   IF WS-VAL-LEN > 0
                       MOVE WS-LINE(WS-VAL-START:WS-VAL-LEN)
                           TO WS-ESC-INPUT
                       MOVE WS-VAL-LEN TO WS-ESC-INPUT-LEN
                       CALL "HTML-ESCAPE" USING
                           WS-ESC-INPUT WS-ESC-INPUT-LEN
                           WS-ESC-OUTPUT WS-ESC-OUTPUT-LEN
                       END-CALL
                   ELSE
                       MOVE 0 TO WS-ESC-OUTPUT-LEN
                   END-IF

      *> Write value with optional link
                   IF WS-REF-RESULT NOT = SPACES
                       AND WS-VAL-LEN > 0
                       STRING
                           "<a href='/show/"
                               DELIMITED BY SIZE
                           WS-REF-RESULT
                               DELIMITED BY SPACE
                           "/" DELIMITED BY SIZE
                           WS-LINE(WS-VAL-START:WS-VAL-LEN)
                               DELIMITED BY SPACE
                           "'>" DELIMITED BY SIZE
                           INTO LS-HTML-BODY
                               WITH POINTER LS-HTML-LEN
                       END-STRING
                       IF WS-ESC-OUTPUT-LEN > 0
                           STRING
                               WS-ESC-OUTPUT(
                                   1:WS-ESC-OUTPUT-LEN)
                                   DELIMITED BY SIZE
                               INTO LS-HTML-BODY
                                   WITH POINTER LS-HTML-LEN
                           END-STRING
                       END-IF
                       STRING "</a>" DELIMITED BY SIZE
                           INTO LS-HTML-BODY
                               WITH POINTER LS-HTML-LEN
                       END-STRING
                   ELSE
                       IF WS-ESC-OUTPUT-LEN > 0
                           STRING
                               WS-ESC-OUTPUT(
                                   1:WS-ESC-OUTPUT-LEN)
                                   DELIMITED BY SIZE
                               INTO LS-HTML-BODY
                                   WITH POINTER LS-HTML-LEN
                           END-STRING
                       END-IF
                   END-IF

                   STRING "</td></tr>" DELIMITED BY SIZE
                       INTO LS-HTML-BODY
                           WITH POINTER LS-HTML-LEN
                   END-STRING
               END-IF
           END-IF
           .
