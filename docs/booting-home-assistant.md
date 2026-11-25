# Booting Home Assistant on an EA-3

Written 2026-08-31, from a unit that is actually serving. Everything here was
measured on hardware; where something is unverified it says so.

## What runs today

Home Assistant Core **2024.3.3** on an EA-3 v2, `http://<box>:8123`, ~450 MB
resident of 1.7 GB, load ~0.01 idle, zero ERROR lines in its log.

```
kernel   x86_64 7.1.8, RAM-booted over TFTP
memory   MemTotal 1,783,348 kB   (memmap=exactmap reclaim)
rootfs   x86_64 Buildroot, unpacked to /newroot on p1, entered with chroot
python   3.11.10
data     /data  -> a directory on p1   (NOT p2 -- see the warning below)
```

## ⚠ mmcblk0p2 is the factory recovery partition. Never touch it.

`LABEL=recfs`. It holds `recfs.tar.xz` (489 MB, the factory root filesystem),
`recovery_kernel.deb`, `cefdk.deb` and the manifests. That image cannot be
downloaded again and cannot be redistributed — destroying it permanently
removes the route back to stock firmware.

`S50data` originally mounted p2 at `/data` and ran `mke2fs` on it whenever
`blkid` found no filesystem. It did not fire only because the filesystem
happened to be intact. It has been rewritten to use a directory on p1 and to
refuse outright if p2 is ever mounted at `/data`.

A verified backup is at `~/ea3-factory-backup/ea3-p2-recfs.tar` (496 MB, 12
members). It is deliberately outside any git repo — it is Control4 code.

## The three constraints that shape everything

### 1. The kernel must fit 7,417,856 bytes

CEFDK's `bootlinux` copies the kernel into a fixed window, `0x813000-0x100000`.
This is CEFDK's own code: it cannot be rewritten, and an oversized kernel is
silently **truncated** — the box does not complain, it just fails to boot.

| build | size | headroom |
|---|---|---|
| x86_64, features=`emmc` | 7,169,024 | 248,832 (3.4%) |
| + NIC/ISO trims | 7,037,952 | 379,904 (5.1%) |

The config is already lean — no netfilter, IPv6, Bluetooth, SCSI/ATA, DRM,
sound, ftrace or debug info. **A 64-bit kernel on this board simply costs ~7 MB
against a 7.4 MB wall.** So:

> New functionality goes in as a **module** (`=m`), never built in (`=y`).

`CONFIG_MODULES` is on and, as of writing, exactly one symbol is `=m` against
1370 that are `=y`. The `switch`, `audio` and `sgx` feature fragments are all
written as `=y`; re-enabling them as they stand will overrun the window.

Escape hatch if a large kernel ever becomes unavoidable: chain a small
bootstrap kernel that `kexec`s the real one from p1. Considered, not built.

### 2. Python 3.11 caps Home Assistant at 2024.3.3

Buildroot 2024.02.9 ships Python **3.11.10**. Home Assistant requires
`>=3.12.0` from **2024.4.0** onward (checked against PyPI `requires_python`).
2024.3.3 is the last release that runs here.

Raising it means a newer Python, i.e. bumping `BUILDROOT_REF` — 2025.02 ships
3.13 — which is a toolchain-wide change with every kernel patch to re-validate.

The symptom of setting `HA_VERSION` too high is deliberately confusing: pip
says "requires a different Python" and the boot log looks like a network fault.

### 3. The board is x86_64 because of `orjson`

PyPI publishes no i686 wheel for `orjson` at any version, and it is a hard
Home Assistant dependency. On x86_64 every native dependency it has —
`orjson`, `cryptography`, `aiohttp`, `ciso8601` — has a manylinux wheel, so
nothing needs compiling on a box with no compiler.

## Things that will bite, and what they look like

Each of these cost real time; the symptom never names the cause.

**pip backtracks forever.** An unconstrained `pip install
homeassistant==2024.3.3` walks backwards through every `habluetooth` release
and starts pulling `bluetooth-data-tools` *sdists*, which need a compiler. It
ran ten minutes without converging. Fixed by shipping HA's own
`package_constraints.txt` (157 pins) in the image at
`/opt/ha/package_constraints.txt` and applying it from the **first** pip call.
HA ships that file inside its wheel, which is useless as a fix — you cannot
read it until after the install you are trying to constrain.

**`josepy` breaks startup and is in no constraints file.** It is a transitive
of `acme`, pulled in by `hass-nabucasa`, so HA never pins it. josepy 2.0
removed `ComparableX509`, which acme 2.8.0 still references at import:

```
AttributeError: module 'josepy' has no attribute 'ComparableX509'
```

Pinned by hand to `josepy<2`.

**No timezone database.** Buildroot ships no `/usr/share/zoneinfo` and Python's
`zoneinfo` has no fallback, so `ZoneInfo("America/New_York")` raises
`ZoneInfoNotFoundError` and HA cannot resolve a single timestamp. `tzdata` is
installed from PyPI.

**No CA bundle.** OpenSSL here wants a bundle file at `/etc/ssl/cert.pem` —
`openssl_cafile`, not the `certs/` directory, which would need hashed symlinks.
Without it every pip download fails `CERTIFICATE_VERIFY_FAILED`.

**No RTC.** The box boots at 2000-01-01, and every TLS handshake then fails
"certificate is not yet valid". Set the clock before anything touches the
network.

**`netifaces` cannot be built on the target.** HA pip-installs integration
requirements *at runtime*, and PyPI has no cp311 wheel for netifaces, so
`aiodiscover` fails and the `dhcp` integration never sets up:

```
ERROR: Failed building wheel for netifaces
Setup failed for 'dhcp': Requirements for dhcp not found: ['aiodiscover==1.6.1']
```

Fixed by cross-compiling it (`BR2_PACKAGE_PYTHON_NETIFACES=y`) and having
`ha-setup` copy it into the venv — the venv is deliberately clean, so it is not
visible otherwise. After that: 0 dhcp failures, 0 ERROR lines.

## Getting a fresh unit up

### On a box already running openHC, with SSH

The kernel and initrd can be replaced in place with `dd` to `/dev/mmcblk0`
**only while the new images fit the autoscript's existing read sizes** —
recorded in `/opt/ohc/autoscript.env`, currently `KSZ=5642240 RSZ=5370368`.
An x86_64 kernel is larger than that, so this path does not work until the
autoscript is rewritten to read whole slots, which needs `/dev/mtd0`.

`CONFIG_MTD` + `CONFIG_MTD_SPI_NOR` are now in `common.fragment` for exactly
this. Note the ordering trap: `MTD_SPI_NOR` is dropped **silently** unless SPI
is on first, and `SPI_PXA2XX_PCI` is a derived symbol needing `COMMON_CLK`.
`COMMON_CLK` used to break `i2c-pxa`; the enumeration patch now registers a
fixed-rate clock per adapter, so it is safe.

### On a stock Control4 box — no button, no serial

Proven 2026-08-27. Stock firmware has `flash_erase`/`flashcp`, so the
whole-slot autoscript can be written directly from it. Stock SSH is
`root` with the factory password and needs legacy crypto:

```
-o KexAlgorithms=+diffie-hellman-group14-sha1 -o HostKeyAlgorithms=+ssh-rsa
```

Disable `sysmand` first — it crash-loops on low RAM and breaks large SSH
streams. The eMMC addressing delta is constant: **CEFDK address = Linux address
+ 0x800000**.

### RAM-boot over TFTP — needs the ID button

Reversible; a power cycle undoes it. Requires manufacturing mode:

1. Unplug power.
2. Press and **hold** the recessed ID button.
3. Plug power back in, still holding.
4. Keep holding until the console says `Manufacturing Mode: Enabled` (~10 s).

Then the tool answers the BOOTP request with the Control4 cookie, TFTPs the
kernel and initramfs, sets the CEFDK globals and runs `bootlinux`.

Three things that make this fail and look like something else:

* **`Manufacturing Mode: Disabled`** — the button was not registered. Hold it
  *before* applying power.
* **`AC_BOOT`** after manufacturing mode — the DHCP cookie was refused. Option
  60 must be NUL-padded; an END byte straight after it makes CEFDK read
  `C4_COOKIE\xff`.
* **a bare `shell>` is not a shell** — it is the stored autoscript echoing its
  own commands. Only trust the prompt after
  `Entering Control4 Manufacturing Mode`.

The flasher now walks through this with a sticky "ACTION NEEDED" banner and
live console feedback (`crates/engine/src/mfgmode.rs`, with tests for each of
the three cases above).

Do **not** type commands into CEFDK while a transfer is running — it drops
them. Wait for the TFTP server's own completion report, not the serial text.
That mistake left `G_KBASE` unset and `bootlinux` jumped at a stale address.

### Memory layout for a RAM boot

```
kernel staged   0x6000000    (bootlinux copies it to 0x100000)
initrd          0x8000000    128 MB -- clear of the kernel, and inside the
                             RAM CEFDK itself declares (tops out at 0xc7fffff)
```

Do not put the initrd at `0x4000000` as the old autoscript did: a 26 MB
initramfs there runs to 0x9000000 and overwrites the kernel.

### Partition map

```
mmcblk0p1   6.0 GB   LABEL=openhc   root, and /data
mmcblk0p2   1.0 GB   LABEL=recfs    FACTORY RECOVERY -- DO NOT TOUCH
mmcblk0p3    32 MB   LABEL=logs
```

p1 starts at **32 MiB**. The installer stages the compressed rootfs at raw
offset 16 MiB, so `rootfs.ext2.gz` must fit a **16 MiB gap** or it writes
through the start of p1. `install_self` now refuses rather than corrupting it.

## EA-3 v1 differences

The v1 has **Wi-Fi**, which the v2 does not. `S41wifi-ap` brings up an AP with
a captive portal when no wired interface is on the network.

That decision used to be a carrier test on `eth0` alone, which is wrong twice
on a board with the BCM53125 switch: the DSA master reads carrier 1 whether or
not a cable is in either jack, and the real jacks are `lan1`/`lan2`, which only
exist once the switch attaches. It now checks every non-loopback, non-radio
interface and requires an actual IPv4 address, not just carrier.

## Reproducing the build

```bash
make image BOARD=ea3-ha
```

Artifacts land in `output/images/`. The installer needs `bzImage`,
`boot-init.cpio.gz` and `rootfs.ext2.gz`; the netboot wrap is optional and no
longer fails the build if `ohc-flash` is missing.

Buildroot's output lives in a BuildKit cache mount, so a rebuild resumes rather
than redoing the toolchain — **but that cache is on the Docker VM disk, and
filling the host disk corrupts it.** That happened here: `Docker.raw` reached
104 GB, the host hit 0 bytes, and the daemon started failing with
`input/output error` on its own blobs.
