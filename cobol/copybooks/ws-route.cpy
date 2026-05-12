      *> Routing state
       01 WS-ROUTE-TYPE        PIC X(10).
          88 ROUTE-HOME        VALUE "HOME".
          88 ROUTE-LIST        VALUE "LIST".
          88 ROUTE-SHOW        VALUE "SHOW".
          88 ROUTE-EDIT        VALUE "EDIT".
          88 ROUTE-CREATE      VALUE "CREATE".
          88 ROUTE-DELETE      VALUE "DELETE".
          88 ROUTE-STATIC      VALUE "STATIC".
          88 ROUTE-LOGIN       VALUE "LOGIN".
          88 ROUTE-LOGOUT      VALUE "LOGOUT".
          88 ROUTE-NOT-FOUND   VALUE "NOTFOUND".
       01 WS-ROUTE-RESOURCE    PIC X(64).
       01 WS-ROUTE-ID          PIC X(10).
       01 WS-STATIC-PATH       PIC X(512).

      *> Pagination
       01 WS-PAGE              PIC 999 VALUE 1.
       01 WS-PER-PAGE          PIC 999 VALUE 10.
       01 WS-TOTAL-COUNT       PIC 99999 VALUE 0.
