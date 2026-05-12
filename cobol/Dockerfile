FROM ubuntu:24.04

RUN apt-get update && \
    apt-get install -y gnucobol4 libcurl4-openssl-dev && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Download gcblunit test framework and cJSON
ADD https://raw.githubusercontent.com/OlegKunitsyn/gcblunit/master/gcblunit.cbl gcblunit.cbl
ADD https://raw.githubusercontent.com/DaveGamble/cJSON/master/cJSON.c cJSON.c
ADD https://raw.githubusercontent.com/DaveGamble/cJSON/master/cJSON.h cJSON.h

COPY . .

# Compile C helpers
RUN gcc -c -fPIC -o helpers.o helpers.c -I.
RUN gcc -c -fPIC -o cJSON.o cJSON.c

# Compile modules as object files
RUN cobc -free -c -I copybooks template-engine.cbl
RUN cobc -free -c -I copybooks schema-loader.cbl
RUN cobc -free -c -I copybooks http-parse.cbl
RUN cobc -free -c -I copybooks router.cbl
RUN cobc -free -c -I copybooks page-layout.cbl
RUN cobc -free -c -I copybooks page-login.cbl
RUN cobc -free -c -I copybooks page-home.cbl
RUN cobc -free -c -I copybooks page-list.cbl
RUN cobc -free -c -I copybooks page-404.cbl
RUN cobc -free -c -I copybooks pagination.cbl
RUN cobc -free -c -I copybooks page-show.cbl
RUN cobc -free -c -I copybooks page-edit.cbl
RUN cobc -free -c -I copybooks form-submit.cbl
RUN cobc -free -c -I copybooks serve-static.cbl
RUN cobc -free -c -I copybooks html-escape.cbl
RUN cobc -free -c -I copybooks shell-sanitize.cbl
RUN cobc -free -c -I copybooks fetch-item.cbl
RUN cobc -free -c -I copybooks ref-detect.cbl
RUN cobc -free -c -I copybooks page-create.cbl
RUN cobc -free -c -I copybooks form-create.cbl
RUN cobc -free -c -I copybooks page-delete.cbl

# Compile and link main with all modules
RUN cobc -free -x -I copybooks -o cobol-admin \
    main.cbl \
    template-engine.o \
    schema-loader.o \
    http-parse.o \
    router.o \
    page-layout.o \
    page-login.o \
    page-home.o \
    page-list.o \
    page-404.o \
    pagination.o \
    page-show.o \
    page-edit.o \
    form-submit.o \
    serve-static.o \
    html-escape.o \
    shell-sanitize.o \
    fetch-item.o \
    ref-detect.o \
    page-create.o \
    form-create.o \
    page-delete.o \
    helpers.o \
    cJSON.o \
    -lcurl

# Run tests at build time
RUN sed -i 's/\r$//' run-tests.sh && chmod +x run-tests.sh && ./run-tests.sh

EXPOSE 8080
CMD ["./cobol-admin"]
