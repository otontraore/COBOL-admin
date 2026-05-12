      *> Authentication state
       01 WS-AUTH-SESSION-ID   PIC X(128).
       01 WS-AUTH-USER-NAME    PIC X(64).
       01 WS-AUTH-ROLE-NAME    PIC X(64).
       01 WS-AUTH-PERMISSIONS  PIC X(4096).
       01 WS-AUTH-STATUS       PIC S9(9) COMP-5 VALUE 0.
       01 WS-AUTH-OK           PIC 9 VALUE 0.
       01 WS-AUTH-ALLOWED      PIC 9 VALUE 0.
       01 WS-AUTH-ACTION       PIC X(16).
