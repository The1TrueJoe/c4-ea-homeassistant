# Buildroot build inside `docker build`, same model as openHC/build/Dockerfile.
# The Buildroot ref and patch set come from the openHC submodule, so a
# submodule bump is the only thing that moves them.
#
#   DOCKER_BUILDKIT=1 docker build -f build/Dockerfile --build-arg BOARD=ea3-v2 \
#       --target artifacts --output type=local,dest=output/images .

FROM rust:1-slim-bookworm AS flasher
WORKDIR /f
COPY openHC/flasher/ /f/
RUN cargo build --release -p ohc-flash-cli


FROM debian:bookworm-slim AS build-env

RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential bc bison flex git rsync unzip wget cpio file figlet \
        python3 libncurses-dev libssl-dev libelf-dev pkg-config ca-certificates perl patch xz-utils \
    && rm -rf /var/lib/apt/lists/*

COPY openHC/build/Dockerfile /tmp/openhc.Dockerfile
COPY openHC/build/buildroot-patches /tmp/br-patches
RUN set -e; ref=$(sed -n 's/^ARG BUILDROOT_REF=//p' /tmp/openhc.Dockerfile); \
    [ -n "$ref" ]; echo ">> buildroot $ref"; \
    git init -q /opt/buildroot; \
    git -C /opt/buildroot fetch -q --depth 1 https://github.com/buildroot/buildroot "$ref"; \
    git -C /opt/buildroot checkout -q FETCH_HEAD; \
    for p in /tmp/br-patches/*.patch; do \
        [ -e "$p" ] || continue; \
        echo ">> buildroot patch: ${p##*/}"; \
        patch -d /opt/buildroot -p1 --forward --batch < "$p"; \
    done

COPY --from=flasher /f/target/release/ohc-flash /usr/local/bin/ohc-flash

RUN useradd -m builder && chown -R builder:builder /opt/buildroot
ENV BUILDROOT_DIR=/opt/buildroot
USER builder
WORKDIR /src
COPY --chown=builder:builder . /src

ARG BR2_JLEVEL=
ARG BOARD=ea3-v2

RUN --mount=type=cache,target=/src/dl,uid=1000,gid=1000,sharing=locked \
    --mount=type=cache,target=/src/output,uid=1000,gid=1000,sharing=locked \
    BR2_JLEVEL="$BR2_JLEVEL" BOARD="$BOARD" bash ./build/build.sh \
    && rm -rf /tmp/artifacts && mkdir -p /tmp/artifacts \
    && cp -a "/src/output/build/$BOARD/images/." /tmp/artifacts/

FROM scratch AS artifacts
COPY --from=build-env /tmp/artifacts/ /
