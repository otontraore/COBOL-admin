      *> Shared HTML layout: renders full page with nav + content
       IDENTIFICATION DIVISION.
       PROGRAM-ID. PAGE-LAYOUT.

       DATA DIVISION.
       WORKING-STORAGE SECTION.
       COPY "ws-template.cpy".
       01 WS-TPL-ACTION          PIC X(6).
       01 WS-TPL-KEY             PIC X(256).
       01 WS-TPL-VALUE           PIC X(1024).
       01 WS-IDX                 PIC 99 VALUE 0.
       01 WS-NAV-LINKS           PIC X(1024).
       01 WS-NAV-PTR             PIC 9(5) COMP-5.
    01 WS-CAN-READ            PIC S9(9) COMP-5 VALUE 0.
    01 WS-READ-ACTION         PIC X(16) VALUE "read".

       LINKAGE SECTION.
       01 LS-HTML-BODY         PIC X(32768).
       01 LS-HTML-LEN          PIC 9(8) COMP-5.
       01 LS-RESOURCE-TABLE.
          05 LS-RESOURCE-COUNT PIC 99.
          05 LS-RESOURCES OCCURS 20 TIMES.
             10 LS-RES-NAME    PIC X(64).
             10 LS-RES-FIELD-COUNT PIC 99.
             10 LS-RES-FIELDS OCCURS 20 TIMES.
                15 LS-RES-FIELD-NAME PIC X(64).
                15 LS-RES-FIELD-TYPE PIC X(16).
                15 LS-RES-FIELD-EDIT PIC 9.
       01 LS-CONTENT-BUF       PIC X(16384).
       01 LS-CONTENT-LEN       PIC 9(8) COMP-5.
       01 LS-AUTH-USER-NAME    PIC X(64).
       01 LS-AUTH-PERMISSIONS  PIC X(4096).

       PROCEDURE DIVISION USING
           LS-HTML-BODY LS-HTML-LEN
           LS-RESOURCE-TABLE
           LS-CONTENT-BUF LS-CONTENT-LEN
           LS-AUTH-USER-NAME LS-AUTH-PERMISSIONS.

       MAIN-LOGIC.
      *> Build nav links into a buffer
           MOVE SPACES TO WS-NAV-LINKS
           MOVE 1 TO WS-NAV-PTR
           PERFORM VARYING WS-IDX FROM 1 BY 1
               UNTIL WS-IDX > LS-RESOURCE-COUNT
               CALL "cobol_auth_can" USING
                   BY REFERENCE LS-AUTH-PERMISSIONS
                   BY REFERENCE LS-RES-NAME(WS-IDX)
                   BY REFERENCE WS-READ-ACTION
                   RETURNING WS-CAN-READ
               END-CALL
               IF WS-CAN-READ = 1
                   STRING
                       "<a href='/list/" DELIMITED BY SIZE
                       LS-RES-NAME(WS-IDX) DELIMITED BY SPACE
                       "'>" DELIMITED BY SIZE
                       LS-RES-NAME(WS-IDX) DELIMITED BY SPACE
                       "</a>" DELIMITED BY SIZE
                       INTO WS-NAV-LINKS WITH POINTER WS-NAV-PTR
                   END-STRING
               END-IF
           END-PERFORM

           IF FUNCTION TRIM(LS-AUTH-USER-NAME) NOT = SPACES
               STRING
                   "<span class='nav-user'>" DELIMITED BY SIZE
                   LS-AUTH-USER-NAME DELIMITED BY SPACE
                   "</span><a href='/logout'>Logout</a>"
                       DELIMITED BY SIZE
                   INTO WS-NAV-LINKS WITH POINTER WS-NAV-PTR
               END-STRING
           END-IF

      *> Set nav variable
           MOVE 0 TO WS-TPL-VAR-COUNT
           MOVE "SET" TO WS-TPL-ACTION
           MOVE "nav" TO WS-TPL-KEY
           MOVE WS-NAV-LINKS TO WS-TPL-VALUE
           CALL "TEMPLATE-ENGINE" USING
               LS-HTML-BODY LS-HTML-LEN
               WS-TPL-ACTION WS-TPL-KEY WS-TPL-VALUE
               WS-TPL-VARS
               LS-CONTENT-BUF LS-CONTENT-LEN
           END-CALL

      *> Render layout template ({{content}} handled by engine)
           MOVE "RENDER" TO WS-TPL-ACTION
           MOVE "templates/layout.html" TO WS-TPL-KEY
           CALL "TEMPLATE-ENGINE" USING
               LS-HTML-BODY LS-HTML-LEN
               WS-TPL-ACTION WS-TPL-KEY WS-TPL-VALUE
               WS-TPL-VARS
               LS-CONTENT-BUF LS-CONTENT-LEN
           END-CALL
           GOBACK.
