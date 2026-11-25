# c4-ea-homeassistant

Home Assistant and Music Assistant on Control4 EA-series controllers (EA-1,
EA-3, EA-5), on top of [openHC](https://github.com/The1TrueJoe/openHC).

**Installing:** [docs/install.md](docs/install.md). It covers both ways to run
an EA: this image (openHC + Home Assistant), or plain openHC for a Control4
system.

## What the image is

openHC's own image bundle for the board, with its Buildroot root filesystem
replaced by Debian trixie:

- **From openHC, unchanged:** the kernel, the bootstrap kernel and boot-init
  (what the flasher writes to the eMMC slots), the full kernel in `/boot` that
  the bootstrap kexecs into, `/lib/modules`, `/lib/firmware`, the daemons in
  `/opt/ohc` (iod, audiod, sysmond, webd, the Zigbee/Z-Wave/Bluetooth bridges,
  all static binaries), and `/etc` where Debian has nothing of the same name:
  openHC's init scripts, `asound.conf`, udev rules, MQTT and mDNS config.
- **From Debian:** the base system, plus the programs openHC's scripts start
  (mosquitto, avahi, hostapd, ...) and what Home Assistant needs, including a
  compiler for the few requirements PyPI has no wheel of.
- **Built in the image, as openHC builds them:** shairport-sync 5.6.3 with
  AirPlay 2 and nqptp 1.2.9 (Debian's shairport-sync is classic AirPlay only),
  so openHC's AirPlay endpoints are AirPlay 2 here too; and openHC's ALSA tone
  plugin against Debian's alsa-lib.
- **This repo:** [`debian/`](debian): the package list, the build, and an
  overlay with Home Assistant (`S97homeassistant`), Music Assistant and its
  squeezelite players (`S98music-assistant`), and the MQTT discovery for the
  box's IR, serial and Zigbee joining (`ohc-ha-discovery`).

openHC's boot scripts run as they do on Buildroot, in order, from one systemd
unit (`openhc.service` → `/usr/lib/openhc/rc`), minus the ones for the base
system that Debian provides. `S00kexec`, the handoff from the bootstrap kernel
to the full one, runs before systemd (`/usr/sbin/init.openhc`), and so does a
first-boot guard: no network address within five minutes of the first boot
puts the box back in openHC's SSH installer instead of leaving it dark. The
journal is persistent, so that boot can be read from p1 afterwards.

**Keeping up with openHC** is a submodule bump: kernel, driver, firmware,
daemon and config changes all come from openHC's bundle for the pinned
commit. This repo only changes when openHC starts a new compiled program
(its Debian package goes in [`debian/packages`](debian/packages)) or adds a
base-system script that systemd replaces (it joins the skip list in
[`debian/overlay/usr/lib/openhc/rc`](debian/overlay/usr/lib/openhc/rc)).

Home Assistant and Music Assistant install on the box on first boot, into
venvs on `/data`, with the image's own Python (the plain x86-64 build: the
EA's Atom has no SSE4.2). Versions: `/etc/ha-core.conf`,
`/etc/music-assistant.conf`; bumping one upgrades on the next start.

## Building

```sh
git submodule update --init
make image BOARD=ea3-v1          # fetches openHC's bundle for the submodule's commit (gh)
make image BOARD=ea3-v1 OPENHC_BUNDLE=path/to/openhc-ea3-v1-….zip
make boards                      # ea1-v1 ea1-v2 ea1-v2-poe ea3-v1 ea3-v2 ea5-v1 ea5-v2
```

`make image` runs [`debian/build.sh`](debian/build.sh) in a privileged
`debian:trixie` container (mmdebstrap) and writes
`output/openhc-ha-<board>.zip`, which the flasher installs like openHC's own.
CI ([`images.yml`](.github/workflows/images.yml)) builds every EA board on
each push and attaches the zips to a release. It needs openHC's CI to have
built images for the pinned commit.

Bump openHC:

```sh
git -C openHC fetch && git -C openHC checkout <commit>
git add openHC && git commit -m "openHC: bump to <sha>"
```

## Status

- [x] The Debian image on an EA-3 (installed over SSH, no serial): systemd,
      openHC's services and IO, eth0 up; HA and MA installed on first boot.
- [x] openHC IO in Home Assistant over MQTT discovery: relays and contacts
      from iod; IR, serial and Zigbee joining from `ohc-ha-discovery`.
      Relay switched from HA on the EA-3 (iod reported it on and off).
- [x] Zigbee through openHC's zigbee-bridge (MQTT discovery); network formed
      on the EA-3's EM357, permit join in HA. A paired device: not yet.
- [x] Music Assistant with a squeezelite player per output; played to the
      EA-3's analog output from Home Assistant (the analog PCM running).
- [x] openHC's AirPlay 2 endpoints (shairport-sync and nqptp built in the
      image), one per output, advertised as AirPlay 2.
- [x] The Debian image boots in QEMU on openHC's full kernel.
- [ ] Bluetooth LE: openHC's kernel support for the EA-3's onboard Bluetooth,
      and its Bluetooth bridge's discovery.
