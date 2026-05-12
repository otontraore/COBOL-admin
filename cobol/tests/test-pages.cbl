       >>SOURCE FORMAT FREE
*> Tests for page builder modules
identification division.
program-id. test-pages.

data division.
working-storage section.
01 ws-html-body         pic x(32768).
01 ws-html-len          pic 9(8) comp-5.
01 ws-resource-name     pic x(64).
01 ws-resource-table.
   05 ws-resource-count pic 99 value 2.
   05 ws-resources occurs 20 times.
      10 ws-res-name    pic x(64).
      10 ws-res-field-count pic 99.
      10 ws-res-fields occurs 20 times.
         15 ws-res-field-name pic x(64).
         15 ws-res-field-type pic x(16).
         15 ws-res-field-edit pic 9.
01 ws-content-buf       pic x(16384).
01 ws-content-len       pic 9(8) comp-5.
01 ws-auth-user-name    pic x(64).
01 ws-auth-permissions  pic x(4096).

procedure division.

    initialize ws-resource-table
    move 2 to ws-resource-count
    move "authors" to ws-res-name(1)
    move 0 to ws-res-field-count(1)
    move "posts" to ws-res-name(2)
    move 0 to ws-res-field-count(2)

    perform test-page-home.
    perform test-page-404.
    perform test-layout.
    goback.

test-page-home section.
    move low-value to ws-html-body
    move 1 to ws-html-len
    call "PAGE-HOME" using ws-html-body ws-html-len
    end-call
    *> Check that output contains expected text
    call "assert-equals" using "<h1>Hello, COBOL Admin!</h1>",
        ws-html-body(1:28).

test-page-404 section.
    move low-value to ws-html-body
    move 1 to ws-html-len
    call "PAGE-404" using ws-html-body ws-html-len
    end-call
    call "assert-equals" using "<h1>404 - Not Found</h1>",
        ws-html-body(1:24).

test-layout section.
    *> Render with sample page content
    move low-value to ws-content-buf
    move "<p>test</p>" to ws-content-buf
    move 11 to ws-content-len
    move low-value to ws-html-body
    move 1 to ws-html-len
    move "Admin" to ws-auth-user-name
    move "admin.access" to ws-auth-permissions
    call "PAGE-LAYOUT" using
        ws-html-body ws-html-len
        ws-resource-table
        ws-content-buf ws-content-len
        ws-auth-user-name ws-auth-permissions
    end-call
    *> Should start with DOCTYPE
    call "assert-equals" using "<!DOCTYPE html>",
        ws-html-body(1:15).

end program test-pages.
