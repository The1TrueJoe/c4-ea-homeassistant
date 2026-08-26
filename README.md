# c4-ea-homeassistant

Home Assistant on Control4 EA-series controllers, built on top of
[openHC](https://github.com/The1TrueJoe/openHC)'s bare kernel + rootfs.

openHC gets a mainline kernel and an initramfs shell netbooting on EA1/EA3
hardware (Wi-Fi/Ethernet, SSH, no vendor firmware). This repo picks up from
there: persistent storage on the eMMC, a real root filesystem, and Home
Assistant actually running and reachable.

## Relationship to openHC

This repo does not vendor or fork openHC. It consumes its outputs:

- the built kernel (`bzImage`) + CEFDK container wrapping from
  `board/ea1` / `board/ea3` in openHC
- the Buildroot `BR2_EXTERNAL` conventions (`*_defconfig`, `rootfs-overlay/`,
  `post-image.sh`) that openHC's board ports already use

Point `OPENHC_DIR` at a local openHC checkout to build against it.

## Status

Not started. Planning stage — see [openHC's README](https://github.com/The1TrueJoe/openHC#board-support)
for what's already proven (EA1 netboots to a shell) vs. still open (storage,
EA3 second NIC).

## Plan

- [ ] Persistent root on eMMC for EA1 (openHC currently ships initramfs-only —
      storage is called out there as "comes later")
- [ ] Buildroot overlay / package for Home Assistant Core (or point at
      HA's own arm/x86 container path — TBD, needs a size/RAM budget check
      against the EA1's hardware first)
- [ ] Bring-up docs specific to this repo (flashing, first boot, recovery)

## Layout (placeholder)

```
overlay/     rootfs additions on top of openHC's board output (HA install, systemd units)
docs/        bring-up notes specific to this repo
```
