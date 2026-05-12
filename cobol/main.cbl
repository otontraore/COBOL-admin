      *> COBOL Admin - Main entry point
      *> Orchestrates HTTP server, routing, and page rendering
       IDENTIFICATION DIVISION.
       PROGRAM-ID. COBOL-ADMIN.

       DATA DIVISION.
       WORKING-STORAGE SECTION.
       COPY "ws-config.cpy".
       COPY "ws-socket.cpy".
       COPY "ws-http.cpy".
       COPY "ws-html.cpy".
       COPY "ws-resource.cpy".
       COPY "ws-route.cpy".
    COPY "ws-auth.cpy".

      *> Send loop
       01 WS-SEND-OFFSET       PIC 9(8) COMP-5 VALUE 0.
       01 WS-SEND-REMAINING    PIC 9(8) COMP-5 VALUE 0.

      *> (removed layout action - now single call)

      *> Resource lookup
       01 WS-MATCHED-RES-IDX   PIC 99 VALUE 0.

      *> Form submit status
       01 WS-SUBMIT-STATUS     PIC 9 VALUE 0.
       01 WS-CREATED-ID        PIC X(10).

      *> Static file serving
       01 WS-STATIC-BODY       PIC X(32768).
       01 WS-STATIC-LEN        PIC 9(8) COMP-5 VALUE 0.
       01 WS-CONTENT-TYPE      PIC X(64).
       01 WS-STATIC-FOUND      PIC 9 VALUE 0.
        01 WS-LOGIN-ERROR       PIC 9 VALUE 0.

       PROCEDURE DIVISION.

       MAIN-LOGIC.
           DISPLAY "COBOL Admin Server starting..."

      *> Read API URL from environment, fallback to default
           ACCEPT API-BASE-URL FROM ENVIRONMENT "API_BASE_URL"
           IF API-BASE-URL = SPACES
               MOVE "http://server:3000" TO API-BASE-URL
           END-IF
           DISPLAY "API URL: " FUNCTION TRIM(API-BASE-URL)

           CALL "SCHEMA-LOADER" USING
               API-BASE-URL WS-RESOURCE-TABLE
           END-CALL

           PERFORM INIT-SOCKET
           IF SOCKET-HANDLE < 0
               DISPLAY "Failed to initialize socket"
               STOP RUN
           END-IF

           PERFORM ACCEPT-LOOP UNTIL 1 = 0
           STOP RUN.

      *>
      *> INIT-SOCKET: Create, bind and listen on TCP socket
      *>
       INIT-SOCKET.
           CALL "socket" USING
               BY VALUE 2 BY VALUE 1 BY VALUE 0
               RETURNING SOCKET-HANDLE
           END-CALL
           IF SOCKET-HANDLE < 0
               DISPLAY "Socket creation failed"
               GOBACK
           END-IF

           CALL "setsockopt" USING
               BY VALUE SOCKET-HANDLE
               BY VALUE 1 BY VALUE 2
               BY REFERENCE SOCKET-OPT BY VALUE 4
               RETURNING SOCKET-RESULT
           END-CALL

           COMPUTE WS-PORT-NETWORK =
               FUNCTION MOD(SERVER-PORT, 256) * 256 +
               SERVER-PORT / 256
           MOVE WS-PORT-NETWORK TO SA-PORT
           MOVE FUNCTION BYTE-LENGTH(SERVER-ADDRESS) TO ADDR-LEN

           CALL "bind" USING
               BY VALUE SOCKET-HANDLE
               BY REFERENCE SERVER-ADDRESS
               BY VALUE ADDR-LEN
               RETURNING SOCKET-RESULT
           END-CALL
           IF SOCKET-RESULT < 0
               DISPLAY "Bind failed"
               GOBACK
           END-IF

           CALL "listen" USING
               BY VALUE SOCKET-HANDLE BY VALUE 10
               RETURNING SOCKET-RESULT
           END-CALL
           IF SOCKET-RESULT < 0
               DISPLAY "Listen failed"
               GOBACK
           END-IF

           DISPLAY "Server listening on port " SERVER-PORT
           .

      *>
      *> ACCEPT-LOOP: Accept client connections
      *>
       ACCEPT-LOOP.
           MOVE FUNCTION BYTE-LENGTH(SERVER-ADDRESS) TO ADDR-LEN

           CALL "accept" USING
               BY VALUE SOCKET-HANDLE
               BY REFERENCE SERVER-ADDRESS
               BY REFERENCE ADDR-LEN
               RETURNING CLIENT-SOCKET
           END-CALL

           IF CLIENT-SOCKET < 0
               DISPLAY "Accept failed"
               GOBACK
           END-IF

           ADD 1 TO WS-REQUEST-COUNT
           PERFORM HANDLE-REQUEST

           CALL "close" USING BY VALUE CLIENT-SOCKET
           END-CALL
           .

      *>
      *> HANDLE-REQUEST: Read, route, build page, respond
      *>
       HANDLE-REQUEST.
           CALL "cobol_cleanup_temp" END-CALL

           MOVE LOW-VALUE TO REQUEST-BUFFER
           MOVE LOW-VALUE TO RESPONSE-BUFFER
           MOVE 0 TO RESPONSE-LEN

           CALL "recv" USING
               BY VALUE CLIENT-SOCKET
               BY REFERENCE REQUEST-BUFFER
               BY VALUE 4096 BY VALUE 0
               RETURNING BYTES-READ
           END-CALL

           IF BYTES-READ <= 0
               GOBACK
           END-IF

      *> Parse request
           CALL "HTTP-PARSE" USING
               REQUEST-BUFFER WS-REQUEST-METHOD
               WS-REQUEST-PATH WS-PATH-LEN
               WS-REQUEST-BODY WS-BODY-LEN
           END-CALL

           DISPLAY "Request #" WS-REQUEST-COUNT " "
               FUNCTION TRIM(WS-REQUEST-METHOD) " "
               FUNCTION TRIM(WS-REQUEST-PATH)

      *> Route the request
           CALL "ROUTER" USING
               WS-REQUEST-PATH WS-PATH-LEN
               WS-ROUTE-TYPE WS-ROUTE-RESOURCE
               WS-RESOURCE-TABLE
               WS-PAGE WS-PER-PAGE
               WS-ROUTE-ID WS-STATIC-PATH
           END-CALL

           PERFORM RESOLVE-AUTH

           IF ROUTE-LOGOUT
               PERFORM SEND-LOGOUT-REDIRECT
               EXIT PARAGRAPH
           END-IF

           IF ROUTE-LOGIN
               IF FUNCTION TRIM(WS-REQUEST-METHOD) = "POST"
                   PERFORM HANDLE-LOGIN
               ELSE
                   MOVE 0 TO WS-LOGIN-ERROR
                   PERFORM RENDER-LOGIN
               END-IF
               EXIT PARAGRAPH
           END-IF

           IF NOT ROUTE-STATIC
               IF WS-AUTH-OK = 0
                   PERFORM SEND-LOGIN-REDIRECT
                   EXIT PARAGRAPH
               END-IF
               CALL "cobol_auth_check" USING
                   BY REFERENCE WS-AUTH-PERMISSIONS
                   BY REFERENCE WS-ROUTE-RESOURCE
                   BY REFERENCE WS-ROUTE-TYPE
                   BY REFERENCE WS-REQUEST-METHOD
                   RETURNING WS-AUTH-ALLOWED
               END-CALL
               IF WS-AUTH-ALLOWED NOT = 1
                   PERFORM SEND-FORBIDDEN
                   EXIT PARAGRAPH
               END-IF
           END-IF

      *> Handle POST on delete: delete and redirect to list
           IF ROUTE-DELETE AND
               FUNCTION TRIM(WS-REQUEST-METHOD) = "POST"
               PERFORM DELETE-AND-REDIRECT
           ELSE

      *> Handle POST on create: submit form and redirect
           IF ROUTE-CREATE AND
               FUNCTION TRIM(WS-REQUEST-METHOD) = "POST"
               CALL "FORM-CREATE" USING
                   API-BASE-URL WS-ROUTE-RESOURCE
                   WS-REQUEST-BODY WS-BODY-LEN
                   WS-CREATED-ID WS-SUBMIT-STATUS
               END-CALL
               IF WS-SUBMIT-STATUS = 1
                   MOVE WS-CREATED-ID TO WS-ROUTE-ID
                   PERFORM SEND-REDIRECT
               ELSE
                   MOVE LOW-VALUE TO WS-PAGE-CONTENT
                   MOVE 1 TO WS-PAGE-LEN
                   STRING
                       "<h1>Error</h1>"
                           DELIMITED BY SIZE
                       "<p class='error'>Failed to create."
                           DELIMITED BY SIZE
                       " Please try again.</p>"
                           DELIMITED BY SIZE
                       "<p><a href='/create/"
                           DELIMITED BY SIZE
                       WS-ROUTE-RESOURCE DELIMITED BY SPACE
                       "'>Back to form</a></p>"
                           DELIMITED BY SIZE
                       INTO WS-PAGE-CONTENT
                           WITH POINTER WS-PAGE-LEN
                   END-STRING
                   SUBTRACT 1 FROM WS-PAGE-LEN
                   MOVE LOW-VALUE TO HTML-BODY
                   MOVE 1 TO HTML-LEN
                   CALL "PAGE-LAYOUT" USING
                       HTML-BODY HTML-LEN
                       WS-RESOURCE-TABLE
                       WS-PAGE-CONTENT WS-PAGE-LEN
                       WS-AUTH-USER-NAME WS-AUTH-PERMISSIONS
                   END-CALL
                   SUBTRACT 1 FROM HTML-LEN
                   PERFORM SEND-RESPONSE
               END-IF
           ELSE

      *> Handle POST on edit: submit form and redirect
           IF ROUTE-EDIT AND
               FUNCTION TRIM(WS-REQUEST-METHOD) = "POST"
               PERFORM FIND-RESOURCE-IDX
               CALL "FORM-SUBMIT" USING
                   API-BASE-URL WS-ROUTE-RESOURCE
                   WS-ROUTE-ID
                   WS-REQUEST-BODY WS-BODY-LEN
                   WS-SUBMIT-STATUS
               END-CALL
               IF WS-SUBMIT-STATUS = 1
                   PERFORM SEND-REDIRECT
               ELSE
      *> Show error — render edit page with error message
                   MOVE LOW-VALUE TO WS-PAGE-CONTENT
                   MOVE 1 TO WS-PAGE-LEN
                   STRING
                       "<h1>Error</h1>"
                           DELIMITED BY SIZE
                       "<p class='error'>Failed to save."
                           DELIMITED BY SIZE
                       " Please try again.</p>"
                           DELIMITED BY SIZE
                       "<p><a href='/edit/"
                           DELIMITED BY SIZE
                       WS-ROUTE-RESOURCE DELIMITED BY SPACE
                       "/" DELIMITED BY SIZE
                       WS-ROUTE-ID DELIMITED BY SPACE
                       "'>Back to edit</a></p>"
                           DELIMITED BY SIZE
                       INTO WS-PAGE-CONTENT
                           WITH POINTER WS-PAGE-LEN
                   END-STRING
                   SUBTRACT 1 FROM WS-PAGE-LEN
                   MOVE LOW-VALUE TO HTML-BODY
                   MOVE 1 TO HTML-LEN
                   CALL "PAGE-LAYOUT" USING
                       HTML-BODY HTML-LEN
                       WS-RESOURCE-TABLE
                       WS-PAGE-CONTENT WS-PAGE-LEN
                       WS-AUTH-USER-NAME WS-AUTH-PERMISSIONS
                   END-CALL
                   SUBTRACT 1 FROM HTML-LEN
                   PERFORM SEND-RESPONSE
               END-IF
           ELSE

      *> Handle static files separately
           IF ROUTE-STATIC
               CALL "SERVE-STATIC" USING
                   WS-STATIC-PATH
                   WS-STATIC-BODY WS-STATIC-LEN
                   WS-CONTENT-TYPE WS-STATIC-FOUND
               END-CALL
               IF WS-STATIC-FOUND = 1
                   PERFORM SEND-STATIC-RESPONSE
               ELSE
                   MOVE "NOTFOUND" TO WS-ROUTE-TYPE
               END-IF
           END-IF

           IF NOT ROUTE-STATIC
      *> Render page content into separate buffer
               MOVE LOW-VALUE TO WS-PAGE-CONTENT
               MOVE 1 TO WS-PAGE-LEN

               EVALUATE TRUE
                   WHEN ROUTE-HOME
                       CALL "PAGE-HOME" USING
                           WS-PAGE-CONTENT WS-PAGE-LEN
                   WHEN ROUTE-LIST
                       PERFORM FIND-RESOURCE-IDX
                       CALL "PAGE-LIST" USING
                           WS-PAGE-CONTENT WS-PAGE-LEN
                           WS-ROUTE-RESOURCE
                           API-BASE-URL
                           WS-PAGE WS-PER-PAGE WS-TOTAL-COUNT
                           WS-RESOURCE-TABLE
                           WS-MATCHED-RES-IDX
                           WS-AUTH-PERMISSIONS
                   WHEN ROUTE-SHOW
                       PERFORM FIND-RESOURCE-IDX
                       CALL "PAGE-SHOW" USING
                           WS-PAGE-CONTENT WS-PAGE-LEN
                           WS-ROUTE-RESOURCE WS-ROUTE-ID
                           API-BASE-URL
                           WS-RESOURCE-TABLE
                           WS-MATCHED-RES-IDX
                           WS-AUTH-PERMISSIONS
                   WHEN ROUTE-EDIT
                       PERFORM FIND-RESOURCE-IDX
                       CALL "PAGE-EDIT" USING
                           WS-PAGE-CONTENT WS-PAGE-LEN
                           WS-ROUTE-RESOURCE WS-ROUTE-ID
                           API-BASE-URL
                           WS-RESOURCE-TABLE
                           WS-MATCHED-RES-IDX
                           WS-AUTH-PERMISSIONS
                   WHEN ROUTE-CREATE
                       PERFORM FIND-RESOURCE-IDX
                       CALL "PAGE-CREATE" USING
                           WS-PAGE-CONTENT WS-PAGE-LEN
                           WS-ROUTE-RESOURCE
                           WS-RESOURCE-TABLE
                           WS-MATCHED-RES-IDX
                   WHEN ROUTE-DELETE
                       CALL "PAGE-DELETE" USING
                           WS-PAGE-CONTENT WS-PAGE-LEN
                           WS-ROUTE-RESOURCE WS-ROUTE-ID
                   WHEN ROUTE-NOT-FOUND
                       CALL "PAGE-404" USING
                           WS-PAGE-CONTENT WS-PAGE-LEN
               END-EVALUATE

      *> Wrap page content in layout template
               SUBTRACT 1 FROM WS-PAGE-LEN
               MOVE LOW-VALUE TO HTML-BODY
               MOVE 1 TO HTML-LEN

               CALL "PAGE-LAYOUT" USING
                   HTML-BODY HTML-LEN
                   WS-RESOURCE-TABLE
                   WS-PAGE-CONTENT WS-PAGE-LEN
                   WS-AUTH-USER-NAME WS-AUTH-PERMISSIONS
               END-CALL

               SUBTRACT 1 FROM HTML-LEN
               PERFORM SEND-RESPONSE
           END-IF
           END-IF
           END-IF
           END-IF
           .

      *>
      *> SEND-STATIC-RESPONSE: Send static file with content-type
      *>
      *>
      *> RESOLVE-AUTH: Load current user from sid cookie
      *>
       RESOLVE-AUTH.
           MOVE 0 TO WS-AUTH-OK
           MOVE SPACES TO WS-AUTH-SESSION-ID
           MOVE SPACES TO WS-AUTH-USER-NAME
           MOVE SPACES TO WS-AUTH-ROLE-NAME
           MOVE SPACES TO WS-AUTH-PERMISSIONS

           CALL "cobol_extract_session_cookie" USING
               BY REFERENCE REQUEST-BUFFER
               BY REFERENCE WS-AUTH-SESSION-ID
               RETURNING WS-AUTH-STATUS
           END-CALL

           IF WS-AUTH-STATUS = 1
               CALL "cobol_auth_me" USING
                   BY REFERENCE API-BASE-URL
                   BY REFERENCE WS-AUTH-SESSION-ID
                   BY REFERENCE WS-AUTH-USER-NAME
                   BY REFERENCE WS-AUTH-ROLE-NAME
                   BY REFERENCE WS-AUTH-PERMISSIONS
                   RETURNING WS-AUTH-STATUS
               END-CALL
               IF WS-AUTH-STATUS = 0
                   MOVE 1 TO WS-AUTH-OK
               END-IF
           END-IF
           .

       HANDLE-LOGIN.
           CALL "cobol_auth_login" USING
               BY REFERENCE API-BASE-URL
               BY REFERENCE WS-REQUEST-BODY
               BY VALUE WS-BODY-LEN
               BY REFERENCE WS-AUTH-SESSION-ID
               BY REFERENCE WS-AUTH-USER-NAME
               BY REFERENCE WS-AUTH-ROLE-NAME
               BY REFERENCE WS-AUTH-PERMISSIONS
               RETURNING WS-AUTH-STATUS
           END-CALL

           IF WS-AUTH-STATUS = 0
               PERFORM SEND-LOGIN-SUCCESS-REDIRECT
           ELSE
               MOVE 1 TO WS-LOGIN-ERROR
               PERFORM RENDER-LOGIN
           END-IF
           .

       RENDER-LOGIN.
           MOVE LOW-VALUE TO WS-PAGE-CONTENT
           MOVE 1 TO WS-PAGE-LEN
           CALL "PAGE-LOGIN" USING
               WS-PAGE-CONTENT WS-PAGE-LEN WS-LOGIN-ERROR
           END-CALL
           SUBTRACT 1 FROM WS-PAGE-LEN

           MOVE LOW-VALUE TO HTML-BODY
           MOVE 1 TO HTML-LEN
           MOVE SPACES TO WS-AUTH-USER-NAME
           MOVE SPACES TO WS-AUTH-PERMISSIONS
           CALL "PAGE-LAYOUT" USING
               HTML-BODY HTML-LEN
               WS-RESOURCE-TABLE
               WS-PAGE-CONTENT WS-PAGE-LEN
               WS-AUTH-USER-NAME WS-AUTH-PERMISSIONS
           END-CALL
           SUBTRACT 1 FROM HTML-LEN
           PERFORM SEND-RESPONSE
           .

       SEND-LOGIN-REDIRECT.
           MOVE LOW-VALUE TO RESPONSE-BUFFER
           STRING
               "HTTP/1.1 303 See Other" DELIMITED BY SIZE
               WS-CRLF DELIMITED BY SIZE
               "Location: /login" DELIMITED BY SIZE
               WS-CRLF DELIMITED BY SIZE
               "Connection: close" DELIMITED BY SIZE
               WS-CRLF DELIMITED BY SIZE
               WS-CRLF DELIMITED BY SIZE
               INTO RESPONSE-BUFFER
           END-STRING
           MOVE 0 TO RESPONSE-LEN
           INSPECT RESPONSE-BUFFER TALLYING RESPONSE-LEN
               FOR CHARACTERS BEFORE INITIAL LOW-VALUE
           PERFORM SEND-BUFFER
           .

       SEND-LOGIN-SUCCESS-REDIRECT.
           MOVE LOW-VALUE TO RESPONSE-BUFFER
           STRING
               "HTTP/1.1 303 See Other" DELIMITED BY SIZE
               WS-CRLF DELIMITED BY SIZE
               "Location: /" DELIMITED BY SIZE
               WS-CRLF DELIMITED BY SIZE
               "Set-Cookie: sid=" DELIMITED BY SIZE
               WS-AUTH-SESSION-ID DELIMITED BY SPACE
               "; Path=/; HttpOnly; SameSite=Lax" DELIMITED BY SIZE
               WS-CRLF DELIMITED BY SIZE
               "Connection: close" DELIMITED BY SIZE
               WS-CRLF DELIMITED BY SIZE
               WS-CRLF DELIMITED BY SIZE
               INTO RESPONSE-BUFFER
           END-STRING
           MOVE 0 TO RESPONSE-LEN
           INSPECT RESPONSE-BUFFER TALLYING RESPONSE-LEN
               FOR CHARACTERS BEFORE INITIAL LOW-VALUE
           PERFORM SEND-BUFFER
           .

       SEND-LOGOUT-REDIRECT.
           MOVE LOW-VALUE TO RESPONSE-BUFFER
           STRING
               "HTTP/1.1 303 See Other" DELIMITED BY SIZE
               WS-CRLF DELIMITED BY SIZE
               "Location: /login" DELIMITED BY SIZE
               WS-CRLF DELIMITED BY SIZE
               "Set-Cookie: sid=; Path=/; Max-Age=0; HttpOnly"
                   DELIMITED BY SIZE
               WS-CRLF DELIMITED BY SIZE
               "Connection: close" DELIMITED BY SIZE
               WS-CRLF DELIMITED BY SIZE
               WS-CRLF DELIMITED BY SIZE
               INTO RESPONSE-BUFFER
           END-STRING
           MOVE 0 TO RESPONSE-LEN
           INSPECT RESPONSE-BUFFER TALLYING RESPONSE-LEN
               FOR CHARACTERS BEFORE INITIAL LOW-VALUE
           PERFORM SEND-BUFFER
           .

       SEND-FORBIDDEN.
           MOVE LOW-VALUE TO WS-PAGE-CONTENT
           MOVE 1 TO WS-PAGE-LEN
           STRING
               "<h1>403 - Forbidden</h1>" DELIMITED BY SIZE
               "<p class='error'>You do not have permission"
                   DELIMITED BY SIZE
               " to access this page.</p>" DELIMITED BY SIZE
               INTO WS-PAGE-CONTENT WITH POINTER WS-PAGE-LEN
           END-STRING
           SUBTRACT 1 FROM WS-PAGE-LEN

           MOVE LOW-VALUE TO HTML-BODY
           MOVE 1 TO HTML-LEN
           CALL "PAGE-LAYOUT" USING
               HTML-BODY HTML-LEN
               WS-RESOURCE-TABLE
               WS-PAGE-CONTENT WS-PAGE-LEN
               WS-AUTH-USER-NAME WS-AUTH-PERMISSIONS
           END-CALL
           SUBTRACT 1 FROM HTML-LEN

           MOVE LOW-VALUE TO RESPONSE-BUFFER
           MOVE HTML-LEN TO WS-LEN-STR
           STRING
               "HTTP/1.1 403 Forbidden" DELIMITED BY SIZE
               WS-CRLF DELIMITED BY SIZE
               "Content-Type: text/html; charset=utf-8"
                   DELIMITED BY SIZE
               WS-CRLF DELIMITED BY SIZE
               "Content-Length: " DELIMITED BY SIZE
               WS-LEN-STR DELIMITED BY SPACE
               WS-CRLF DELIMITED BY SIZE
               "Connection: close" DELIMITED BY SIZE
               WS-CRLF DELIMITED BY SIZE
               WS-CRLF DELIMITED BY SIZE
               INTO RESPONSE-BUFFER
           END-STRING
           MOVE 0 TO RESPONSE-LEN
           INSPECT RESPONSE-BUFFER TALLYING RESPONSE-LEN
               FOR CHARACTERS BEFORE INITIAL LOW-VALUE
           MOVE HTML-BODY(1:HTML-LEN)
               TO RESPONSE-BUFFER(RESPONSE-LEN + 1:HTML-LEN)
           ADD HTML-LEN TO RESPONSE-LEN
           PERFORM SEND-BUFFER
           .

      *>
      *> DELETE-AND-REDIRECT: Delete resource and redirect to list
      *>
       DELETE-AND-REDIRECT.
      *> Build DELETE URL
           MOVE LOW-VALUE TO RESPONSE-BUFFER
           STRING
               FUNCTION TRIM(API-BASE-URL) DELIMITED BY SIZE
               "/" DELIMITED BY SIZE
               WS-ROUTE-RESOURCE DELIMITED BY SPACE
               "/" DELIMITED BY SIZE
               WS-ROUTE-ID DELIMITED BY SPACE
               LOW-VALUE DELIMITED BY SIZE
               INTO RESPONSE-BUFFER
           END-STRING

           CALL "cobol_http_delete" USING
               BY REFERENCE RESPONSE-BUFFER
               RETURNING WS-SUBMIT-STATUS
           END-CALL

           PERFORM SEND-LIST-REDIRECT
           .

      *>
      *> SEND-LIST-REDIRECT: Redirect to list page
      *>
       SEND-LIST-REDIRECT.
           MOVE LOW-VALUE TO RESPONSE-BUFFER
           STRING
               "HTTP/1.1 303 See Other" DELIMITED BY SIZE
               WS-CRLF DELIMITED BY SIZE
               "Location: /list/" DELIMITED BY SIZE
               WS-ROUTE-RESOURCE DELIMITED BY SPACE
               WS-CRLF DELIMITED BY SIZE
               "Connection: close" DELIMITED BY SIZE
               WS-CRLF DELIMITED BY SIZE
               WS-CRLF DELIMITED BY SIZE
               INTO RESPONSE-BUFFER
           END-STRING
           MOVE 0 TO RESPONSE-LEN
           INSPECT RESPONSE-BUFFER TALLYING RESPONSE-LEN
               FOR CHARACTERS BEFORE INITIAL LOW-VALUE
           PERFORM SEND-BUFFER
           .

      *>
      *> FIND-RESOURCE-IDX: Find WS-MATCHED-RES-IDX for route
      *>
       FIND-RESOURCE-IDX.
           PERFORM VARYING WS-MATCHED-RES-IDX FROM 1 BY 1
               UNTIL WS-MATCHED-RES-IDX > WS-RESOURCE-COUNT
               IF WS-RES-NAME(WS-MATCHED-RES-IDX)
                   = WS-ROUTE-RESOURCE
                   EXIT PERFORM
               END-IF
           END-PERFORM
           .

       SEND-REDIRECT.
           MOVE LOW-VALUE TO RESPONSE-BUFFER
           STRING
               "HTTP/1.1 303 See Other" DELIMITED BY SIZE
               WS-CRLF DELIMITED BY SIZE
               "Location: /show/" DELIMITED BY SIZE
               WS-ROUTE-RESOURCE DELIMITED BY SPACE
               "/" DELIMITED BY SIZE
               WS-ROUTE-ID DELIMITED BY SPACE
               WS-CRLF DELIMITED BY SIZE
               "Connection: close" DELIMITED BY SIZE
               WS-CRLF DELIMITED BY SIZE
               WS-CRLF DELIMITED BY SIZE
               INTO RESPONSE-BUFFER
           END-STRING
           MOVE 0 TO RESPONSE-LEN
           INSPECT RESPONSE-BUFFER TALLYING RESPONSE-LEN
               FOR CHARACTERS BEFORE INITIAL LOW-VALUE
           PERFORM SEND-BUFFER
           .

       SEND-STATIC-RESPONSE.
           MOVE LOW-VALUE TO RESPONSE-BUFFER
           MOVE WS-STATIC-LEN TO WS-LEN-STR
           STRING
               "HTTP/1.1 200 OK" DELIMITED BY SIZE
               WS-CRLF DELIMITED BY SIZE
               "Content-Type: " DELIMITED BY SIZE
               WS-CONTENT-TYPE DELIMITED BY SPACE
               WS-CRLF DELIMITED BY SIZE
               "Content-Length: " DELIMITED BY SIZE
               WS-LEN-STR DELIMITED BY SPACE
               WS-CRLF DELIMITED BY SIZE
               "Connection: close" DELIMITED BY SIZE
               WS-CRLF DELIMITED BY SIZE
               WS-CRLF DELIMITED BY SIZE
               INTO RESPONSE-BUFFER
           END-STRING
           MOVE 0 TO RESPONSE-LEN
           INSPECT RESPONSE-BUFFER TALLYING RESPONSE-LEN
               FOR CHARACTERS BEFORE INITIAL LOW-VALUE
           MOVE WS-STATIC-BODY(1:WS-STATIC-LEN)
               TO RESPONSE-BUFFER(RESPONSE-LEN + 1:
                   WS-STATIC-LEN)
           ADD WS-STATIC-LEN TO RESPONSE-LEN
           PERFORM SEND-BUFFER
           .

       SEND-RESPONSE.
           MOVE LOW-VALUE TO RESPONSE-BUFFER
           MOVE HTML-LEN TO WS-LEN-STR
           STRING
               "HTTP/1.1 200 OK" DELIMITED BY SIZE
               WS-CRLF DELIMITED BY SIZE
               "Content-Type: text/html; charset=utf-8"
                   DELIMITED BY SIZE
               WS-CRLF DELIMITED BY SIZE
               "Content-Length: " DELIMITED BY SIZE
               WS-LEN-STR DELIMITED BY SPACE
               WS-CRLF DELIMITED BY SIZE
               "Connection: close" DELIMITED BY SIZE
               WS-CRLF DELIMITED BY SIZE
               WS-CRLF DELIMITED BY SIZE
               INTO RESPONSE-BUFFER
           END-STRING
           MOVE 0 TO RESPONSE-LEN
           INSPECT RESPONSE-BUFFER TALLYING RESPONSE-LEN
               FOR CHARACTERS BEFORE INITIAL LOW-VALUE
           MOVE HTML-BODY(1:HTML-LEN)
               TO RESPONSE-BUFFER(RESPONSE-LEN + 1:HTML-LEN)
           ADD HTML-LEN TO RESPONSE-LEN
           PERFORM SEND-BUFFER
           .

      *> Shared send loop — sends RESPONSE-BUFFER(1:RESPONSE-LEN)
       SEND-BUFFER.
           MOVE 0 TO WS-SEND-OFFSET
           MOVE RESPONSE-LEN TO WS-SEND-REMAINING
           PERFORM UNTIL WS-SEND-REMAINING <= 0
               CALL "send" USING
                   BY VALUE CLIENT-SOCKET
                   BY REFERENCE
                       RESPONSE-BUFFER(WS-SEND-OFFSET + 1:
                           WS-SEND-REMAINING)
                   BY VALUE WS-SEND-REMAINING
                   BY VALUE 0
                   RETURNING BYTES-SENT
               END-CALL
               IF BYTES-SENT <= 0
                   EXIT PERFORM
               END-IF
               ADD BYTES-SENT TO WS-SEND-OFFSET
               SUBTRACT BYTES-SENT FROM WS-SEND-REMAINING
           END-PERFORM
           .
