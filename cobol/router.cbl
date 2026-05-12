      *> Matches a request path to a route type, extracts query params
       IDENTIFICATION DIVISION.
       PROGRAM-ID. ROUTER.

       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-IDX               PIC 99 VALUE 0.
       01 WS-SLASH-POS         PIC 9(4) COMP-5 VALUE 0.
       01 WS-QMARK-POS         PIC 9(4) COMP-5 VALUE 0.
       01 WS-CLEAN-PATH        PIC X(512).
       01 WS-CLEAN-LEN         PIC 9(4) COMP-5 VALUE 0.
       01 WS-QUERY-STR         PIC X(512).
       01 WS-SCAN              PIC 9(4) COMP-5 VALUE 0.
       01 WS-PARAM-NAME        PIC X(64).
       01 WS-PARAM-VAL         PIC X(64).
       01 WS-PARAM-LEN         PIC 9(4) COMP-5 VALUE 0.
       01 WS-PARAM-NUMERIC     PIC 9 VALUE 0.

       LINKAGE SECTION.
       01 LS-REQUEST-PATH      PIC X(512).
       01 LS-PATH-LEN          PIC 9(4) COMP-5.
       01 LS-ROUTE-TYPE        PIC X(10).
       01 LS-ROUTE-RESOURCE    PIC X(64).
       01 LS-RESOURCE-TABLE.
          05 LS-RESOURCE-COUNT PIC 99.
          05 LS-RESOURCES OCCURS 20 TIMES.
             10 LS-RES-NAME    PIC X(64).
             10 LS-RES-FIELD-COUNT PIC 99.
             10 LS-RES-FIELDS OCCURS 20 TIMES.
                15 LS-RES-FIELD-NAME PIC X(64).
                15 LS-RES-FIELD-TYPE PIC X(16).
                15 LS-RES-FIELD-EDIT PIC 9.
       01 LS-PAGE              PIC 999.
       01 LS-PER-PAGE          PIC 999.
       01 LS-ROUTE-ID          PIC X(10).
       01 LS-STATIC-PATH       PIC X(512).

       PROCEDURE DIVISION USING
           LS-REQUEST-PATH LS-PATH-LEN
           LS-ROUTE-TYPE LS-ROUTE-RESOURCE
           LS-RESOURCE-TABLE
           LS-PAGE LS-PER-PAGE
           LS-ROUTE-ID LS-STATIC-PATH.

       MAIN-LOGIC.
           MOVE "NOTFOUND" TO LS-ROUTE-TYPE
           MOVE SPACES TO LS-ROUTE-RESOURCE
           MOVE SPACES TO LS-ROUTE-ID
           MOVE SPACES TO LS-STATIC-PATH
           MOVE 1 TO LS-PAGE
           MOVE 10 TO LS-PER-PAGE

      *> Split path from query string at '?'
           MOVE SPACES TO WS-CLEAN-PATH
           MOVE SPACES TO WS-QUERY-STR
           MOVE 0 TO WS-QMARK-POS

           PERFORM VARYING WS-SCAN FROM 1 BY 1
               UNTIL WS-SCAN > LS-PATH-LEN
               IF LS-REQUEST-PATH(WS-SCAN:1) = "?"
                   MOVE WS-SCAN TO WS-QMARK-POS
                   EXIT PERFORM
               END-IF
           END-PERFORM

           IF WS-QMARK-POS > 0
               MOVE LS-REQUEST-PATH(1:WS-QMARK-POS - 1)
                   TO WS-CLEAN-PATH
               COMPUTE WS-CLEAN-LEN = WS-QMARK-POS - 1
               IF LS-PATH-LEN > WS-QMARK-POS
                   MOVE LS-REQUEST-PATH(
                       WS-QMARK-POS + 1:
                       LS-PATH-LEN - WS-QMARK-POS)
                       TO WS-QUERY-STR
               END-IF
               PERFORM PARSE-QUERY-PARAMS
           ELSE
               MOVE LS-REQUEST-PATH TO WS-CLEAN-PATH
               MOVE LS-PATH-LEN TO WS-CLEAN-LEN
           END-IF

      *> Match route
           IF FUNCTION TRIM(WS-CLEAN-PATH) = "/"
               MOVE "HOME" TO LS-ROUTE-TYPE
           ELSE
               IF FUNCTION TRIM(WS-CLEAN-PATH) = "/login"
                   MOVE "LOGIN" TO LS-ROUTE-TYPE
               END-IF
               IF FUNCTION TRIM(WS-CLEAN-PATH) = "/logout"
                   MOVE "LOGOUT" TO LS-ROUTE-TYPE
               END-IF
               IF WS-CLEAN-LEN > 8
                   IF WS-CLEAN-PATH(1:8) = "/static/"
                       MOVE WS-CLEAN-PATH(
                           9:WS-CLEAN-LEN - 8)
                           TO LS-STATIC-PATH
                       MOVE "STATIC" TO LS-ROUTE-TYPE
                   END-IF
               END-IF
               IF WS-CLEAN-LEN > 6
                   IF WS-CLEAN-PATH(1:6) = "/list/"
                       MOVE WS-CLEAN-PATH(
                           7:WS-CLEAN-LEN - 6)
                           TO LS-ROUTE-RESOURCE
                       PERFORM VARYING WS-IDX FROM 1 BY 1
                           UNTIL WS-IDX > LS-RESOURCE-COUNT
                           IF LS-RES-NAME(WS-IDX)
                               = LS-ROUTE-RESOURCE
                               MOVE "LIST" TO LS-ROUTE-TYPE
                               EXIT PERFORM
                           END-IF
                       END-PERFORM
                   END-IF
               END-IF
      *> Match /create/{resource}
               IF WS-CLEAN-LEN > 8
                   IF WS-CLEAN-PATH(1:8) = "/create/"
                       MOVE WS-CLEAN-PATH(
                           9:WS-CLEAN-LEN - 8)
                           TO LS-ROUTE-RESOURCE
                       PERFORM VARYING WS-IDX FROM 1 BY 1
                           UNTIL WS-IDX > LS-RESOURCE-COUNT
                           IF LS-RES-NAME(WS-IDX)
                               = LS-ROUTE-RESOURCE
                               MOVE "CREATE"
                                   TO LS-ROUTE-TYPE
                               EXIT PERFORM
                           END-IF
                       END-PERFORM
                   END-IF
               END-IF
      *> Match /show/{resource}/{id}
               IF WS-CLEAN-LEN > 6
                   IF WS-CLEAN-PATH(1:6) = "/show/"
      *> Find second slash after /show/
                       MOVE 0 TO WS-SLASH-POS
                       PERFORM VARYING WS-SCAN FROM 7 BY 1
                           UNTIL WS-SCAN > WS-CLEAN-LEN
                           IF WS-CLEAN-PATH(WS-SCAN:1) = "/"
                               MOVE WS-SCAN TO WS-SLASH-POS
                               EXIT PERFORM
                           END-IF
                       END-PERFORM
                       IF WS-SLASH-POS > 7
                           MOVE WS-CLEAN-PATH(
                               7:WS-SLASH-POS - 7)
                               TO LS-ROUTE-RESOURCE
                           MOVE WS-CLEAN-PATH(
                               WS-SLASH-POS + 1:
                               WS-CLEAN-LEN - WS-SLASH-POS)
                               TO LS-ROUTE-ID
                           PERFORM VARYING WS-IDX FROM 1 BY 1
                               UNTIL WS-IDX >
                                   LS-RESOURCE-COUNT
                               IF LS-RES-NAME(WS-IDX)
                                   = LS-ROUTE-RESOURCE
                                   MOVE "SHOW"
                                       TO LS-ROUTE-TYPE
                                   EXIT PERFORM
                               END-IF
                           END-PERFORM
                       END-IF
                   END-IF
               END-IF
      *> Match /edit/{resource}/{id}
               IF WS-CLEAN-LEN > 6
                   IF WS-CLEAN-PATH(1:6) = "/edit/"
                       MOVE 0 TO WS-SLASH-POS
                       PERFORM VARYING WS-SCAN FROM 7 BY 1
                           UNTIL WS-SCAN > WS-CLEAN-LEN
                           IF WS-CLEAN-PATH(WS-SCAN:1) = "/"
                               MOVE WS-SCAN TO WS-SLASH-POS
                               EXIT PERFORM
                           END-IF
                       END-PERFORM
                       IF WS-SLASH-POS > 7
                           MOVE WS-CLEAN-PATH(
                               7:WS-SLASH-POS - 7)
                               TO LS-ROUTE-RESOURCE
                           MOVE WS-CLEAN-PATH(
                               WS-SLASH-POS + 1:
                               WS-CLEAN-LEN - WS-SLASH-POS)
                               TO LS-ROUTE-ID
                           PERFORM VARYING WS-IDX FROM 1 BY 1
                               UNTIL WS-IDX >
                                   LS-RESOURCE-COUNT
                               IF LS-RES-NAME(WS-IDX)
                                   = LS-ROUTE-RESOURCE
                                   MOVE "EDIT"
                                       TO LS-ROUTE-TYPE
                                   EXIT PERFORM
                               END-IF
                           END-PERFORM
                       END-IF
                   END-IF
               END-IF
      *> Match /delete/{resource}/{id}
               IF WS-CLEAN-LEN > 8
                   IF WS-CLEAN-PATH(1:8) = "/delete/"
                       MOVE 0 TO WS-SLASH-POS
                       PERFORM VARYING WS-SCAN FROM 9 BY 1
                           UNTIL WS-SCAN > WS-CLEAN-LEN
                           IF WS-CLEAN-PATH(WS-SCAN:1) = "/"
                               MOVE WS-SCAN TO WS-SLASH-POS
                               EXIT PERFORM
                           END-IF
                       END-PERFORM
                       IF WS-SLASH-POS > 9
                           MOVE WS-CLEAN-PATH(
                               9:WS-SLASH-POS - 9)
                               TO LS-ROUTE-RESOURCE
                           MOVE WS-CLEAN-PATH(
                               WS-SLASH-POS + 1:
                               WS-CLEAN-LEN - WS-SLASH-POS)
                               TO LS-ROUTE-ID
                           PERFORM VARYING WS-IDX FROM 1 BY 1
                               UNTIL WS-IDX >
                                   LS-RESOURCE-COUNT
                               IF LS-RES-NAME(WS-IDX)
                                   = LS-ROUTE-RESOURCE
                                   MOVE "DELETE"
                                       TO LS-ROUTE-TYPE
                                   EXIT PERFORM
                               END-IF
                           END-PERFORM
                       END-IF
                   END-IF
               END-IF
           END-IF

           GOBACK.

      *> Parse page= and perPage= from query string
       PARSE-QUERY-PARAMS.
      *> Use simple scan: look for "page=" and "perPage="
           PERFORM EXTRACT-PAGE-PARAM
           PERFORM EXTRACT-PERPAGE-PARAM
           .

       EXTRACT-PAGE-PARAM.
           MOVE 0 TO WS-SCAN
           INSPECT WS-QUERY-STR TALLYING WS-SCAN
               FOR CHARACTERS BEFORE INITIAL "page="
           IF WS-SCAN < FUNCTION LENGTH(
               FUNCTION TRIM(WS-QUERY-STR TRAILING))
      *> Check it's not "perPage=" by verifying char before
               IF WS-SCAN = 0 OR
                   WS-QUERY-STR(WS-SCAN:1) = "&"
                   COMPUTE WS-SCAN = WS-SCAN + 6
                   MOVE SPACES TO WS-PARAM-VAL
                   PERFORM VARYING WS-IDX FROM 1 BY 1
                       UNTIL WS-IDX > 5
                       IF WS-QUERY-STR(WS-SCAN:1) = "&"
                           OR WS-QUERY-STR(WS-SCAN:1) = SPACE
                           EXIT PERFORM
                       END-IF
                       MOVE WS-QUERY-STR(WS-SCAN:1)
                           TO WS-PARAM-VAL(WS-IDX:1)
                       ADD 1 TO WS-SCAN
                   END-PERFORM
                   IF WS-PARAM-VAL NOT = SPACES
                       PERFORM VALIDATE-PARAM-NUMERIC
                       IF WS-PARAM-NUMERIC = 1
                           COMPUTE LS-PAGE =
                               FUNCTION NUMVAL(
                                   FUNCTION TRIM(
                                       WS-PARAM-VAL TRAILING))
                           IF LS-PAGE < 1
                               MOVE 1 TO LS-PAGE
                           END-IF
                           IF LS-PAGE > 999
                               MOVE 999 TO LS-PAGE
                           END-IF
                       END-IF
                   END-IF
               END-IF
           END-IF
           .

       EXTRACT-PERPAGE-PARAM.
           MOVE 0 TO WS-SCAN
           INSPECT WS-QUERY-STR TALLYING WS-SCAN
               FOR CHARACTERS BEFORE INITIAL "perPage="
           IF WS-SCAN < FUNCTION LENGTH(
               FUNCTION TRIM(WS-QUERY-STR TRAILING))
               COMPUTE WS-SCAN = WS-SCAN + 9
               MOVE SPACES TO WS-PARAM-VAL
               PERFORM VARYING WS-IDX FROM 1 BY 1
                   UNTIL WS-IDX > 5
                   IF WS-QUERY-STR(WS-SCAN:1) = "&"
                       OR WS-QUERY-STR(WS-SCAN:1) = SPACE
                       EXIT PERFORM
                   END-IF
                   MOVE WS-QUERY-STR(WS-SCAN:1)
                       TO WS-PARAM-VAL(WS-IDX:1)
                   ADD 1 TO WS-SCAN
               END-PERFORM
               IF WS-PARAM-VAL NOT = SPACES
                   PERFORM VALIDATE-PARAM-NUMERIC
                   IF WS-PARAM-NUMERIC = 1
                       COMPUTE LS-PER-PAGE =
                           FUNCTION NUMVAL(
                               FUNCTION TRIM(
                                   WS-PARAM-VAL TRAILING))
                       IF LS-PER-PAGE < 1
                           MOVE 10 TO LS-PER-PAGE
                       END-IF
                       IF LS-PER-PAGE > 100
                           MOVE 100 TO LS-PER-PAGE
                       END-IF
                   END-IF
               END-IF
           END-IF
           .

       VALIDATE-PARAM-NUMERIC.
           MOVE 1 TO WS-PARAM-NUMERIC
           MOVE FUNCTION LENGTH(
               FUNCTION TRIM(WS-PARAM-VAL TRAILING))
               TO WS-PARAM-LEN

           IF WS-PARAM-LEN = 0
               MOVE 0 TO WS-PARAM-NUMERIC
           ELSE
               PERFORM VARYING WS-IDX FROM 1 BY 1
                   UNTIL WS-IDX > WS-PARAM-LEN
                   IF WS-PARAM-VAL(WS-IDX:1) < "0"
                       OR WS-PARAM-VAL(WS-IDX:1) > "9"
                       MOVE 0 TO WS-PARAM-NUMERIC
                       EXIT PERFORM
                   END-IF
               END-PERFORM
           END-IF
           .
