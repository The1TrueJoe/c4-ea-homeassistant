# c4-ea-homeassistant

Home Assistant on Control4 EA-series controllers, built on top of
[openHC](https://github.com/The1TrueJoe/openHC)'s bare kernel + rootfs.

openHC gets a mainline kernel and an initramfs shell netbooting on EA1
hardware (proven) and building-but-unproven on EA3 (Wi-Fi/Ethernet, SSH, no
vendor firmware). This repo picks up from there: persistent storage on the
eMMC, a real root filesystem, and Home Assistant actually running and
reachable.

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
+ openHC/board/<ea1|ea3>/..._defconfig       board deltas (upstream, untouched)
+ board/<BOARD>/..._defconfig                Home Assistant deltas (this repo)
```

Anything the bare kernel-up build doesn't need — starting with a target
Python — is added in `board/<BOARD>/<BOARD>_defconfig` here, not upstream.
openHC stays a generic Control4 kernel-up build with no Home Assistant
awareness; this repo is the only place that knows why the Python is there.
`BOARD` selects `ea1-ha` or `ea3-ha` (default `ea3-ha` — see below).

```sh
git submodule update --init openHC
make image [BOARD=ea3-ha|ea1-ha]   # Docker Buildroot build, see build/build.sh
```

## Board: EA3

**EA3 is the hardware actually on the bench**, so it's the default `BOARD`.
Read [openHC's `docs/ea3-recon.md`](openHC/docs/ea3-recon.md) before assuming
anything works — as of the openHC commit this repo is pinned to, EA3 is
**unproven**: no EA3 has been netbooted, and the NIC (`e1000`) probes with a
bare `-EIO` and no `eth0` on the mainline kernel. That's an openHC-side bug,
not a Home Assistant one — it blocks everything downstream (there's no
network to even reach the box) and needs solving there first.

## Audio: ALSA vs. Sendspin

The EA3 (and EA5) route audio through an Analog Devices ADAU1451 SigmaDSP —
recon is solid (`openHC/docs/ea3-recon.md#audio`), but nothing has been
ported to mainline yet. Split the same way as everything else:

- **Getting sound out of the box at all (ALSA/kernel/DSP firmware loading)
  is generic hardware bring-up and belongs in openHC**, not here — same as
  the NIC and storage work. See the "Mainline bring-up: what's missing"
  note in that doc for the two candidate approaches (a real ASoC codec
  driver, or a userspace SigmaDSP loader bypassing ASoC).
- **[Sendspin](https://github.com/Sendspin/spec)** (the multi-room sync
  protocol Music Assistant/Home Assistant speaks to player endpoints) is
  the HA-specific consumer of that ALSA device, so it lives here.
  [`aiosendspin`](https://github.com/Sendspin-Protocol/sendspin) (the
  protocol library, not the full `sendspin-cli` app) is the right building
  block — the CLI app bundles PyAV, numpy, Pillow, PulseAudio and a
  textual UI that make no sense on this box; a minimal player against
  `aiosendspin` + direct ALSA output is the plan once there's an actual
  ALSA device to target. Not started — blocked on the ALSA work above.

## Status

- [x] Build layering (BR2_EXTERNAL stacked on openHC), `ea1-ha` and `ea3-ha`
      boards — python3 added as the first delta, full-build verification
      in progress
- [ ] EA3 NIC (`e1000` probes `-EIO`, no netboot proven yet) — openHC-side,
      blocks reaching the board over anything but serial
- [ ] Persistent root on eMMC for EA1/EA3 (openHC currently ships
      initramfs-only — needs porting the eMMC ext4 approach openHC already
      proved on ca1)
- [ ] ALSA audio path for the ADAU1451 (openHC-side — see above)
- [ ] Sendspin player against `aiosendspin` (this repo — blocked on ALSA)
- [ ] Home Assistant Core itself on-target — feasibility open: cross-compiled
      musl/i686 wheels for HA's dependency tree (aiohttp, cryptography,
      sqlalchemy, ...) are not a given; may need building from source under
      Buildroot's python3 package infra, or reconsidering the toolchain

## Layout

```
board/
  external.desc, Config.in, external.mk   this repo's BR2_EXTERNAL tree (name: OHCHA)
  ea1-ha/ea1-ha_defconfig                 HA deltas on top of openHC's ea-common + ea1
  ea3-ha/ea3-ha_defconfig                 HA deltas on top of openHC's ea-common + ea3
build/
  build.sh, Dockerfile                    same Docker/cache-mount model as openHC
```
