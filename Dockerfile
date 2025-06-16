FROM timescale/timescaledb:latest-pg17

RUN apk update && \
    apk add --no-cache make perl patch && \
    mkdir -p /tmp/pgtap && \
    cd /tmp/pgtap && \
    wget https://api.pgxn.org/dist/pgtap/1.3.3/pgtap-1.3.3.zip && \
    unzip pgtap-1.3.3.zip && \
    cd pgtap-1.3.3 && \
    make && \
    make install && \
    rm -rf /tmp/pgtap
