       >>SOURCE FORMAT FREE
*> Tests for ROUTER module
identification division.
program-id. test-router.

data division.
working-storage section.
01 ws-request-path      pic x(512).
01 ws-path-len          pic 9(4) comp-5.
01 ws-route-type        pic x(10).
01 ws-route-resource    pic x(64).
01 ws-page             pic 999.
01 ws-per-page         pic 999.
01 ws-expected-page    pic 999.
01 ws-expected-per-page pic 999.
01 ws-route-id         pic x(10).
01 ws-static-path      pic x(512).
01 ws-resource-table.
   05 ws-resource-count pic 99 value 3.
   05 ws-resources occurs 20 times.
      10 ws-res-name    pic x(64).
      10 ws-res-field-count pic 99.
      10 ws-res-fields occurs 20 times.
         15 ws-res-field-name pic x(64).
         15 ws-res-field-type pic x(16).
         15 ws-res-field-edit pic 9.

procedure division.

    *> Set up test resource table
    initialize ws-resource-table
    move 3 to ws-resource-count
    move "authors" to ws-res-name(1)
    move 0 to ws-res-field-count(1)
    move "posts" to ws-res-name(2)
    move 0 to ws-res-field-count(2)
    move "tags" to ws-res-name(3)
    move 0 to ws-res-field-count(3)

    perform test-home-route.
    perform test-list-valid.
    perform test-list-invalid.
    perform test-list-query-params.
    perform test-list-invalid-query-params.
    perform test-unknown-path.
    perform test-list-second-resource.
    perform test-show-route.
    perform test-show-invalid.
    perform test-create-route.
    perform test-create-invalid.
    perform test-delete-route.
    perform test-delete-invalid.
    perform test-login-route.
    perform test-logout-route.
    goback.

test-home-route section.
    move spaces to ws-request-path
    move "/" to ws-request-path
    move 1 to ws-path-len
    call "ROUTER" using
        ws-request-path ws-path-len
        ws-route-type ws-route-resource
        ws-resource-table
        ws-page ws-per-page
        ws-route-id ws-static-path
    end-call
    call "assert-equals" using "HOME", ws-route-type(1:4).

test-list-valid section.
    move spaces to ws-request-path
    move "/list/authors" to ws-request-path
    move 13 to ws-path-len
    call "ROUTER" using
        ws-request-path ws-path-len
        ws-route-type ws-route-resource
        ws-resource-table
        ws-page ws-per-page
        ws-route-id ws-static-path
    end-call
    call "assert-equals" using "LIST", ws-route-type(1:4).
    call "assert-equals" using "authors", ws-route-resource(1:7).

test-list-invalid section.
    move spaces to ws-request-path
    move "/list/bogus" to ws-request-path
    move 11 to ws-path-len
    call "ROUTER" using
        ws-request-path ws-path-len
        ws-route-type ws-route-resource
        ws-resource-table
        ws-page ws-per-page
        ws-route-id ws-static-path
    end-call
    call "assert-equals" using "NOTFOUND", ws-route-type(1:8).

test-list-query-params section.
    move spaces to ws-request-path
    move "/list/authors?page=2&perPage=25" to ws-request-path
    move 31 to ws-path-len
    call "ROUTER" using
        ws-request-path ws-path-len
        ws-route-type ws-route-resource
        ws-resource-table
        ws-page ws-per-page
        ws-route-id ws-static-path
    end-call
    call "assert-equals" using "LIST", ws-route-type(1:4).
    call "assert-equals" using "authors", ws-route-resource(1:7).
    move 2 to ws-expected-page
    call "assert-equals" using ws-expected-page, ws-page.
    move 25 to ws-expected-per-page
    call "assert-equals" using ws-expected-per-page, ws-per-page.

test-list-invalid-query-params section.
    move spaces to ws-request-path
    move "/list/authors?page=abc&perPage=x" to ws-request-path
    move 32 to ws-path-len
    call "ROUTER" using
        ws-request-path ws-path-len
        ws-route-type ws-route-resource
        ws-resource-table
        ws-page ws-per-page
        ws-route-id ws-static-path
    end-call
    call "assert-equals" using "LIST", ws-route-type(1:4).
    call "assert-equals" using "authors", ws-route-resource(1:7).
    move 1 to ws-expected-page
    call "assert-equals" using ws-expected-page, ws-page.
    move 10 to ws-expected-per-page
    call "assert-equals" using ws-expected-per-page, ws-per-page.

test-unknown-path section.
    move spaces to ws-request-path
    move "/something" to ws-request-path
    move 10 to ws-path-len
    call "ROUTER" using
        ws-request-path ws-path-len
        ws-route-type ws-route-resource
        ws-resource-table
        ws-page ws-per-page
        ws-route-id ws-static-path
    end-call
    call "assert-equals" using "NOTFOUND", ws-route-type(1:8).

test-list-second-resource section.
    move spaces to ws-request-path
    move "/list/posts" to ws-request-path
    move 11 to ws-path-len
    call "ROUTER" using
        ws-request-path ws-path-len
        ws-route-type ws-route-resource
        ws-resource-table
        ws-page ws-per-page
        ws-route-id ws-static-path
    end-call
    call "assert-equals" using "LIST", ws-route-type(1:4).
    call "assert-equals" using "posts", ws-route-resource(1:5).

test-show-route section.
    move spaces to ws-request-path
    move "/show/authors/42" to ws-request-path
    move 16 to ws-path-len
    call "ROUTER" using
        ws-request-path ws-path-len
        ws-route-type ws-route-resource
        ws-resource-table
        ws-page ws-per-page
        ws-route-id ws-static-path
    end-call
    call "assert-equals" using "SHOW", ws-route-type(1:4).
    call "assert-equals" using "authors", ws-route-resource(1:7).
    call "assert-equals" using "42", ws-route-id(1:2).

test-show-invalid section.
    move spaces to ws-request-path
    move "/show/bogus/1" to ws-request-path
    move 13 to ws-path-len
    call "ROUTER" using
        ws-request-path ws-path-len
        ws-route-type ws-route-resource
        ws-resource-table
        ws-page ws-per-page
        ws-route-id ws-static-path
    end-call
    call "assert-equals" using "NOTFOUND", ws-route-type(1:8).

test-create-route section.
    move spaces to ws-request-path
    move "/create/authors" to ws-request-path
    move 15 to ws-path-len
    call "ROUTER" using
        ws-request-path ws-path-len
        ws-route-type ws-route-resource
        ws-resource-table
        ws-page ws-per-page
        ws-route-id ws-static-path
    end-call
    call "assert-equals" using "CREATE", ws-route-type(1:6).
    call "assert-equals" using "authors", ws-route-resource(1:7).

test-create-invalid section.
    move spaces to ws-request-path
    move "/create/bogus" to ws-request-path
    move 13 to ws-path-len
    call "ROUTER" using
        ws-request-path ws-path-len
        ws-route-type ws-route-resource
        ws-resource-table
        ws-page ws-per-page
        ws-route-id ws-static-path
    end-call
    call "assert-equals" using "NOTFOUND", ws-route-type(1:8).

test-delete-route section.
    move spaces to ws-request-path
    move "/delete/posts/7" to ws-request-path
    move 15 to ws-path-len
    call "ROUTER" using
        ws-request-path ws-path-len
        ws-route-type ws-route-resource
        ws-resource-table
        ws-page ws-per-page
        ws-route-id ws-static-path
    end-call
    call "assert-equals" using "DELETE", ws-route-type(1:6).
    call "assert-equals" using "posts", ws-route-resource(1:5).
    call "assert-equals" using "7", ws-route-id(1:1).

test-delete-invalid section.
    move spaces to ws-request-path
    move "/delete/bogus/1" to ws-request-path
    move 15 to ws-path-len
    call "ROUTER" using
        ws-request-path ws-path-len
        ws-route-type ws-route-resource
        ws-resource-table
        ws-page ws-per-page
        ws-route-id ws-static-path
    end-call
    call "assert-equals" using "NOTFOUND", ws-route-type(1:8).

test-login-route section.
    move spaces to ws-request-path
    move "/login" to ws-request-path
    move 6 to ws-path-len
    call "ROUTER" using
        ws-request-path ws-path-len
        ws-route-type ws-route-resource
        ws-resource-table
        ws-page ws-per-page
        ws-route-id ws-static-path
    end-call
    call "assert-equals" using "LOGIN", ws-route-type(1:5).

test-logout-route section.
    move spaces to ws-request-path
    move "/logout" to ws-request-path
    move 7 to ws-path-len
    call "ROUTER" using
        ws-request-path ws-path-len
        ws-route-type ws-route-resource
        ws-resource-table
        ws-page ws-per-page
        ws-route-id ws-static-path
    end-call
    call "assert-equals" using "LOGOUT", ws-route-type(1:6).

end program test-router.
