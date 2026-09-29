#!/bin/bash
# Builds the FiveOS installer ISO by remastering the official Debian netinst ISO:
#   - preseed.cfg + FiveOS installer scripts are appended to the installer initrds
#   - the FiveOS system files are added to the ISO under /fiveos/rootfs
#   - boot records are replayed unchanged, so BIOS and UEFI boot keep working
#
# Runs on Debian/Ubuntu (also WSL2). Requirements:
#   sudo apt install xorriso cpio wget
#
# Environment:
#   DEBIAN_CD   directory with the netinst ISO + SHA256SUMS
#               (default: current Debian stable, amd64)
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
VERSION=$(tr -d '[:space:]' < "$ROOT/VERSION")
CACHE="$ROOT/build/cache"
WORK="$ROOT/build/work"
OUT="$ROOT/out"
DEBIAN_CD="${DEBIAN_CD:-https://cdimage.debian.org/debian-cd/current/amd64/iso-cd}"

log() { printf '\e[1;32m==>\e[0m %s\n' "$*"; }
fail() {
	printf '\e[1;31mERROR:\e[0m %s\n' "$*" >&2
	exit 1
}

for tool in xorriso cpio gzip wget sha256sum md5sum; do
	command -v "$tool" > /dev/null || fail "'$tool' is missing. Install: sudo apt install xorriso cpio wget"
done

mkdir -p "$CACHE" "$OUT"
rm -rf "$WORK"
mkdir -p "$WORK"

# --- 1. Debian netinst ISO ---------------------------------------------------
log "Looking up the current Debian netinst ISO"
wget -q -O "$CACHE/SHA256SUMS" "$DEBIAN_CD/SHA256SUMS"
ISO_NAME=$(grep -oE 'debian-[0-9.]+-amd64-netinst\.iso' "$CACHE/SHA256SUMS" | head -n 1)
[ -n "$ISO_NAME" ] || fail "No netinst ISO found in $DEBIAN_CD/SHA256SUMS"
ISO="$CACHE/$ISO_NAME"

if [ ! -f "$ISO" ]; then
	log "Downloading $ISO_NAME"
	wget -q --show-progress -O "$ISO.part" "$DEBIAN_CD/$ISO_NAME"
	mv "$ISO.part" "$ISO"
fi
log "Verifying $ISO_NAME"
(cd "$CACHE" && grep "  $ISO_NAME\$" SHA256SUMS | sha256sum -c --quiet -) || {
	rm -f "$ISO"
	fail "Checksum mismatch, the download was removed. Run the build again."
}

# --- 2. Installer additions (go into the initrd) -----------------------------
log "Preparing installer files"
mkdir -p "$WORK/initrd-extra/fiveos"
cp "$ROOT/installer/preseed.cfg" "$WORK/initrd-extra/preseed.cfg"
cp "$ROOT/installer/early.sh" "$ROOT/installer/late.sh" "$ROOT/installer/fiveos.templates" \
	"$WORK/initrd-extra/fiveos/"

# --- 3. System files (go onto the ISO) ----------------------------------------
cp -R "$ROOT/rootfs" "$WORK/rootfs"

# a checkout on Windows may have CRLF line endings, which break shell scripts
# (grep -I skips binary files such as the logo images)
{ grep -rIl $'\r' "$WORK/initrd-extra" "$WORK/rootfs" || true; } | while IFS= read -r f; do
	sed -i 's/\r$//' "$f"
done

(cd "$WORK/initrd-extra" && find . -mindepth 1 | sed 's|^\./||' | cpio --quiet -o -H newc -R 0:0 | gzip -9) \
	> "$WORK/initrd-extra.cpio.gz"

# --- 4. Patch the initrds -----------------------------------------------------
# The kernel unpacks concatenated cpio archives in order, so appending ours
# adds /preseed.cfg and /fiveos to the installer's root file system.
MAP_ARGS=()
xorriso -osirrox on -indev "$ISO" -extract /md5sum.txt "$WORK/md5sum.txt" 2> /dev/null
chmod u+w "$WORK/md5sum.txt"

for initrd in /install.amd/initrd.gz /install.amd/gtk/initrd.gz; do
	local_file="$WORK/$(echo "${initrd#/}" | tr / _)"
	if ! xorriso -osirrox on -indev "$ISO" -extract "$initrd" "$local_file" 2> /dev/null; then
		log "Skipping $initrd (not on this ISO)"
		continue
	fi
	chmod u+w "$local_file"
	cat "$WORK/initrd-extra.cpio.gz" >> "$local_file"
	sum=$(md5sum "$local_file" | cut -d' ' -f1)
	sed -i "s|^[0-9a-f]*  \.$initrd\$|$sum  .$initrd|" "$WORK/md5sum.txt"
	MAP_ARGS+=(-map "$local_file" "$initrd")
	log "Patched $initrd"
done
[ ${#MAP_ARGS[@]} -gt 0 ] || fail "No installer initrd found on the ISO."

# --- 5. Write the new ISO ------------------------------------------------------
OUT_ISO="$OUT/fiveos-$VERSION-amd64.iso"
rm -f "$OUT_ISO"
log "Writing $(basename "$OUT_ISO")"
xorriso -indev "$ISO" -outdev "$OUT_ISO" \
	"${MAP_ARGS[@]}" \
	-map "$WORK/rootfs" /fiveos/rootfs \
	-map "$ROOT/VERSION" /fiveos/VERSION \
	-map "$WORK/md5sum.txt" /md5sum.txt \
	-boot_image any replay 2> "$WORK/xorriso.log" || {
	cat "$WORK/xorriso.log" >&2
	fail "xorriso failed."
}

log "Checking the boot records"
python3 "$ROOT/build/check-iso.py" --fix "$OUT_ISO" || fail "The ISO would not boot, see above."

(cd "$OUT" && sha256sum "$(basename "$OUT_ISO")" > "$(basename "$OUT_ISO").sha256")
log "Done: $OUT_ISO ($(du -h "$OUT_ISO" | cut -f1))"
