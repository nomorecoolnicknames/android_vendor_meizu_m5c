#!/usr/bin/env python3
# blob-path-patch.py IN OUT OLD=NEW[@COUNT] ...
#
# Rewrites absolute paths inside a stock blob, same length only, and refuses
# to produce anything it cannot prove: every OLD must have exactly len(NEW)
# bytes, must occur in IN (exactly COUNT times when @COUNT is given), and no
# replacement may be left undone.  The source blob is never touched; the
# patched copy is written to OUT at build time (vendor/meizu/m5c/Android.mk,
# m5c_treble_patched_blobs).
#
# Why: under full Treble a vendor process may not dlopen() from /system and
# should not read /system/etc, but the N-era MediaTek blobs spell those paths
# out (the bring-up notes).
# "/system/" and "/vendor/" are both 8 bytes, so a path keeps its length and
# nothing after it moves.
import sys


def main(argv):
    if len(argv) < 4:
        sys.exit("usage: blob-path-patch.py IN OUT OLD=NEW[@COUNT] ...")
    src, dst, specs = argv[1], argv[2], argv[3:]
    data = open(src, "rb").read()
    for spec in specs:
        pair, _, count = spec.partition("@")
        old, new = (s.encode() for s in pair.split("=", 1))
        if len(old) != len(new):
            sys.exit(f"{src}: '{old.decode()}' -> '{new.decode()}' changes length")
        n = data.count(old)
        if n == 0 or (count and n != int(count)):
            sys.exit(f"{src}: '{old.decode()}' found {n} times, expected {count or '>=1'}"
                     " - the blob is not the one this rule was written for")
        data = data.replace(old, new)
    with open(dst, "wb") as f:
        f.write(data)


if __name__ == "__main__":
    main(sys.argv)
