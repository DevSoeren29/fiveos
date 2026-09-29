#!/usr/bin/env python3
"""Checks that an ISO can boot: El Torito catalog present and the ISOLINUX
boot info table (BIOS boot) points to isolinux.bin with a valid checksum.
Without a correct table ISOLINUX stops with "Image checksum error"."""
import struct
import sys

SECTOR = 2048


def read(f, lba, size=SECTOR):
    f.seek(lba * SECTOR)
    return f.read(size)


def check(path):
    with open(path, "rb") as f:
        catalog = None
        for lba in range(16, 64):
            vd = read(f, lba)
            if vd[1:6] != b"CD001":
                continue
            if vd[0] == 0 and vd[7:30].startswith(b"EL TORITO"):
                catalog = struct.unpack_from("<I", vd, 0x47)[0]
                break
        if catalog is None:
            return "no El Torito boot record found"

        cat = read(f, catalog)
        if cat[0] != 1 or cat[0x1E:0x20] != b"\x55\xaa":
            return "invalid El Torito boot catalog"
        default = cat[32:64]
        if default[0] != 0x88:
            return "default boot entry is not bootable"
        image_lba = struct.unpack_from("<I", default, 8)[0]

        head = read(f, image_lba, 64)
        _pvd, bi_file, bi_length, bi_csum = struct.unpack_from("<IIII", head, 8)
        if bi_file != image_lba:
            return f"boot info table points to LBA {bi_file}, isolinux.bin is at {image_lba}"
        if not 2048 < bi_length < 1 << 20:
            return f"implausible boot file length {bi_length}"
        data = read(f, image_lba, bi_length)[64:]
        data += b"\0" * (-len(data) % 4)
        csum = sum(struct.unpack(f"<{len(data) // 4}I", data)) & 0xFFFFFFFF
        if csum != bi_csum:
            return f"isolinux.bin checksum mismatch ({csum:#010x} != {bi_csum:#010x})"
        print(f"    BIOS boot: isolinux.bin at LBA {image_lba}, {bi_length} bytes, checksum OK")

        entries = sum(1 for off in range(64, SECTOR, 32) if cat[off] == 0x88)
        print(f"    El Torito: default entry + {entries} further boot entr{'y' if entries == 1 else 'ies'} (UEFI)")
    return None


if __name__ == "__main__":
    error = check(sys.argv[1])
    if error:
        print(f"ERROR: {error}", file=sys.stderr)
        sys.exit(1)
