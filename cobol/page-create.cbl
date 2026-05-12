      *> Builds create form for a resource
       IDENTIFICATION DIVISION.
       PROGRAM-ID. PAGE-CREATE.

       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-FIELD-IDX         PIC 99 VALUE 0.
       01 WS-FIELD-TYPE        PIC X(16).
       01 WS-INPUT-TYPE        PIC X(20).

       LINKAGE SECTION.
       01 LS-HTML-BODY         PIC X(32768).
       01 LS-HTML-LEN          PIC 9(8) COMP-5.
       01 LS-RESOURCE-NAME     PIC X(64).
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

       PROCEDURE DIVISION USING
           LS-HTML-BODY LS-HTML-LEN
           LS-RESOURCE-NAME
           LS-RESOURCE-TABLE LS-RES-IDX.

       MAIN-LOGIC.
      *> Header
           STRING
               "<div class='show-header'>"
                   DELIMITED BY SIZE
               "<div><h1>Create " DELIMITED BY SIZE
               LS-RESOURCE-NAME DELIMITED BY SPACE
               "</h1>" DELIMITED BY SIZE
               "<a href='/list/" DELIMITED BY SIZE
               LS-RESOURCE-NAME DELIMITED BY SPACE
               "'>Back to list</a></div></div>"
                   DELIMITED BY SIZE
               INTO LS-HTML-BODY WITH POINTER LS-HTML-LEN
           END-STRING

      *> Form
           STRING
               "<form method='POST' action='/create/"
                   DELIMITED BY SIZE
               LS-RESOURCE-NAME DELIMITED BY SPACE
               "' class='edit-form'>" DELIMITED BY SIZE
               INTO LS-HTML-BODY WITH POINTER LS-HTML-LEN
           END-STRING

      *> Render editable fields only
           PERFORM VARYING WS-FIELD-IDX FROM 1 BY 1
               UNTIL WS-FIELD-IDX >
                   LS-RES-FIELD-COUNT(LS-RES-IDX)

      *> Skip non-editable fields (id, createdAt)
               IF LS-RES-FIELD-EDIT(LS-RES-IDX, WS-FIELD-IDX)
                   = 1
                   MOVE LS-RES-FIELD-TYPE(
                       LS-RES-IDX, WS-FIELD-IDX)
                       TO WS-FIELD-TYPE

                   PERFORM RENDER-INPUT
               END-IF
           END-PERFORM

      *> Submit
           STRING
               "<div class='form-actions'>"
                   DELIMITED BY SIZE
               "<button type='submit' class='btn'>"
                   DELIMITED BY SIZE
               "Create</button>"
                   DELIMITED BY SIZE
               "<a href='/list/" DELIMITED BY SIZE
               LS-RESOURCE-NAME DELIMITED BY SPACE
               "'>Cancel</a></div></form>"
                   DELIMITED BY SIZE
               INTO LS-HTML-BODY WITH POINTER LS-HTML-LEN
           END-STRING

           GOBACK.

       RENDER-INPUT.
           MOVE "text" TO WS-INPUT-TYPE

           STRING
               "<div class='form-field'>"
                   DELIMITED BY SIZE
               "<label for='" DELIMITED BY SIZE
               LS-RES-FIELD-NAME(LS-RES-IDX, WS-FIELD-IDX)
                   DELIMITED BY SPACE
               "'>" DELIMITED BY SIZE
               LS-RES-FIELD-NAME(LS-RES-IDX, WS-FIELD-IDX)
                   DELIMITED BY SPACE
               "</label>" DELIMITED BY SIZE
               '<input type="' DELIMITED BY SIZE
               WS-INPUT-TYPE DELIMITED BY SPACE
               '" name="' DELIMITED BY SIZE
               LS-RES-FIELD-NAME(LS-RES-IDX, WS-FIELD-IDX)
                   DELIMITED BY SPACE
               INTO LS-HTML-BODY WITH POINTER LS-HTML-LEN
           END-STRING

           IF FUNCTION TRIM(WS-FIELD-TYPE) = "array"
               STRING "[]" DELIMITED BY SIZE
                   INTO LS-HTML-BODY WITH POINTER LS-HTML-LEN
               END-STRING
           END-IF

           STRING
               '" id="' DELIMITED BY SIZE
               LS-RES-FIELD-NAME(LS-RES-IDX, WS-FIELD-IDX)
                   DELIMITED BY SPACE
               '"' DELIMITED BY SIZE
               INTO LS-HTML-BODY WITH POINTER LS-HTML-LEN
           END-STRING

           IF FUNCTION TRIM(WS-FIELD-TYPE) = "array"
               STRING
                   ' placeholder="value1, value2"' DELIMITED BY SIZE
                   INTO LS-HTML-BODY WITH POINTER LS-HTML-LEN
               END-STRING
           END-IF

           STRING '></div>' DELIMITED BY SIZE
               INTO LS-HTML-BODY WITH POINTER LS-HTML-LEN
           END-STRING
           .
