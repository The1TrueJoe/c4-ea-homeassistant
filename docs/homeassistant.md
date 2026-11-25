# Home Assistant on the EA3 — plan and constraints

Status 2026-08-30: **not running yet, and one hard blocker stands in front of
everything else.** The board itself is no longer the problem; memory is.

## What changed

The old note in this repo said EA3 was unproven — no netboot, `e1000` failing
with `-EIO`. That is stale. Measured on hardware:

* openHC installs over SSH with **no serial and no ID button**, boots
  unattended from eMMC, and pivots to a persistent ext4 root on `mmcblk0p1`.
* ~5.6 GB free on the rootfs, networking up, SSH in.
* Audio has a full driver stack written upstream (CE5300 I2S + ADAU1451), plus
  AirPlay and Spotify Connect receivers.

So the runway is clear except for RAM.

## Blocker: 186 MB of a 2 GB board

```
BIOS-e820: [mem 0x00100000-0x0c7fffff]  System RAM       ←  200 MB
BIOS-e820: [mem 0x0c800000-0x7fffffff]  device reserved  ← 1.8 GB, idle
MemTotal: 190640 kB
```

CEFDK reserves 1.8 GB for the Intel CE media stack (decode buffers, demux,
display planes). openHC never loads that stack, and `/proc/iomem` shows nothing
claiming a single byte of the range — it is idle DRAM that the firmware simply
declines to offer.

**Home Assistant Core does not fit in 186 MB.** Reclaiming is therefore step
zero, not an optimisation.

The fix is written and deliberately disabled upstream in
`openHC/board/ea3-v2/linux/ea3-v2.fragment`:

```
CONFIG_CMDLINE="... memmap=1024M@0x10000000"
```

It belongs upstream (generic memory bring-up, nothing HA-specific) and needs
care:

* Enable **with a serial console attached**. A `memmap=` over a range that is
  actually live does not fail loudly — it corrupts and panics.
* Widen in stages: 256M, then 1024M, then out toward `0x78000000`.
* **Never reach the framebuffer at `0x7fc00000`.** `simplefb` scans it out and
  nothing else can: the SGX545 is a renderer, not a display engine, and the
  display controllers at `01:08.x` have no driver at all. `ce5300-fb` refuses to
  probe if its buffer became System RAM, so overshooting costs the display.

Stopping below `0x78000000` still yields ~1.6 GB, which is ample.

## Why HA cannot simply be pip-installed

Its dependency tree is ~100 packages. Most are pure Python, but several carry
native extensions, and the target has **no compiler** and PyPI ships **no i686
wheels** for them. `cryptography` alone needs a Rust toolchain.

The split that resolves this:

| | where it comes from | why |
|---|---|---|
| `cryptography`, `aiohttp`, `pyyaml` | Buildroot, cross-compiled | native extensions; impossible on-target |
| `jinja2`, `certifi`, `attrs` | Buildroot | already packaged, no reason not to |
| the pure-Python remainder | `pip` into a venv on `/data` at first boot | keeps the rootfs small, and HA can be upgraded without a reflash |

`board/ea3-ha/ea3-ha_defconfig` already selects the Buildroot half.

## Storage

`/data` is `mmcblk0p2`, mounted by `S50data`, holding the HA config, the
recorder database and the venv. Deliberately **not** the rootfs:

* the recorder writes constantly and should not share a filesystem with the OS;
* an openHC reflash or a factory restore rewrites p1 and leaves p2 alone, so
  the house configuration survives a firmware update.

`S50data` formats p2 only when there is **no recognisable filesystem** — never
blindly, because a transient mount failure that triggers a reformat would
silently destroy the configuration.

## Order of work

1. **Reclaim RAM upstream in openHC** (serial attached, staged). Verify with
   `MemTotal` and something memory-heavy at each step. Nothing below is worth
   attempting first.
2. Build `ea3-ha` and confirm the Python base imports on-target: `ssl`,
   `sqlite3`, `zlib`, `cryptography`, `aiohttp`, `yaml`.
3. First-boot installer: create the venv on `/data`, `pip install
   homeassistant` with `--no-build-isolation` and the Buildroot-provided
   packages visible via `--system-site-packages`, so pip does not try to
   rebuild them.
4. `S95homeassistant` init script, bound to `/data/config`.
5. Only then: the Sendspin player, against `aiosendspin` rather than the heavy
   `sendspin-cli` app (which drags in PyAV/numpy/Pillow/PulseAudio/textual —
   wrong shape for this box).

## Open questions

* **Does HA Core actually fit in ~1.2 GB with the recorder running?** Unmeasured
  on this board. If it does not, the fallback is a trimmed integration set.
* **Which HA version pins cleanly** against Buildroot 2024.02's `cryptography`
  and `aiohttp` versions. A mismatch here is the most likely source of a long
  dependency fight, and it is worth checking *before* the venv step.
* Whether the recorder should use SQLite on eMMC at all, given write wear.
