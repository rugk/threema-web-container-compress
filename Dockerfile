# __________________
# GZipper
# __________________
FROM node:slim AS gzipper
# global dependencies
# https://github.com/nodejs/docker-node/blob/main/docs/BestPractices.md#global-npm-dependencies
ENV NPM_CONFIG_PREFIX=/home/node/.npm-global

# drop permissions to user level
# https://docs.docker.com/develop/develop-images/dockerfile_best-practices/#user
USER node

RUN npm install -g gzipper

# __________________
# Threema Web Build
# __________________
FROM alpine AS builder
WORKDIR /tmp/download

# Debian alternative:
RUN	apk add --no-cache \
  gnupg \
  ca-certificates \
  curl \
  wget \
  jq

# drop permissions the alpine-way
# (Using "guest" is not easily possible, because gpg needs homedir access later. That's why we use a custom user.)
# https://stackoverflow.com/a/49955098/5008962
RUN addgroup -S builder && adduser -S builder -G builder
RUN chown -R builder .
RUN mkdir /app&&chown -R builder /app
USER builder

# use tags/v1.0.0 to specify the version manually
ARG RELEASE_VERSION="latest"
# download latest source
# alternative: https://github.com/dsaltares/fetch-gh-release-asset/raw/master/fetch_github_asset.sh
ENV GITHUB_REPOSITORY=threema-ch/threema-web
RUN curl -sL https://api.github.com/repos/${GITHUB_REPOSITORY}/releases/${RELEASE_VERSION} | jq -r '.assets[] | select(.name | contains("threema-web")) | .browser_download_url' | wget -i -

# trust GPG key
COPY pubkeys/ /tmp/pubkeys
RUN gpg --import /tmp/pubkeys/*.asc
RUN echo "E7ADD9914E260E8B35DFB50665FDE935573ACDA6:6:"|gpg --import-ownertrust

# verify downloaded files
RUN gpg --verify *.tar.gz.asc *.tar.gz
RUN gpg --verify *.sha256.txt.asc *.sha256.txt
RUN sha256sum -c *.sha256.txt
RUN mkdir -p /tmp/threema \
    && tar -xzf *.tar.gz --strip-components 1 -C /tmp/threema
WORKDIR /app
RUN mv /tmp/threema/* /app

# __________________
# Compression optimisation
# __________________
FROM node:latest AS compressor
WORKDIR /app

RUN apt-get update && apt-get install -y \
    zstd \
    && rm -rf /var/lib/apt/lists/*

RUN chown -R node:node /app
USER node

# get app data
COPY --chown=node:node --from=builder /app /app

# compress zstd
# "threads=0" uses one thread per CPU core
RUN find /app -type f -exec zstd -z -f -19 --threads=0 {} +

# load gzipper
ENV NPM_CONFIG_PREFIX=/home/node/.npm-global
ENV PATH=$PATH:/home/node/.npm-global/bin
# global dependencies
# https://github.com/nodejs/docker-node/blob/main/docs/BestPractices.md#global-npm-dependencies
COPY --from=gzipper ${NPM_CONFIG_PREFIX} ${NPM_CONFIG_PREFIX}
# compress GZIP and Brotli
RUN gzipper compress --level 9 --remove-larger --exclude 'gz,br,zst' /app
RUN gzipper compress --level 9 --brotli --remove-larger --exclude 'gz,br,zst' /app

# debug output
RUN zstd -v \
    && node -v \
    && ls -la /app

# __________________
# Final
# __________________
FROM alpine AS final
VOLUME /output
COPY --chown=root:root --from=compressor /app /app
RUN rm -rf /output/*
RUN mv /app/* /output