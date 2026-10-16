#!/usr/bin/env python3
# blob-elf-wire.py — DT_NEEDED wiring of stock m5c blobs to the Treble shims.
#
#   blob-elf-wire.py scan PROPRIETARY_DIR REL...        > treble-elf-wiring.txt
#   blob-elf-wire.py apply --patchelf P --wiring W REL FILE
#
# The M/N-era MediaTek blobs import symbols that no Android 13 library
# exports (MTK xlog, android_memset16, PermissionCache, __pthread_gettid), that moved to a
# library they do not NEED (CallStack -> libutilscallstack, VNDK-SP), or that
# must not come from the platform (android::Region for Mali: libui.so is kept
# out of sphal, see device/meizu/m5c/treble/region.cpp).  The fix is a
# DT_NEEDED edit with patchelf, made at build time on a copy — the pristine
# blobs under proprietary/ are shared with lineage-20 and never touched
# (vendor/meizu/m5c/Android.mk, m5c-treble-blob).
#
# scan derives the wiring from the blobs' own imports (RULES below) and
# prints one line per ELF:  REL [OLD=NEW ...] [+SONAME ...]
# apply refuses to produce anything it cannot justify: every +SONAME must be
# backed by at least one import that library is here for, every OLD=NEW by
# the imports RULES name for it, and after patching no import covered by
# RULES may be left without its library — a swapped blob fails the build.
# Pure Python on purpose: the build's python3 has no pyelftools.
import os
import re
import struct
import subprocess
import sys

# soname -> predicate over an imported symbol name: the library supplies it.
ADD = {
    "libm5cshim_legacy.so": lambda s: s in (
        "__xlog_buf_printf", "android_memset16",
        "_ZN7android15PermissionCache22checkCallingPermissionERKNS_8String16E",
        "__pthread_gettid"),
    "libutilscallstack.so": lambda s: s.startswith(("_ZN7android9CallStack",
                                                    "_ZNK7android9CallStack")),
    # BoringSSL has no SSLv3 methods (device/meizu/m5c/treble/ssl.cpp).
    "libm5cshim_ssl.so": lambda s: s in ("SSLv3_client_method", "SSLv3_server_method"),
    # N camera API gone from A13 (device/meizu/m5c/treble/camera.cpp).
    "libm5cshim_camera.so": lambda s: s in CAMERA_SHIM,
    # The N sensor API LineageOS libsensor_vendor still provides.
    "libsensor_vendor.so": lambda s: s in SENSOR_COMPAT,
}
# Executables only: soname -> predicate, as ADD.  FACT (A13 boot of
# 2026-09-28): "CANNOT LINK EXECUTABLE /vendor/bin/wmt_loader: cannot locate
# symbol __android_log_print" (6620_launcher the same) — the N-era binaries
# NEED libcutils and got the logger through it; in A13 libcutils comes from
# the VNDK namespace and its dependencies are not searched for the
# executable's own symbols.  nvram_daemon links only because one of its
# /vendor libraries NEEDs liblog.  Libraries are left alone: they resolve
# through the executable that loads them.
ADD_BIN = {
    "liblog.so": lambda s: s.startswith("__android_log_"),
}
# What device/meizu/m5c/treble/camera.cpp defines for the camera closure
# (libcam_utils, libmtk_mmutils, libmmsdkservice.feature,
# libcam.utils.sensorlistener; FACT m5c_linkaudit 2026-09-29).
CAMERA_SHIM = frozenset((
    "_ZN7android11PropertyMapC1Ev", "_ZN7android11PropertyMapD1Ev",
    "_ZN7android11PropertyMap5clearEv",
    "_ZN7android11PropertyMap11addPropertyERKNS_7String8ES3_",
    "_ZNK7android11PropertyMap11hasPropertyERKNS_7String8E",
    "_ZNK7android11PropertyMap14tryGetPropertyERKNS_7String8ERS1_",
    "_ZNK7android11PropertyMap14tryGetPropertyERKNS_7String8ERb",
    "_ZNK7android11PropertyMap14tryGetPropertyERKNS_7String8ERf",
    "_ZNK7android11PropertyMap14tryGetPropertyERKNS_7String8ERi",
    "_ZN7android13GraphicBufferC1Ejjij",
    "_ZN7android13GraphicBufferC1EjjijjP13native_handleb",
    "_ZN7android13GraphicBufferC1EP19ANativeWindowBufferb",
    "_ZN7android13GraphicBuffer4lockEjPPv",
    "_ZN7android11BufferQueue17createBufferQueueEPNS_2spINS_22IGraphicBufferProducerEEE"
    "PNS1_INS_22IGraphicBufferConsumerEEERKNS1_INS_19IGraphicBufferAllocEEE",
    "_ZN7android18BufferItemConsumerC1ERKNS_2spINS_22IGraphicBufferConsumerEEEjib",
    "_ZN7android18BufferItemConsumer7setNameERKNS_7String8E",
    "_ZN7android7SurfaceC1ERKNS_2spINS_22IGraphicBufferProducerEEEb",
    "_ZN7android13SensorManagerC1ERKNS_8String16E",
    "_ZNK7android16SensorEventQueue5getFdEv",
    "_ZN7android21IPermissionController11asInterfaceERKNS_2spINS_7IBinderEEE",
    # open-time closure (libcam_platform): libcam.client, libvfb_render, libvmp_render
    "_ZN7android19GraphicBufferMapper4lockEPK13native_handlejRKNS_4RectEPPv",
    "_ZN7android7String811setPathNameEPKc",
    "_ZNK7android10GLConsumer16getCurrentBufferEv",
))
SENSOR_COMPAT = frozenset((
    "_ZN7android13SensorManager16createEventQueueENS_7String8Ei",
    "_ZN7android13SensorManager16getDefaultSensorEi",
    "_ZN7android16SensorEventQueue4readEP12ASensorEventj",
    "_ZNK7android16SensorEventQueue12enableSensorEPKNS_6SensorE",
    "_ZNK7android16SensorEventQueue12setEventRateEPKNS_6SensorEx",
    "_ZNK7android16SensorEventQueue13disableSensorEPKNS_6SensorE",
))
# Path-restricted additions: soname -> (path regex, predicate).  Operator new
# with slack (device/meizu/m5c/treble/newpad.cpp) for the two dlopen roots
# whose closures construct Android 13 objects in Nougat-sized blocks
# (camera.cpp): the camera HAL (GraphicBuffer 136 -> 160 bytes in
# libcam_utils, libmtk_mmutils, libmmsdkservice.feature, libcam.client,
# libcam.common.meizu; BufferItemConsumer 1064 -> 1080) and the OMX video
# encoder libMtkOmxVenc (GraphicBuffer, 136, three call sites), which
# libMtkOmxCore dlopens on its own.  Prepended to the root's DT_NEEDED, so
# bionic finds it before libc++ for everything that dlopen loads.
# 2026-09-29, set 18: libcam_platform.so is a third root — the camera
# devicemgr dlopen()s it at open, and libcam.client / libcam.device1 (N
# GraphicBuffer blocks, and a Thread::run without a name that Android 13
# aborts on; newpad.cpp) come in with it.  It imports no operator new itself,
# so the rule is by path alone.
ADD_PATH = {
    "libm5cshim_newpad.so": (re.compile(r"^lib(64)?/(hw/camera\.mt6737m|libMtkOmxVenc|libcam_platform)\.so$"),
                             lambda s: True),
}
# (old, new, path regex, symbols new must supply, symbols that forbid it)
# libm5cshim_region.so exports exactly the Region calls libGLES_mali makes
# (both ABIs, readelf; getArray takes size_t*, hence j/m).  Any other Region
# or libui import forbids the swap: the shim would leave it unresolved.
REGION_SHIMMED = re.compile(r"^(_ZN7android6Region(C1Ev|D1Ev|5clearEv|3setEii"
                            r"|6orSelfERKNS_4RectE|12subtractSelfERKNS_4RectE)"
                            r"|_ZNK7android6Region8getArrayEP[jm])$")
LIBUI_OTHER = re.compile(r"^(?!%s)_ZN?K?7android(6Region|4Rect|5Fence|9FenceTime"
                         r"|13GraphicBuffer|19GraphicBufferMapper"
                         r"|22GraphicBufferAllocator)" % REGION_SHIMMED.pattern)
# audio.primary.mt6737m NEEDs libtinycompress.so, whose /vendor path belongs
# to the AOSP module that a prebuilt-kernel tree cannot build; the calls it
# makes are answered by device/meizu/m5c/treble/tinycompress.cpp.  Any other
# tinycompress import forbids the swap: the shim would leave it unresolved.
TINYCOMPRESS = ("compress_close", "compress_get_error", "compress_get_tstamp",
                "compress_nonblock", "compress_open", "compress_pause",
                "compress_resume", "compress_set_gapless_metadata",
                "compress_start", "compress_stop", "compress_write",
                "is_compress_ready")
TC_SHIMMED = re.compile(r"^(%s)$" % "|".join(TINYCOMPRESS))
TC_OTHER = re.compile(r"^(?!(%s)$)(compress_|is_compress_|is_codec_supported$)"
                      % "|".join(TINYCOMPRESS))
# libwfo_jni (the stock M JNI of WifiOffloadService, loaded by ForgeImsService
# in "sphal" as a vendor public library) NEEDs libnativehelper.so for
# jniRegisterNativeMethods alone.  Android 13's libnativehelper lives in the
# ART apex, which sphal does not see; device/meizu/m5c/treble/jnihelp.cpp
# answers that one call.  Any other JNIHelp/JniInvocation import forbids the
# swap: the shim would leave it unresolved.
JH_SHIMMED = re.compile(r"^jniRegisterNativeMethods$")
JH_OTHER = re.compile(r"^(?!jniRegisterNativeMethods$)(jni[A-Z]|JNI_|AFileDescriptor_"
                      r"|_ZN\w*JniInvocation)")
REPLACE = [("libui.so", "libm5cshim_region.so", re.compile(r"^lib(64)?/egl/"),
            REGION_SHIMMED, LIBUI_OTHER),
           ("libtinycompress.so", "libm5cshim_tinycompress.so",
            re.compile(r"^lib(64)?/hw/audio\.primary\."), TC_SHIMMED, TC_OTHER),
           ("libnativehelper.so", "libm5cshim_jnihelp.so",
            re.compile(r"^lib(64)?/libwfo_jni\.so$"), JH_SHIMMED, JH_OTHER)]


def elf(path):
    """(needed list, set of non-weak undefined dynamic symbols) of an ELF."""
    d = open(path, "rb").read()
    if d[:4] != b"\x7fELF" or d[5] != 1:
        return None
    is64 = d[4] == 2
    if is64:
        shoff, = struct.unpack_from("<Q", d, 0x28)
        shentsize, shnum = struct.unpack_from("<HH", d, 0x3A)
        shfmt, symfmt, symsz, dynfmt, dynsz = "<IIQQQQIIQQ", "<IBBHQQ", 24, "<qQ", 16
    else:
        shoff, = struct.unpack_from("<I", d, 0x20)
        shentsize, shnum = struct.unpack_from("<HH", d, 0x2E)
        shfmt, symfmt, symsz, dynfmt, dynsz = "<IIIIIIIIII", "<IIIBBH", 16, "<iI", 8
    secs = []
    for i in range(shnum):
        f = struct.unpack_from(shfmt, d, shoff + i * shentsize)
        secs.append(dict(type=f[1], off=f[4], size=f[5], link=f[6]))

    def cstr(sec, o):
        s = secs[sec]["off"] + o
        return d[s:d.index(b"\0", s)].decode()

    needed, und = [], set()
    for s in secs:
        if s["type"] == 6:          # SHT_DYNAMIC
            for o in range(s["off"], s["off"] + s["size"], dynsz):
                tag, val = struct.unpack_from(dynfmt, d, o)
                if tag == 0:
                    break
                if tag == 1:        # DT_NEEDED
                    needed.append(cstr(s["link"], val))
        elif s["type"] == 11:       # SHT_DYNSYM
            for o in range(s["off"] + symsz, s["off"] + s["size"], symsz):
                f = struct.unpack_from(symfmt, d, o)
                if is64:
                    name, info, shndx = f[0], f[1], f[3]
                else:
                    name, info, shndx = f[0], f[3], f[5]
                if shndx == 0 and name and (info >> 4) == 1:   # UND, STB_GLOBAL
                    und.add(cstr(s["link"], name))
    return needed, und


def derive(rel, needed, und):
    """Wiring ops RULES imply for one ELF: (replacements, additions)."""
    rep = []
    for old, new, where, want, forbid in REPLACE:
        if old in needed and where.search(rel) and any(want.search(s) for s in und) \
                and not any(forbid.search(s) for s in und):
            rep.append((old, new))
    after = [dict(rep).get(n, n) for n in needed]
    rules = dict(ADD, **ADD_BIN) if rel.startswith("bin/") else dict(ADD)
    rules.update({so: has for so, (where, has) in ADD_PATH.items() if where.search(rel)})
    add = sorted(so for so, has in rules.items()
                 if so not in after and any(has(s) for s in und))
    return rep, add


def scan(prop, rels):
    for rel in rels:
        info = elf(os.path.join(prop, rel))
        if info is None:
            continue
        rep, add = derive(rel, *info)
        if rep or add:
            print(" ".join([rel] + [f"{o}={n}" for o, n in rep] + [f"+{a}" for a in add]))


def apply(patchelf, wiring, rel, path):
    lines = [l.split() for l in open(wiring) if l.strip() and not l.startswith("#")]
    ops = [l[1:] for l in lines if l[0] == rel]
    if len(ops) != 1:
        sys.exit(f"{rel}: {len(ops)} lines in {wiring}, expected 1")
    rep = [tuple(o.split("=", 1)) for o in ops[0] if "=" in o]
    add = [o[1:] for o in ops[0] if o.startswith("+")]
    needed, und = elf(path)
    want_rep, want_add = derive(rel, needed, und)
    if sorted(rep) != sorted(want_rep) or sorted(add) != sorted(want_add):
        sys.exit(f"{rel}: wiring {ops[0]} but the blob's imports call for "
                 f"{[f'{o}={n}' for o, n in want_rep] + ['+' + a for a in want_add]}"
                 " - the blob is not the one this line was written for")
    args = []
    for old, new in rep:
        args += ["--replace-needed", old, new]
    for a in add:
        args += ["--add-needed", a]
    subprocess.run([patchelf] + args + [path], check=True)
    got, und2 = elf(path)
    expect = set(dict(rep).get(n, n) for n in needed) | set(add)
    if set(got) != expect or und2 != und:
        sys.exit(f"{rel}: after patchelf NEEDED={got}, expected {sorted(expect)}")
    if derive(rel, got, und2) != ([], []):
        sys.exit(f"{rel}: still unwired after patchelf: {derive(rel, got, und2)}")


def main(argv):
    if len(argv) >= 3 and argv[1] == "scan":
        scan(argv[2], argv[3:])
    elif len(argv) == 8 and argv[1] == "apply" and argv[2] == "--patchelf" \
            and argv[4] == "--wiring":
        apply(argv[3], argv[5], argv[6], argv[7])
    else:
        sys.exit("usage: blob-elf-wire.py scan PROPRIETARY_DIR REL...\n"
                 "       blob-elf-wire.py apply --patchelf P --wiring W REL FILE")


if __name__ == "__main__":
    main(sys.argv)
