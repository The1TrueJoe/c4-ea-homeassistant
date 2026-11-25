# Buildroot build, done INSIDE `docker build` with BuildKit cache mounts.
# Same model as openHC/build/Dockerfile — see there for why (virtiofs I/O).
#
#   DOCKER_BUILDKIT=1 docker build -f build/Dockerfile \
#       --target artifacts --output type=local,dest=output/images .

FROM debian:bookworm-slim AS build-env

ARG BUILDROOT_REF=2024.02.9
ARG BR2_JLEVEL=
ARG BOARD=ea3-ha
# Which openHC board to layer onto. Empty = build.sh's default for $BOARD.
# The Home Assistant deltas are identical across EA variants, so the hardware
# base is a parameter rather than a duplicated board directory:
#     make image BOARD=ea3-ha OPENHC_BOARD=ea3-v1
ARG OPENHC_BOARD=

RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential bc bison flex git rsync unzip wget cpio file figlet \
        python3 libncurses-dev libssl-dev ca-certificates perl patch xz-utils \
    && rm -rf /var/lib/apt/lists/*

RUN git clone --depth 1 --branch "$BUILDROOT_REF" \
        https://github.com/buildroot/buildroot /opt/buildroot

# Patches to Buildroot ITSELF, mirroring openHC/build/Dockerfile. This step was
# missing here, so a C++ toolchain build would fail on gcc's libsanitizer
# (<linux/scc.h> was removed from the kernel) -- a failure deep in the toolchain
# with nothing pointing back at the cause.
COPY openHC/build/buildroot-patches /tmp/br-patches
RUN set -e; for p in /tmp/br-patches/*.patch; do \
        [ -e "$p" ] || continue; \
        echo ">> buildroot patch: ${p##*/}"; \
        patch -d /opt/buildroot -p1 --forward --batch < "$p" || \
            { echo "!! failed: ${p##*/}" >&2; exit 1; }; \
    done

RUN useradd -m builder && chown -R builder:builder /opt/buildroot
ENV BUILDROOT_DIR=/opt/buildroot
USER builder
WORKDIR /src
COPY --chown=builder:builder . /src

RUN --mount=type=cache,target=/src/dl,uid=1000,gid=1000 \
    --mount=type=cache,target=/src/output,uid=1000,gid=1000 \
    BR2_JLEVEL="$BR2_JLEVEL" BOARD="$BOARD" OPENHC_BOARD="$OPENHC_BOARD" bash ./build/build.sh \
    && rm -rf /tmp/artifacts && mkdir -p /tmp/artifacts \
    && cp -a "/src/output/build/$BOARD/images/." /tmp/artifacts/

FROM scratch AS artifacts
COPY --from=build-env /tmp/artifacts/ /
