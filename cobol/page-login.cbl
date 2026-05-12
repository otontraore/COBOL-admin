      *> Builds the login page
       IDENTIFICATION DIVISION.
       PROGRAM-ID. PAGE-LOGIN.

       DATA DIVISION.
       LINKAGE SECTION.
       01 LS-HTML-BODY         PIC X(32768).
       01 LS-HTML-LEN          PIC 9(8) COMP-5.
       01 LS-HAS-ERROR         PIC 9.

       PROCEDURE DIVISION USING
           LS-HTML-BODY LS-HTML-LEN LS-HAS-ERROR.

       MAIN-LOGIC.
           STRING
               "<div class='show-header'><div><h1>Login</h1>"
                   DELIMITED BY SIZE
               "</div></div>" DELIMITED BY SIZE
               INTO LS-HTML-BODY WITH POINTER LS-HTML-LEN
           END-STRING

           IF LS-HAS-ERROR = 1
               STRING
                   "<p class='error'>Invalid username or password.</p>"
                       DELIMITED BY SIZE
                   INTO LS-HTML-BODY WITH POINTER LS-HTML-LEN
               END-STRING
           END-IF

           STRING
               "<form method='POST' action='/login' class='edit-form'>"
                   DELIMITED BY SIZE
               "<div class='form-field'>" DELIMITED BY SIZE
               "<label for='username'>Username</label>"
                   DELIMITED BY SIZE
               "<input type='text' name='username' id='username'"
                   DELIMITED BY SIZE
               " autocomplete='username'></div>" DELIMITED BY SIZE
               "<div class='form-field'>" DELIMITED BY SIZE
               "<label for='password'>Password</label>"
                   DELIMITED BY SIZE
               "<input type='password' name='password' id='password'"
                   DELIMITED BY SIZE
               " autocomplete='current-password'></div>"
                   DELIMITED BY SIZE
               "<div class='form-actions'>" DELIMITED BY SIZE
               "<button type='submit' class='btn'>Login</button>"
                   DELIMITED BY SIZE
               "</div></form>" DELIMITED BY SIZE
               INTO LS-HTML-BODY WITH POINTER LS-HTML-LEN
           END-STRING

           GOBACK.
