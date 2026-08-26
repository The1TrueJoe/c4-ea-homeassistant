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
