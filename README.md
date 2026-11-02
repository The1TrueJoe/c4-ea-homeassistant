# c4-ea-homeassistant

Home Assistant on Control4 EA-series controllers: [openHC](https://github.com/The1TrueJoe/openHC)'s
EA images with one layer added on top.

## How it fits together

openHC owns everything about the hardware: the boards, their differences
(Wi-Fi, switch, PoE, DSP, secure-boot fuse), the kernel, the features and the
daemons. This repo produces the same EA images with a Home Assistant layer
appended, and nothing else.

- `openHC/` is a git submodule pinned to an openHC commit.
- `board/ha_defconfig` is the only build input this repo adds. openHC's own
  `build/build.sh` composes the board as usual (common, `ea/common`, features,
  board) and appends this layer last through its downstream hook
  (`OHC_EXTRA_DEFCONFIG`, with `board/` as a second `BR2_EXTERNAL` tree via
  `OHC_EXTRA_EXTERNAL`).
- `BOARD` is any openHC EA board (`openHC/board/ea/<board>`). The list comes
  from the submodule, so new openHC boards build here without changes here:

  ```sh
  make boards      # ea1-v1 ea1-v2 ea1-v2-poe ea3-v1 ea3-v2 today
  ```

Bump openHC:

```sh
git submodule update --remote openHC
git submodule update --init --recursive
git add openHC && git commit -m "openHC: bump to <sha>"
```

The Buildroot ref and patch set follow the submodule (read from
`openHC/build/Dockerfile` and `openHC/build/buildroot-patches/`).

## Building

CI builds every EA board on each push and PR (`.github/workflows/images.yml`)
and uploads one zip per board, `openhc-ha-<board>-<version>.zip`. That is the
same bundle layout as openHC's own images, so openHC's flasher installs it:

```sh
make -C openHC flash HOST=<ip> IMAGES=/path/to/openhc-ha-ea3-v2-....zip
```

Publishing a release attaches the zips to it. Locally:

```sh
git submodule update --init --recursive
make defconfig BOARD=ea3-v2   # print the composed defconfig, build nothing
make daemons   BOARD=ea3-v2   # stage openHC's daemons (rustup + node)
make image     BOARD=ea3-v2   # Docker Buildroot build
```

A full Buildroot build is heavy: prefer CI.

## What openHC already gives Home Assistant

- **x86_64 glibc userspace** on every EA. openHC moved off i386 for Home
  Assistant: orjson and cryptography publish no i686 wheels, and HA pins exact
  versions. On x86_64 HA's manylinux wheels install with pip.
- **Persistent ext4 root on the eMMC** (the `emmc` feature).
- **MQTT broker** (mosquitto) on the box. `iod` publishes relays and contacts
  with HA MQTT discovery: set `IOD_MQTT_DISCOVERY=homeassistant` in
  `/etc/openhc/iod.conf`.
- **Zigbee network radio for ZHA**: the EM357 is reflashed to EmberZNet 6.7.8
  (EZSP v8) at boot and served over TCP 6638, with `_zigbee-coordinator._tcp`
  advertised over mDNS.
- **Audio**: ALSA, Spotify Connect, AirPlay and HDMI audio on every EA. The
  EA3's analog out through its ADAU1451 DSP is still open in openHC. Its DSP
  program is built and sealed inside openHC's CI and never leaves it, so EA3
  images from this repo build without one.

## What this layer adds

- Python 3.14 with the stdlib modules HA uses (ssl, sqlite3, zlib/bz2/lzma/zstd,
  expat, decimal, unicodedata) and pip.

## Status

- [x] Builds on top of current openHC, every EA board, via openHC's downstream hook
- [ ] Home Assistant Core on the box: a venv on the eMMC, wheels from PyPI.
      Not yet installed or started by the image.
- [ ] Sendspin player (Music Assistant multi-room) against
      [`aiosendspin`](https://github.com/Sendspin-Protocol/sendspin), output
      through openHC's ALSA setup. Not started.

## Layout

```
board/
  ha_defconfig                            the Home Assistant layer
  external.desc, Config.in, external.mk   this repo's BR2_EXTERNAL tree (OHCHA)
build/
  build.sh      runs openHC/build/build.sh with the HA layer
  boards.sh     lists openHC's EA boards
  Dockerfile    Docker Buildroot build, Buildroot ref read from openHC
.github/workflows/images.yml   one image per EA board
```
