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

Home Assistant Core, as the `ha-core` package (`board/package/ha-core`):

- Python 3.14 with the stdlib modules HA uses (ssl, sqlite3, zlib/bz2/lzma/zstd,
  expat, decimal, unicodedata), pip and the CA bundle.
- `S97homeassistant`. On the first boot it runs `/opt/ha/bin/ha-install`, which
  installs `homeassistant==<version>` into a venv at `/data/ha/venv` from
  PyPI, then starts `hass` on **:8123** with its config in `/data/ha/config`.
  A crash restarts it; HA's own restart from the UI happens in place.
- The HA version is `BR2_PACKAGE_HA_CORE_HA_VERSION` (2026.10.4). Changing it
  upgrades the venv on the next boot.

The install happens on the box, not in the image. HA's tree is several hundred
MB, and the EA rootfs is also a RAM initramfs. Checked off-box for 2026.10.4 on
Python 3.14.10 / glibc 2.44: all 100 pinned dependencies have x86_64 manylinux
wheels, except PyRIC, a pure-Python sdist that needs no compiler. The first
boot needs internet and a correct clock (openHC's ntpd); progress goes to
`/data/ha/install.log`, and HA's own output goes to syslog as `homeassistant`.

Caveats:

- `/data` is on the eMMC root (p1). **Reflashing p1 wipes the HA config**, so
  take a backup from HA first.
- The CE5310 is a Bonnell Atom: x86-64 without SSE4.x or POPCNT. A wheel built
  for x86-64-v2 or newer dies with SIGILL. Core's wheels are not known to be
  built that way, but an integration's dependency could be.

## Status

- [x] Builds on top of current openHC, every EA board, via openHC's downstream hook
- [x] Home Assistant Core installs on first boot and runs as a service
      (not yet run on hardware)
- [ ] Sendspin player (Music Assistant multi-room) against
      [`aiosendspin`](https://github.com/Sendspin-Protocol/sendspin), output
      through openHC's ALSA setup. Not started.

## Layout

```
board/
  ha_defconfig                            the Home Assistant layer
  package/ha-core/                        Python deps, installer, init script
  external.desc, Config.in, external.mk   this repo's BR2_EXTERNAL tree (OHCHA)
build/
  build.sh      runs openHC/build/build.sh with the HA layer
  boards.sh     lists openHC's EA boards
  Dockerfile    Docker Buildroot build, Buildroot ref read from openHC
.github/workflows/images.yml   one image per EA board
```
