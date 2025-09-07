# Multi-stage Dockerfile for Project Skyfire 5.4.8 on Ubuntu 24.04
# Targets:
#  - builder: compiles SkyFire_548 with TOOLS=1 and installs to /usr/local/skyfire-server
#  - runtime-base: minimal runtime deps and skyfire install
#  - world: worldserver image with entrypoint
#  - auth: authserver image with entrypoint
#  - extractor: tool image to extract maps/vmaps/dbc
#  - dbtool: utility image to init/update database

# ------------------
# Builder stage
# ------------------
FROM ubuntu:24.04 AS builder

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    g++ make cmake git wget \
    gcc-14 g++-14 \
    libssl-dev libreadline-dev bzip2 libbz2-dev \
    mysql-client default-libmysqlclient-dev libmysqlclient-dev libmysql++-dev \
    # deps helpful for building ACE
    perl \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Build directory
WORKDIR /tmp

# Clone SkyFire following official documentation
RUN git clone -b main https://github.com/ProjectSkyfire/SkyFire_548.git

# Install ACE 8.0.1 from source
RUN wget https://github.com/DOCGroup/ACE_TAO/releases/download/ACE%2BTAO-8_0_1/ACE-8.0.1.tar.gz \
    && tar -xzf ACE-8.0.1.tar.gz \
    && cd ACE_wrappers \
    && export ACE_ROOT=$(pwd) \
    && export INSTALL_PREFIX=/usr/local \
    && echo '#include "ace/config-linux.h"' > ace/config.h \
    && echo 'include $(ACE_ROOT)/include/makeinclude/platform_linux.GNU' > include/makeinclude/platform_macros.GNU \
    && make -j"$(nproc)" \
    && make install INSTALL_PREFIX=/usr/local \
    && cd .. \
    && rm -rf ACE_wrappers ACE-8.0.1.tar.gz

# Install OpenSSL 3.5.2 from source (version shown in logs)
RUN wget https://www.openssl.org/source/openssl-3.5.2.tar.gz \
    && tar -xzf openssl-3.5.2.tar.gz \
    && cd openssl-3.5.2 \
    && ./Configure --prefix=/usr/local --openssldir=/usr/local/ssl \
    && make -j"$(nproc)" \
    && make install \
    && cd .. \
    && rm -rf openssl-3.5.2 openssl-3.5.2.tar.gz \
    && ldconfig

RUN apt-get update && apt-get install -y \
    libmysqlclient-dev \
    libmysqlclient21 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /tmp/SkyFire_548
ENV CC=gcc-14 CXX=g++-14

RUN mkdir build && cd build
WORKDIR /tmp/SkyFire_548/build
RUN cmake ../ -DTOOLS=1 -DCMAKE_INSTALL_PREFIX=/usr/local/skyfire-server \
    && make -j"$(nproc)" \
    && make install

# ------------------
# Runtime base stage
# ------------------
FROM ubuntu:24.04 AS runtime-base
ENV DEBIAN_FRONTEND=noninteractive

# Copy ACE and OpenSSL libraries from builder
COPY --from=builder /usr/local/lib/libACE* /usr/local/lib/
COPY --from=builder /usr/local/lib/libssl* /usr/local/lib/
COPY --from=builder /usr/local/lib/libcrypto* /usr/local/lib/

# Runtime libraries only (match builder libs)
RUN apt-get update && apt-get install -y \
    libreadline8 bzip2 libbz2-1.0 \
    default-mysql-client \
    libmysqlclient21 \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/* \
    && ldconfig

# Copy installed skyfire from builder (now using proper skyfire-server paths)
COPY --from=builder /usr/local/skyfire-server /usr/local/skyfire-server
# Use system libs (already installed in runtime-base)
RUN ldconfig || true

# Common env and directories (using official skyfire paths)
ENV SKYFIRE_HOME=/usr/local/skyfire-server \
    SKYFIRE_ETC=/usr/local/skyfire-server/etc \
    SKYFIRE_BIN=/usr/local/skyfire-server/bin \
    DATA_DIR=/data

RUN mkdir -p "$DATA_DIR" "$SKYFIRE_ETC" "$SKYFIRE_BIN"

# Add scripts
COPY scripts/ /opt/skyfire/scripts/
RUN chmod +x /opt/skyfire/scripts/*.sh || true

# ------------------
# worldserver image
# ------------------
FROM runtime-base AS world

ENV SERVICE_TYPE=world

ENTRYPOINT ["/opt/skyfire/scripts/entrypoint-world.sh"]
CMD ["/usr/local/skyfire-server/bin/worldserver"]

# ------------------
# authserver image
# ------------------
FROM runtime-base AS auth

ENV SERVICE_TYPE=auth

ENTRYPOINT ["/opt/skyfire/scripts/entrypoint-auth.sh"]
CMD ["/usr/local/skyfire-server/bin/authserver"]

# ------------------
# extractor image (tools only)
## (extractor-related stages removed; user provides extracted data in ./data)

# ------------------
# dbtool base: no SkyFire binaries required, only SQL + mysql client
# ------------------
FROM ubuntu:24.04 AS dbbase
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y default-mysql-client ca-certificates && rm -rf /var/lib/apt/lists/*
WORKDIR /
# Copy SQL sources from builder stage
COPY --from=builder /tmp/SkyFire_548/sql /opt/skyfire/sql
# Copy scripts
COPY scripts/ /opt/skyfire/scripts/
RUN chmod +x /opt/skyfire/scripts/*.sh || true

FROM dbbase AS dbtool
ENTRYPOINT ["/opt/skyfire/scripts/init-db.sh"]
