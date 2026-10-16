#!/usr/bin/env python3
# elf-dynsym-shinfo.py IN OUT — copy a stock blob, correcting the sh_info of
# its .dynsym section header (index of the first non-local symbol).
#
# FACT (build of 2026-09-28 19:50): ld.lld refuses to link the MTK Oreo
# libril against the stock 64-bit mtk-ril.so and librilmtk.so:
#   ld.lld: error: found local symbol '__bss_start__' in global part of
#   symbol table in file .../mtk-ril.so   (x7 per blob)
# Both blobs have .dynsym symbols 0..9 LOCAL and 10.. non-local, but
# sh_info = 3.  The dynamic loader never reads section headers, so the value
# only matters to a static linker; the copy differs from the blob in these
# four bytes and nothing else.  The fix is refused (exit 1) unless the local
# symbols form one run from index 0 — anything else cannot be expressed by
# sh_info and would need a real rewrite.  A blob that is already consistent
# (the 32-bit pair) is copied unchanged.
import shutil
import struct
import sys


def main(src, dst):
    d = bytearray(open(src, "rb").read())
    if d[:4] != b"\x7fELF" or d[5] != 1:
        sys.exit(f"{src}: not a little-endian ELF")
    is64 = d[4] == 2
    if is64:
        shoff, = struct.unpack_from("<Q", d, 0x28)
        shentsize, shnum = struct.unpack_from("<HH", d, 0x3A)
        fmt, info_at, bind_at = "<IIQQQQIIQQ", 44, 4
    else:
        shoff, = struct.unpack_from("<I", d, 0x20)
        shentsize, shnum = struct.unpack_from("<HH", d, 0x2E)
        fmt, info_at, bind_at = "<IIIIIIIIII", 28, 12
    for i in range(shnum):
        o = shoff + i * shentsize
        _, typ, _, _, off, size, _, info, _, entsz = struct.unpack_from(fmt, d, o)
        if typ != 11:  # SHT_DYNSYM
            continue
        binds = [d[off + k * entsz + bind_at] >> 4 for k in range(size // entsz)]
        first = next(k for k, b in enumerate(binds) if b != 0)
        if any(b == 0 for b in binds[first:]):
            sys.exit(f"{src}: local symbols after index {first}, sh_info cannot describe it")
        if info != first:
            struct.pack_into("<I", d, o + info_at, first)
            print(f"{src}: .dynsym sh_info {info} -> {first}")
        break
    else:
        sys.exit(f"{src}: no .dynsym")
    open(dst, "wb").write(bytes(d))
    shutil.copymode(src, dst)


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit("usage: elf-dynsym-shinfo.py IN OUT")
    main(sys.argv[1], sys.argv[2])
