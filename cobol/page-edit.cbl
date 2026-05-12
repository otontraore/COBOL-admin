      *> Builds edit form or handles form submission
       IDENTIFICATION DIVISION.
       PROGRAM-ID. PAGE-EDIT.

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
       01 WS-FIELD-KEY         PIC X(64).
       01 WS-TAB-POS           PIC 9(4) COMP-5 VALUE 0.
       01 WS-VAL-START         PIC 9(4) COMP-5 VALUE 0.
       01 WS-SANITIZE-BUF      PIC X(512).
       01 WS-SANITIZE-LEN      PIC 9(4) COMP-5 VALUE 0.
       01 WS-SANITIZE-OK       PIC 9 VALUE 0.
       01 WS-FETCH-STATUS      PIC 9 VALUE 0.
       01 WS-VAL-LEN           PIC 9(4) COMP-5 VALUE 0.
       01 WS-LINE-LEN          PIC 9(4) COMP-5 VALUE 0.

      *> HTML escaping
       01 WS-ESC-INPUT         PIC X(2048).
       01 WS-ESC-INPUT-LEN     PIC 9(4) COMP-5 VALUE 0.
       01 WS-ESC-OUTPUT        PIC X(4096).
       01 WS-ESC-OUTPUT-LEN    PIC 9(4) COMP-5 VALUE 0.
       01 WS-FNAME-LEN         PIC 99 VALUE 0.
       01 WS-MATCH-IDX         PIC 99 VALUE 0.
       01 WS-FIELD-TYPE        PIC X(16).
       01 WS-FIELD-EDIT        PIC 9 VALUE 0.
       01 WS-INPUT-TYPE        PIC X(20).
    01 WS-CAN-DELETE        PIC S9(9) COMP-5 VALUE 0.
    01 WS-DELETE-ACTION     PIC X(16) VALUE "delete".

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
               GOBACK
           END-IF
           PERFORM BUILD-FORM
           GOBACK.

      *> Build HTML form
       BUILD-FORM.
           CALL "cobol_auth_can" USING
               BY REFERENCE LS-AUTH-PERMISSIONS
               BY REFERENCE LS-RESOURCE-NAME
               BY REFERENCE WS-DELETE-ACTION
               RETURNING WS-CAN-DELETE
           END-CALL

      *> Header with cancel link
           STRING
               "<div class='show-header'>"
                   DELIMITED BY SIZE
               "<div><h1>Edit " DELIMITED BY SIZE
               LS-RESOURCE-NAME DELIMITED BY SPACE
               " #" DELIMITED BY SIZE
               LS-RESOURCE-ID DELIMITED BY SPACE
               "</h1>" DELIMITED BY SIZE
               "<a href='/show/" DELIMITED BY SIZE
               LS-RESOURCE-NAME DELIMITED BY SPACE
               "/" DELIMITED BY SIZE
               LS-RESOURCE-ID DELIMITED BY SPACE
               "'>Cancel</a></div></div>" DELIMITED BY SIZE
               INTO LS-HTML-BODY WITH POINTER LS-HTML-LEN
           END-STRING

      *> Form posts to /edit/{resource}/{id}
           STRING
               "<form method='POST' action='/edit/"
                   DELIMITED BY SIZE
               LS-RESOURCE-NAME DELIMITED BY SPACE
               "/" DELIMITED BY SIZE
               LS-RESOURCE-ID DELIMITED BY SPACE
               "' class='edit-form'>" DELIMITED BY SIZE
               INTO LS-HTML-BODY WITH POINTER LS-HTML-LEN
           END-STRING

      *> Read fields and render inputs
           CALL "fopen" USING WS-DATA-FILE WS-FOPEN-MODE
               RETURNING WS-FILE-PTR
           END-CALL
           IF WS-FILE-PTR NOT = NULL
               MOVE 0 TO WS-READ-DONE
               PERFORM READ-FORM-FIELD
                   UNTIL WS-READ-DONE = 1
               CALL "fclose" USING BY VALUE WS-FILE-PTR
               END-CALL
           END-IF

      *> Submit button
           STRING
               "<div class='form-actions'>"
                   DELIMITED BY SIZE
               "<button type='submit' class='btn'>"
                   DELIMITED BY SIZE
               "Save</button>"
                   DELIMITED BY SIZE
               "<a href='/show/" DELIMITED BY SIZE
               LS-RESOURCE-NAME DELIMITED BY SPACE
               "/" DELIMITED BY SIZE
               LS-RESOURCE-ID DELIMITED BY SPACE
               "'>Cancel</a>" DELIMITED BY SIZE
               INTO LS-HTML-BODY WITH POINTER LS-HTML-LEN
           END-STRING

           IF WS-CAN-DELETE = 1
               STRING
                   "<a class='btn btn-danger' href='/delete/"
                       DELIMITED BY SIZE
                   LS-RESOURCE-NAME DELIMITED BY SPACE
                   "/" DELIMITED BY SIZE
                   LS-RESOURCE-ID DELIMITED BY SPACE
                   "'>Delete</a>" DELIMITED BY SIZE
                   INTO LS-HTML-BODY WITH POINTER LS-HTML-LEN
               END-STRING
           END-IF

           STRING "</div></form>" DELIMITED BY SIZE
               INTO LS-HTML-BODY WITH POINTER LS-HTML-LEN
           END-STRING
           .

       READ-FORM-FIELD.
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

      *> Extract key and value
               MOVE 0 TO WS-TAB-POS
               INSPECT WS-LINE TALLYING WS-TAB-POS
                   FOR CHARACTERS BEFORE INITIAL X"09"

               IF WS-TAB-POS > 0
                   MOVE SPACES TO WS-FIELD-KEY
                   MOVE WS-LINE(1:WS-TAB-POS) TO WS-FIELD-KEY
                   COMPUTE WS-VAL-START = WS-TAB-POS + 2
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

      *> Look up field type and editability
                   MOVE "string" TO WS-FIELD-TYPE
                   MOVE 1 TO WS-FIELD-EDIT
                   PERFORM VARYING WS-MATCH-IDX FROM 1 BY 1
                       UNTIL WS-MATCH-IDX >
                           LS-RES-FIELD-COUNT(LS-RES-IDX)
                       IF LS-RES-FIELD-NAME(
                           LS-RES-IDX, WS-MATCH-IDX)
                           = WS-FIELD-KEY
                           MOVE LS-RES-FIELD-TYPE(
                               LS-RES-IDX, WS-MATCH-IDX)
                               TO WS-FIELD-TYPE
                           MOVE LS-RES-FIELD-EDIT(
                               LS-RES-IDX, WS-MATCH-IDX)
                               TO WS-FIELD-EDIT
                           EXIT PERFORM
                       END-IF
                   END-PERFORM

                   PERFORM RENDER-INPUT
               END-IF
           END-IF
           .

       RENDER-INPUT.
      *> Map schema type to HTML input type
      *> Detect date-time values (ISO format 20xx-...)
           MOVE "text" TO WS-INPUT-TYPE
           IF WS-VAL-LEN >= 10
               IF WS-LINE(WS-VAL-START:2) = "20"
                   AND WS-LINE(WS-VAL-START + 4:1) = "-"
                   AND WS-LINE(WS-VAL-START + 7:1) = "-"
                   MOVE "datetime-local" TO WS-INPUT-TYPE
               END-IF
           END-IF

      *> Label
           STRING
               "<div class='form-field'>"
                   DELIMITED BY SIZE
               "<label for='" DELIMITED BY SIZE
               WS-FIELD-KEY DELIMITED BY SPACE
               "'>" DELIMITED BY SIZE
               WS-FIELD-KEY DELIMITED BY SPACE
               "</label>" DELIMITED BY SIZE
               INTO LS-HTML-BODY WITH POINTER LS-HTML-LEN
           END-STRING

      *> Input (disabled if not editable)
           STRING
               '<input type="' DELIMITED BY SIZE
               WS-INPUT-TYPE DELIMITED BY SPACE
               '" name="' DELIMITED BY SIZE
               WS-FIELD-KEY DELIMITED BY SPACE
               INTO LS-HTML-BODY WITH POINTER LS-HTML-LEN
           END-STRING

           IF FUNCTION TRIM(WS-FIELD-TYPE) = "array"
               STRING "[]" DELIMITED BY SIZE
                   INTO LS-HTML-BODY WITH POINTER LS-HTML-LEN
               END-STRING
           END-IF

           STRING
               '" id="' DELIMITED BY SIZE
               WS-FIELD-KEY DELIMITED BY SPACE
               '" value="' DELIMITED BY SIZE
               INTO LS-HTML-BODY WITH POINTER LS-HTML-LEN
           END-STRING
           IF WS-VAL-LEN > 0
      *> Truncate datetime-local to YYYY-MM-DDTHH:MM
               IF WS-INPUT-TYPE = "datetime-local"
                   AND WS-VAL-LEN > 16
                   MOVE WS-LINE(WS-VAL-START:16)
                       TO WS-ESC-INPUT
                   MOVE 16 TO WS-ESC-INPUT-LEN
               ELSE
                   MOVE WS-LINE(WS-VAL-START:WS-VAL-LEN)
                       TO WS-ESC-INPUT
                   MOVE WS-VAL-LEN TO WS-ESC-INPUT-LEN
               END-IF
               CALL "HTML-ESCAPE" USING
                   WS-ESC-INPUT WS-ESC-INPUT-LEN
                   WS-ESC-OUTPUT WS-ESC-OUTPUT-LEN
               END-CALL
               STRING
                   WS-ESC-OUTPUT(1:WS-ESC-OUTPUT-LEN)
                       DELIMITED BY SIZE
                   INTO LS-HTML-BODY WITH POINTER LS-HTML-LEN
               END-STRING
           END-IF
           STRING '"' DELIMITED BY SIZE
               INTO LS-HTML-BODY WITH POINTER LS-HTML-LEN
           END-STRING

           IF WS-FIELD-EDIT = 0
               STRING " disabled" DELIMITED BY SIZE
                   INTO LS-HTML-BODY WITH POINTER LS-HTML-LEN
               END-STRING
           END-IF

           IF FUNCTION TRIM(WS-FIELD-TYPE) = "array"
               STRING
                   ' placeholder="value1, value2"' DELIMITED BY SIZE
                   INTO LS-HTML-BODY WITH POINTER LS-HTML-LEN
               END-STRING
           END-IF

           STRING "></div>" DELIMITED BY SIZE
               INTO LS-HTML-BODY WITH POINTER LS-HTML-LEN
           END-STRING
           .
