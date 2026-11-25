#!/usr/bin/env bash
# Build the Home Assistant image for an openHC EA board: openHC's own bundle
# with its rootfs.ext2 replaced by a Debian trixie root.
#
#   debian/build.sh <openhc-bundle.zip|dir> <out.zip>
#
# Runs as root on Debian (in CI and `make image`: a privileged debian:trixie
# container). From openHC's bundle it keeps, unchanged: the kernel, the
# bootstrap and boot-init (the flasher writes those to the eMMC slots), and
# from its rootfs /opt/ohc (the daemons, static), /lib/modules, /lib/firmware,
# /boot (the full kernel S00kexec hands off to) and /etc (no-clobber: openHC's
# init scripts and config, where Debian has nothing of the same name). A newer
# openHC therefore lands here by bumping the submodule; only a new compiled
# userspace program in openHC needs its Debian package added to `packages`.
set -euo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
REPO=$(dirname "$HERE")
BUNDLE=$1
OUT=$(realpath -m "$2")
SUITE=${SUITE:-trixie}
MIRROR=${MIRROR:-http://deb.debian.org/debian}
W=$(mktemp -d /tmp/ohc-debian.XXXXXX)
R=$W/rootfs
trap 'umount -R "$R/proc" "$R/sys" "$R/dev" 2>/dev/null || true' EXIT

echo ">> openHC bundle: $BUNDLE"
mkdir -p "$W/in"
if [ -d "$BUNDLE" ]; then cp -a "$BUNDLE/." "$W/in/"; else unzip -q "$BUNDLE" -d "$W/in"; fi
IN=$(dirname "$(find "$W/in" -name 'rootfs.ext2*' | head -1)")
[ -f "$IN/rootfs.ext2" ] || gunzip "$IN/rootfs.ext2.gz"
for f in bzImage boot-init.cpio.gz rootfs.ext2; do
    [ -f "$IN/$f" ] || { echo "not an openHC EA bundle: no $f" >&2; exit 1; }
done

echo ">> what the image takes from openHC's rootfs"
O=$W/openhc
for d in opt/ohc lib/modules lib/firmware boot etc usr/share/udhcpc usr/bin usr/sbin bin sbin; do
    mkdir -p "$O/$(dirname "$d")"
    debugfs -R "rdump /$d $O/$(dirname "$d")" "$IN/rootfs.ext2" 2>/dev/null || true
done
[ -x "$O/opt/ohc/bin/iod" ] || { echo "openHC rootfs has no /opt/ohc/bin/iod" >&2; exit 1; }
cat "$O/etc/openhc-release"

echo ">> Debian $SUITE"
pkgs=$(grep -v '^#' "$HERE/packages" | tr -s ' \n' ',' | sed 's/^,//; s/,$//')
mmdebstrap --variant=minbase --include="$pkgs" \
    --aptopt='APT::Install-Recommends "false"' \
    --dpkgopt='path-exclude=/usr/share/doc/*' --dpkgopt='path-include=/usr/share/doc/*/copyright' \
    --dpkgopt='path-exclude=/usr/share/man/*' --dpkgopt='path-exclude=/usr/share/locale/*' \
    "$SUITE" "$R" "$MIRROR"

echo ">> openHC into it"
cp -a "$O/opt/." "$R/opt/"
cp -a "$O/lib/modules" "$O/lib/firmware" "$R/usr/lib/"
cp -a "$O/boot/." "$R/boot/"
[ -d "$O/usr/share/udhcpc" ] && cp -a "$O/usr/share/udhcpc" "$R/usr/share/"
# Debian's busybox udhcpc runs /etc/udhcpc/default.script (Buildroot's:
# /usr/share/udhcpc/): without it a lease "succeeds" and sets no address.
mkdir -p "$R/etc/udhcpc"
ln -sf /usr/share/udhcpc/default.script "$R/etc/udhcpc/default.script"
# openHC's own shell tools (ohc-udev-name for the udev rules, ...): every script
# in its bin dirs that Debian has no file of. Its ELF binaries are Buildroot
# glibc builds and can't run here; their Debian packages are in `packages`.
for d in usr/bin usr/sbin bin sbin; do
    [ -d "$O/$d" ] || continue
    for f in "$O/$d"/*; do
        [ -f "$f" ] && [ ! -L "$f" ] && [ "$(head -c2 "$f")" = '#!' ] || continue
        t="$R/$d/${f##*/}"
        [ -e "$t" ] || [ -L "$t" ] || { cp -a "$f" "$t"; echo "   openHC script: /$d/${f##*/}"; }
    done
done
# No-clobber: Debian's files win where both exist (passwd, os-release, ...);
# everything only openHC has (init.d/S*, asound.conf, openhc/, udev rules,
# openhc-release, mosquitto and avahi config) comes across.
cp -an "$O/etc/." "$R/etc/"
# ...except these, which openHC must own.
for f in asound.conf mosquitto/mosquitto.conf openhc-release; do
    [ -e "$O/etc/$f" ] && cp -a "$O/etc/$f" "$R/etc/$f"
done
# Buildroot's inittab/fstab mean nothing to systemd; this is the root.
rm -f "$R/etc/inittab"
printf '/dev/mmcblk0p1 / ext4 rw,noatime 0 1\n' > "$R/etc/fstab"
printf 'variant=debian-%s homeassistant\n' "$SUITE" >> "$R/etc/openhc-release"

echo ">> this repo's layer"
cp -a "$HERE/overlay/." "$R/"

echo ">> uv, and HA's Python (baseline x86-64: the EA's Atom has no SSE4)"
UV_VERSION=${UV_VERSION:-0.13.10}
curl -fsSL "https://github.com/astral-sh/uv/releases/download/$UV_VERSION/uv-x86_64-unknown-linux-musl.tar.gz" \
    | tar xz -C "$R/usr/local/bin" --strip-components=1
# Name the plain x86_64 build: on a newer CPU uv would pick an x86_64_v3 one.
UV_PYTHON_INSTALL_DIR="$R/opt/python-dist" "$R/usr/local/bin/uv" python install \
    "cpython-${PYTHON_VERSION:-3.14}-linux-x86_64-gnu"
py=$(cd "$R/opt/python-dist" && ls -d cpython-*-linux-x86_64-gnu | grep -E '^cpython-[0-9]+\.[0-9]+\.[0-9]+' | sort -V | tail -1)
ln -sfn "python-dist/$py" "$R/opt/python"

echo ">> AirPlay 2 sources"
SPS_VERSION=${SPS_VERSION:-5.6.3} NQPTP_VERSION=${NQPTP_VERSION:-1.2.9}
mkdir -p "$R/tmp/src"
curl -fsSL "https://github.com/mikebrady/shairport-sync/archive/refs/tags/$SPS_VERSION.tar.gz" | tar xz -C "$R/tmp/src"
curl -fsSL "https://github.com/mikebrady/nqptp/archive/refs/tags/$NQPTP_VERSION.tar.gz" | tar xz -C "$R/tmp/src"

# openHC's librespot (Spotify Connect endpoints) is a dynamic glibc binary from
# Buildroot: keep it only if Debian's glibc has every symbol version it needs.
if [ -f "$O/usr/bin/librespot" ]; then
    cp "$O/usr/bin/librespot" "$R/tmp/librespot"
    need=$(chroot "$R" objdump -T /tmp/librespot | grep -o 'GLIBC_[0-9.]*' | sort -Vu | tail -1)
    have=$(chroot "$R" getconf GNU_LIBC_VERSION | cut -d" " -f2)
    if [ "$(printf '%s\n%s\n' "${need#GLIBC_}" "$have" | sort -V | tail -1)" = "$have" ]; then
        mv "$R/tmp/librespot" "$R/usr/bin/librespot"; echo "   librespot kept ($need <= glibc $have)"
    else
        rm "$R/tmp/librespot"
        echo "   librespot left out (needs $need, Debian has glibc $have): Spotify Connect endpoints won't start"
    fi
fi

echo ">> configure in the root"
mount -t proc proc "$R/proc"; mount -t sysfs sys "$R/sys"; mount --bind /dev "$R/dev"
cp "$REPO/openHC/packages/alsa-ohceq/ohceq.c" "$R/tmp/"
chroot "$R" /bin/sh -eux <<'CHROOT'
# openHC's ALSA tone plugin (asound.conf's coax/HDMI chains), against Debian's alsa-lib
mkdir -p /usr/lib/x86_64-linux-gnu/alsa-lib
gcc -O2 -shared -fPIC -DPIC -Wall -o /usr/lib/x86_64-linux-gnu/alsa-lib/libasound_module_pcm_ohceq.so /tmp/ohceq.c -lasound -lm
rm /tmp/ohceq.c
# AirPlay 2 for openHC's AirPlay endpoints, configured as openHC's Buildroot does
cd /tmp/src/nqptp-*
autoreconf -fi >/dev/null && ./configure -q --prefix=/usr && make -s -j"$(nproc)" && make -s install
cd /tmp/src/shairport-sync-*
autoreconf -fi >/dev/null
./configure -q --prefix=/usr --sysconfdir=/etc --with-alsa --with-metadata --with-pipe --with-stdout \
    --with-avahi --with-libdaemon --with-ssl=openssl --with-airplay-2 --with-ffmpeg \
    --with-dbus-interface --with-mpris-interface --with-soxr
make -s -j"$(nproc)" && make -s install
cd / && rm -rf /tmp/src
shairport-sync -V
# busybox applets openHC's scripts use that Debian lacks (udhcpc, logread, devmem...)
mkdir -p /usr/lib/openhc/busybox
busybox --install -s /usr/lib/openhc/busybox
# PID 1: S00kexec first, then systemd (usr/sbin/init.openhc)
dpkg-divert --local --rename --divert /usr/sbin/init.systemd --add /usr/sbin/init
ln -sf init.openhc /usr/sbin/init
# openHC's scripts start these themselves
systemctl mask mosquitto.service avahi-daemon.service avahi-daemon.socket dnsmasq.service \
    hostapd.service squeezelite.service ksmbd.service wpa_supplicant.service
systemctl enable openhc.service ssh.service systemd-timesyncd.service
echo root:openhc | chpasswd
echo openhc > /etc/hostname
rm -f /etc/resolv.conf && touch /etc/resolv.conf
# kexec-tools must not take over reboots
rm -f /etc/default/kexec
apt-get clean; rm -rf /var/lib/apt/lists/* /var/cache/* /var/log/*.log
CHROOT
umount -R "$R/proc" "$R/sys" "$R/dev"

echo ">> rootfs.ext2"
mb=$(( $(du -sm "$R" | cut -f1) * 5 / 4 + 256 ))
# openHC's other p1 roots are Buildroot's: drop them so nothing installs one
# instead of this (rootfs.ext2.gz is the flasher's self-install, staged in a
# 16 MiB gap this root can't fit). rootfs.cpio.gz stays: the RAM netboot.
rm -f "$IN"/rootfs.ext2 "$IN"/rootfs.ext2.gz "$IN"/rootfs.ext4 "$IN"/rootfs.cpio "$IN"/rootfs.tar
mke2fs -q -t ext4 -L openhc -d "$R" "$IN/rootfs.ext2" "${mb}M"
echo "   ${mb} MB (the box grows it to the whole partition on first boot)"

echo ">> $OUT"
mkdir -p "$(dirname "$OUT")"
rm -f "$OUT"
(cd "$IN" && zip -q -r "$OUT" .)
ls -la "$OUT"
