#!/usr/bin/env python3
# blob-parcel-box.py — "box" the Marshmallow android::Parcel of the stock
# 64-bit librilmtk.so so that it stops overrunning Android 13 storage.
#
#   blob-parcel-box.py --patchelf P IN OUT
#
# FACT: sizeof(android::Parcel) is 120 bytes on arm64 with the A13 headers
# (los20, clang r450784d), and the stock librilmtk reserves 104
# (enqueueLocalRequestResponse: mov x0, #104; bl operator new;
# bl Parcel::Parcel(), 0x22c24-0x22c30); it constructs Parcels on the stack
# and on the heap in 16 places, among them IMS_RIL_onUnsolicitedResponseSocket
# and IMS_RIL_onRequestComplete.  Against the A13 libbinder every constructor
# writes 16 bytes past the storage.
#  the bring-up notes, H3.
#
# The copy made here imports android::Pbrcel instead: the 16 imported
# android::Parcel method names in .dynstr become 6Pbrcel (same length), and
# libm5cshim_nparcel.so (device/meizu/m5c treble/nparcel.cpp) is added to
# DT_NEEDED.  The shim keeps a pointer to a heap-allocated real Parcel in the
# first 8 bytes of the blob's 104-byte storage and forwards every method.
# The approach is the m95 one (device/meizu/m95 shims/nparcel.cpp,
# tools/librilimp-box-nparcel.py), applied at build time on a copy: the
# pristine blob under proprietary/ is never touched.
#
# Why the box is enough (checked on this blob, 2026-09-30): the 16 imports
# are all the Parcel it uses; no export takes or returns a Parcel (the only
# export naming one, nullParcelReleaseFunction, deals in raw bytes); a scan for
# inline loads/stores into a Parcel's storage found only reused stack slots
# and reassigned registers (11 candidates, each read by hand).
#
# Refuses to write anything unless exactly these 16 strings carry
# "android6Parcel", and checks the result.
import struct
import subprocess
import sys

SHIM = b"libm5cshim_nparcel.so"
PARCEL = [
    b"_ZN7android6Parcel10writeInt32Ei",
    b"_ZN7android6Parcel10writeInt64El",
    b"_ZN7android6Parcel13writeString16EPKDsm",
    b"_ZN7android6Parcel5writeEPKvm",
    b"_ZN7android6Parcel7setDataEPKhm",
    b"_ZN7android6ParcelC1Ev",
    b"_ZN7android6ParcelD1Ev",
    b"_ZNK7android6Parcel11readInplaceEm",
    b"_ZNK7android6Parcel12dataPositionEv",
    b"_ZNK7android6Parcel15setDataPositionEm",
    b"_ZNK7android6Parcel19readString16InplaceEPm",
    b"_ZNK7android6Parcel4dataEv",
    b"_ZNK7android6Parcel4readEPvm",
    b"_ZNK7android6Parcel8dataSizeEv",
    b"_ZNK7android6Parcel9readInt32EPi",
    b"_ZNK7android6Parcel9readInt32Ev",
]


def dynstr(d):
    """(offset, size) of .dynstr in a 64-bit little-endian ELF."""
    if d[:4] != b"\x7fELF" or d[4] != 2 or d[5] != 1:
        sys.exit("not a 64-bit little-endian ELF")
    shoff, = struct.unpack_from("<Q", d, 0x28)
    shentsize, shnum, shstrndx = struct.unpack_from("<HHH", d, 0x3A)
    names, = struct.unpack_from("<Q", d, shoff + shstrndx * shentsize + 0x18)
    for i in range(shnum):
        o = shoff + i * shentsize
        n, = struct.unpack_from("<I", d, o)
        if d[names + n:d.index(b"\0", names + n)] == b".dynstr":
            off, size = struct.unpack_from("<QQ", d, o + 0x18)
            return off, size
    sys.exit("no .dynstr")


def strings_with(d, off, size, needle):
    """Every NUL-terminated string of .dynstr that contains needle."""
    out, pos = [], off
    while pos < off + size:
        end = d.index(b"\0", pos)
        if needle in d[pos:end]:
            out.append((pos, d[pos:end]))
        pos = end + 1
    return out


def dynamic(d):
    """(DT_NEEDED list, names of undefined GLOBAL/WEAK .dynsym entries) of a
    64-bit little-endian ELF.  Pure Python on purpose, as blob-elf-wire.py:
    inside the build `readelf` is not an allowed PATH tool (it is missing from
    build/soong/ui/build/paths/config.go, the interposer fails the rule with
    "Disallowed PATH tool"; set 28-volte, 2026-09-30 17:33)."""
    shoff, = struct.unpack_from("<Q", d, 0x28)
    shentsize, shnum = struct.unpack_from("<HH", d, 0x3A)
    secs = []
    for i in range(shnum):
        f = struct.unpack_from("<IIQQQQIIQQ", d, shoff + i * shentsize)
        secs.append(dict(type=f[1], off=f[4], size=f[5], link=f[6]))

    def cstr(sec, o):
        s = secs[sec]["off"] + o
        return d[s:d.index(b"\0", s)].decode()

    needed, und = [], []
    for s in secs:
        if s["type"] == 6:                                  # SHT_DYNAMIC
            for o in range(s["off"], s["off"] + s["size"], 16):
                tag, val = struct.unpack_from("<qQ", d, o)
                if tag == 0:
                    break
                if tag == 1:                                # DT_NEEDED
                    needed.append(cstr(s["link"], val))
        elif s["type"] == 11:                               # SHT_DYNSYM
            for o in range(s["off"] + 24, s["off"] + s["size"], 24):
                name, info, _, shndx = struct.unpack_from("<IBBH", d, o)
                if shndx == 0 and name and (info >> 4) in (1, 2):   # UND, GLOBAL/WEAK
                    und.append(cstr(s["link"], name))
    return needed, und


def main(argv):
    if len(argv) != 5 or argv[1] != "--patchelf":
        sys.exit("usage: blob-parcel-box.py --patchelf P IN OUT")
    patchelf, src, dst = argv[2], argv[3], argv[4]
    d = bytearray(open(src, "rb").read())
    off, size = dynstr(d)
    found = strings_with(d, off, size, b"android6Parcel")
    if sorted(s for _, s in found) != sorted(PARCEL):
        sys.exit(f"{src}: android6Parcel strings are {sorted(s for _, s in found)}, "
                 "expected the 16 of this rule - the blob is not the one it was written for")
    for pos, s in found:
        i = pos + s.index(b"6Parcel")
        d[i:i + 7] = b"6Pbrcel"
    with open(dst, "wb") as f:
        f.write(d)
    subprocess.run([patchelf, "--add-needed", SHIM.decode(), dst], check=True)

    needed, und = dynamic(open(dst, "rb").read())
    boxed = [s for s in und if "6Pbrcel" in s]
    left = [s for s in und if "6Parcel" in s]
    if len(boxed) != len(PARCEL) or left or SHIM.decode() not in needed:
        sys.exit(f"{dst}: after boxing {len(boxed)} Pbrcel imports, {len(left)} Parcel "
                 f"imports left, shim in NEEDED: {SHIM.decode() in needed}")


if __name__ == "__main__":
    main(sys.argv)
