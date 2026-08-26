# c4-ea-homeassistant

Home Assistant on Control4 EA-series controllers, built on top of
[openHC](https://github.com/The1TrueJoe/openHC)'s bare kernel + rootfs.

openHC gets a mainline kernel and an initramfs shell netbooting on EA1/EA3
hardware (Wi-Fi/Ethernet, SSH, no vendor firmware). This repo picks up from
there: persistent storage on the eMMC, a real root filesystem, and Home
Assistant actually running and reachable.

## Relationship to openHC

openHC is vendored as a git submodule at [`openHC/`](openHC), pinned to a
specific upstream commit so builds are reproducible. Pull upstream changes
with:

```sh
git submodule update --remote openHC
git add openHC && git commit -m "openHC: bump to upstream <sha>"
```

This repo builds on openHC's Buildroot `BR2_EXTERNAL` conventions
(`*_defconfig`, `rootfs-overlay/`, `post-image.sh`) and its EA1/EA3 board
output (kernel `bzImage` + CEFDK container wrapping).

## How the build is split

openHC's `board/` is one Buildroot `BR2_EXTERNAL` tree (`OPENHC`). This repo
is a second one (`OHCHA`), passed to Buildroot alongside it
(`BR2_EXTERNAL="openHC/board board"`). `build/build.sh` builds the effective
defconfig the same way openHC concatenates its own family + board files, just
with a third layer added on top:

```
openHC/board/ea-common/ea-common_defconfig   shared EA family base (upstream, untouched)
+ openHC/board/ea1/ea1_defconfig             EA1-only deltas (upstream, untouched)
+ board/ea1-ha/ea1-ha_defconfig              Home Assistant deltas (this repo)
```

Anything the bare kernel-up build doesn't need — starting with a target
Python — is added in `board/ea1-ha/ea1-ha_defconfig` here, not upstream.
openHC stays a generic Control4 kernel-up build with no Home Assistant
awareness; this repo is the only place that knows why the Python is there.

```sh
git submodule update --init openHC
make image        # Docker Buildroot build, see build/build.sh
```

## Status

- [x] Build layering (BR2_EXTERNAL stacked on openHC, `board/ea1-ha`) — python3
      added as the first delta, not yet verified with a full build
- [ ] Persistent root on eMMC for EA1 (openHC currently ships initramfs-only —
      the prerequisite for HA to keep any state across reboots; needs porting
      the eMMC ext4 approach openHC already proved on ca1)
- [ ] Home Assistant Core itself on-target — feasibility open: cross-compiled
      musl/i686 wheels for HA's dependency tree (aiohttp, cryptography,
      sqlalchemy, ...) are not a given; may need building from source under
      Buildroot's python3 package infra, or reconsidering the toolchain
- [ ] Bring-up docs specific to this repo (flashing, first boot, recovery)

## Layout

```
board/
  external.desc, Config.in, external.mk   this repo's BR2_EXTERNAL tree (name: OHCHA)
  ea1-ha/
    ea1-ha_defconfig                      HA deltas on top of openHC's ea-common + ea1
build/
  build.sh, Dockerfile                    same Docker/cache-mount model as openHC
```
