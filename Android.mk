# Guarded: kati parses every Android.mk for every product of the workspace,
# and the modules and install rules below are m5c's alone (the sibling trees
# vendor/meizu/{m95,m5s,m2note} define modules of the same names).
ifeq ($(TARGET_DEVICE),m5c)
LOCAL_PATH := $(call my-dir)

# libnvram has no module here on purpose: the blob is installed by
# m5c-vendor-blobs.mk and nothing links it by name: its users are stock
# blobs that NEED it (e.g. libbluetooth_mtk, under libbt-vendor of the BT HAL).
# A kati libnvram also collided with a Soong module of another tree on LOS16
# ("MODULE.TARGET.SHARED_LIBRARIES.libnvram already defined").

# No modules for libdpframework, libgralloc_extra, libaudiocustparam or
# librilimp: nothing in the m5c build links them by name (FACT, kati ninja of
# the 2026-09-29 build: no consumer outside their own rules; forge_hwc only
# dlopen()s libgralloc_extra; librilimp served hardware/ril/libril, which
# BOARD_PROVIDES_LIBRIL switches off).  libgralloc_extra and
# libaudiocustparam are installed by m5c-vendor-blobs.mk (byte-identical to
# the stock blobs in the image), libdpframework by the wiring rule below.

# The stock RIL pair as modules, so the MTK Oreo HIDL libril of
# device/meizu/m5c/ril/libril can link them by name (LOCAL_SHARED_LIBRARIES
# librilmtk, mtk-ril).  They install to $(TARGET_OUT_VENDOR)/lib{,64}, which
# is also where the runtime users find them (rild, the MTK libril, and
# mtk-ril.so's own DT_NEEDED librilmtk.so).
# FACT (readelf 2026-09-03): the stock 64-bit librilmtk exports every MTK
# entry the Oreo libril imports (IMS_RIL_onUnsolicitedResponseSocket,
# IMS_isRilRequestFromIms, IMS_RILA_register, RIL_UpdateToVT, ...), and
# mtk-ril.so exports RIL_InitSocket/RIL_SAP_Init (no RIL_Init).
#
# 2026-09-28 (flash-m5c): the 64-bit pair goes through elf-dynsym-shinfo.py.
# FACT (build of 19:50): ld.lld refused to link the MTK libril of
# device/meizu/m5c/ril against them — "found local symbol '__bss_start__' in
# global part of symbol table" x7 per blob: .dynsym symbols 0..9 are LOCAL but
# sh_info says 3.  The copy fixes that one section-header field (the loader
# never reads it); the 32-bit pair is consistent and stays as is.  Split into
# 64/32 definitions because LOCAL_PREBUILT_MODULE_FILE is one path per module.
#
# 2026-09-30 (VoLTE): the 64-bit librilmtk is also boxed (blob-parcel-box.py):
# it was built for a 104-byte android::Parcel, Android 13's is 120, and its IMS
# path (IMS_RIL_onUnsolicitedResponseSocket, IMS_RIL_onRequestComplete) builds
# Parcels on the stack.  Its 16 Parcel imports become android::Pbrcel, served by
# libm5cshim_nparcel (device/meizu/m5c treble/nparcel.cpp) through a pointer to
# a real heap Parcel (the bring-up notes).
M5C_SHINFO_FIX := $(LOCAL_PATH)/elf-dynsym-shinfo.py
M5C_PARCEL_BOX := $(LOCAL_PATH)/blob-parcel-box.py
M5C_PATCHELF := prebuilts/extract-tools/linux-x86/bin/patchelf-0_17_2
M5C_SHINFO_DIR := $(TARGET_OUT_INTERMEDIATES)/M5C_SHINFO_FIXED
$(M5C_SHINFO_DIR)/lib64/librilmtk.so: $(LOCAL_PATH)/proprietary/lib64/librilmtk.so $(M5C_SHINFO_FIX) $(M5C_PARCEL_BOX) $(M5C_PATCHELF)
	@mkdir -p $(dir $@)
	$(hide) rm -f $@.tmp
	$(hide) python3 $(M5C_SHINFO_FIX) $< $@.tmp
	$(hide) python3 $(M5C_PARCEL_BOX) --patchelf $(M5C_PATCHELF) $@.tmp $@
	$(hide) rm -f $@.tmp
$(M5C_SHINFO_DIR)/lib64/mtk-ril.so: $(LOCAL_PATH)/proprietary/lib64/mtk-ril.so $(M5C_SHINFO_FIX)
	@mkdir -p $(dir $@)
	$(hide) python3 $(M5C_SHINFO_FIX) $< $@

include $(CLEAR_VARS)
LOCAL_MODULE := librilmtk
LOCAL_MODULE_OWNER := meizu
LOCAL_MODULE_TAGS := optional
LOCAL_MODULE_CLASS := SHARED_LIBRARIES
LOCAL_MODULE_SUFFIX := .so
LOCAL_PROPRIETARY_MODULE := true
LOCAL_MULTILIB := 64
LOCAL_PREBUILT_MODULE_FILE := $(M5C_SHINFO_DIR)/lib64/librilmtk.so
# 2026-10-07 (set 36-volte): no strip.  patchelf (--add-needed in the box)
# appends a PT_LOAD at file offset 0x40000 / vaddr 0x50000 holding the moved
# .dynstr/.gnu.hash/.dynamic.  The default prebuilt strip (llvm-strip
# --strip-all, clang-r450784d) repacks it to file offset 0x3bbf0, no longer
# congruent with the vaddr modulo the page; bionic maps file page 0x3b000
# there and rild died with "empty/missing DT_HASH/DT_GNU_HASH in
# /vendor/lib64/librilmtk.so" (FACT: llvm-strip of LINKED/librilmtk.so
# reproduces the installed 0f7a5788 byte for byte).
LOCAL_STRIP_MODULE := false
include $(BUILD_PREBUILT)

include $(CLEAR_VARS)
LOCAL_MODULE := librilmtk
LOCAL_MODULE_OWNER := meizu
LOCAL_MODULE_TAGS := optional
LOCAL_MODULE_CLASS := SHARED_LIBRARIES
LOCAL_MODULE_SUFFIX := .so
LOCAL_PROPRIETARY_MODULE := true
LOCAL_MULTILIB := 32
LOCAL_SRC_FILES_32 := proprietary/lib/librilmtk.so
include $(BUILD_PREBUILT)

include $(CLEAR_VARS)
LOCAL_MODULE := mtk-ril
LOCAL_MODULE_OWNER := meizu
LOCAL_MODULE_TAGS := optional
LOCAL_MODULE_CLASS := SHARED_LIBRARIES
LOCAL_MODULE_SUFFIX := .so
LOCAL_PROPRIETARY_MODULE := true
LOCAL_MULTILIB := 64
LOCAL_PREBUILT_MODULE_FILE := $(M5C_SHINFO_DIR)/lib64/mtk-ril.so
include $(BUILD_PREBUILT)

include $(CLEAR_VARS)
LOCAL_MODULE := mtk-ril
LOCAL_MODULE_OWNER := meizu
LOCAL_MODULE_TAGS := optional
LOCAL_MODULE_CLASS := SHARED_LIBRARIES
LOCAL_MODULE_SUFFIX := .so
LOCAL_PROPRIETARY_MODULE := true
LOCAL_MULTILIB := 32
LOCAL_SRC_FILES_32 := proprietary/lib/mtk-ril.so
include $(BUILD_PREBUILT)

# ---------------------------------------------------------------------------
# Full Treble (2026-09-25, branch lineage-20-treble): path-patched copies of
# nine stock blobs.  Each one spells an absolute /system path that a Treble
# vendor process can no longer use — it may not dlopen() from /system/lib*
# (the vendor linker namespace permits /odm, /vendor, /system/vendor only) and
# the files those paths name now live on /vendor (m5c-vendor-blobs.mk header).
# The rewrite is same-length and counted: blob-path-patch.py fails the build
# if a string is missing or occurs a different number of times than the
# strings scan of 2026-09-25 found, i.e. if the blob is ever swapped.
# The pristine blobs under proprietary/ are not modified.
#
#   libvcodecdrv (lib)      dlopen()s 14 codec cores by /system/lib/...
#   libvcodecdrv (lib64)    7 x /system/lib/..., 3 x /system/lib64/...
#   libMtkOmxCore           fopen("/system/etc/mtk_omx_core.cfg")
#   audio.primary.mt6737m   /system/etc/audio_device.xml
#   libmal_imsmngr          dlopen("/system/lib/volte_imsm.so")
#   thermal_manager         /etc/.tp/{thermal.conf,.%s} -> /odm/etc/ (the .tp
#                           files are installed to $(TARGET_COPY_OUT_ODM)/etc,
#                           reached through the /odm/etc -> /vendor/odm/etc
#                           symlink of the A13 rootdir), and
#                           dlopen("/system/lib/libmtcloader.so")
#   fuelgauged              dlopen("/system/lib/libfgauge.so")
#   mtkrild                 dlopen("/system/lib/mtk-ril.so")
#   factory                 /system/etc/factory.ini
#   mtkmal                  opendir()s "/system/lib" or "/vendor/lib" for its
#                           libmal_* entities (both strings, one each); which
#                           one it picks on A13 is not known, so both now say
#                           /vendor/lib (VoLTE, the bring-up notes
#                           H2)
# fuelgauged, mtkrild and factory were broken before Treble already: their
# libraries sat in /vendor/lib since LOS16 while the blobs kept asking
# /system/lib.
#
# Second pass on the same copy: DT_NEEDED wiring to the Treble shims for the
# ELFs listed in treble-elf-wiring.txt (blob-elf-wire.py, patchelf from
# prebuilts/extract-tools).  Those entries are filtered out of
# PRODUCT_COPY_FILES in m5c-vendor-blobs.mk — the copy rules of
# build/make/core/Makefile come after this file and would win otherwise.
# ---------------------------------------------------------------------------
M5C_BLOB_PATCH := $(LOCAL_PATH)/blob-path-patch.py
M5C_ELF_WIRE := $(LOCAL_PATH)/blob-elf-wire.py
M5C_ELF_WIRING := $(LOCAL_PATH)/treble-elf-wiring.txt
M5C_ELF_WIRED := $(shell sed -n 's/^\([^#[:space:]][^[:space:]]*\).*/\1/p' $(M5C_ELF_WIRING))
M5C_TREBLE_RELS :=
M5C_TREBLE_PATCHED :=

# $(1) path under proprietary/ and /vendor, $(2) path rewrites for
# blob-path-patch.py (may be empty), $(3) file mode
define m5c-treble-blob
$(TARGET_OUT_VENDOR)/$(1): $(LOCAL_PATH)/proprietary/$(1) $(M5C_BLOB_PATCH) $(M5C_ELF_WIRE) $(M5C_ELF_WIRING) $(M5C_PATCHELF)
	@mkdir -p $$(dir $$@)
	$(hide) rm -f $$@.tmp
	$(hide) $(if $(2),python3 $(M5C_BLOB_PATCH) $$< $$@.tmp $(2),cp $$< $$@.tmp)
	$(hide) $(if $(filter $(1),$(M5C_ELF_WIRED)),python3 $(M5C_ELF_WIRE) apply --patchelf $(M5C_PATCHELF) --wiring $(M5C_ELF_WIRING) $(1) $$@.tmp,true)
	$(hide) chmod $(3) $$@.tmp
	$(hide) mv -f $$@.tmp $$@
M5C_TREBLE_RELS += $(1)
M5C_TREBLE_PATCHED += $(TARGET_OUT_VENDOR)/$(1)
endef

$(eval $(call m5c-treble-blob,lib/libvcodecdrv.so,/system/lib/=/vendor/lib/@14,644))
$(eval $(call m5c-treble-blob,lib64/libvcodecdrv.so,/system/lib/=/vendor/lib/@7 /system/lib64/=/vendor/lib64/@3,644))
$(eval $(call m5c-treble-blob,lib/libMtkOmxCore.so,/system/etc/mtk_omx_core.cfg=/vendor/etc/mtk_omx_core.cfg@1,644))
$(eval $(call m5c-treble-blob,lib64/libMtkOmxCore.so,/system/etc/mtk_omx_core.cfg=/vendor/etc/mtk_omx_core.cfg@1,644))
$(eval $(call m5c-treble-blob,lib/hw/audio.primary.mt6737m.so,/system/etc/audio_device.xml=/vendor/etc/audio_device.xml@1,644))
$(eval $(call m5c-treble-blob,lib64/hw/audio.primary.mt6737m.so,/system/etc/audio_device.xml=/vendor/etc/audio_device.xml@1,644))
$(eval $(call m5c-treble-blob,lib/libmal_imsmngr.so,/system/lib/volte_imsm.so=/vendor/lib/volte_imsm.so@1,644))
$(eval $(call m5c-treble-blob,lib64/libmal_imsmngr.so,/system/lib/volte_imsm.so=/vendor/lib/volte_imsm.so@1,644))
$(eval $(call m5c-treble-blob,bin/thermal_manager,/etc/.tp/=/odm/etc/@2 /system/lib/libmtcloader.so=/vendor/lib/libmtcloader.so@1,755))
$(eval $(call m5c-treble-blob,bin/fuelgauged,/system/lib/libfgauge.so=/vendor/lib/libfgauge.so@1,755))
$(eval $(call m5c-treble-blob,bin/mtkrild,/system/lib/mtk-ril.so=/vendor/lib/mtk-ril.so@1,755))
$(eval $(call m5c-treble-blob,bin/factory,/system/etc/factory.ini=/vendor/etc/factory.ini@1,755))
$(eval $(call m5c-treble-blob,bin/mtkmal,/system/lib=/vendor/lib@1,755))
$(foreach f,$(filter-out $(M5C_TREBLE_RELS),$(M5C_ELF_WIRED)),\
    $(eval $(call m5c-treble-blob,$(f),,$(if $(filter bin/%,$(f)),755,644))))

ALL_DEFAULT_INSTALLED_MODULES += $(M5C_TREBLE_PATCHED)

# ---------------------------------------------------------------------------
# /vendor/firmware links to the modem images in /vendor/etc/firmware.
# device/meizu/m5c sets firmware_class.path=/vendor/firmware at early-init so
# that the kernel loads firmware itself instead of through ueventd; the path
# parameter takes ONE directory.  FACT (set 27, 2026-09-30): the names the
# kernel requests are pcm_{suspend,sodi,deepidle,vcore_dvfs}_2.bin (already in
# /vendor/firmware) and modem_1_lwg_n.img, dsp_1_lwg_n.bin (installed to
# /vendor/etc/firmware by m5c-vendor-blobs.mk, where ccci_mdinit looks for
# them and ueventd finds them via firmware_directories).  No name exists in
# two firmware directories (the bring-up notes). Relative links: the
# kernel resolves them from /vendor/firmware.
M5C_FW_LINKS := $(addprefix $(TARGET_OUT_VENDOR)/firmware/,modem_1_lwg_n.img dsp_1_lwg_n.bin)
$(M5C_FW_LINKS):
	@mkdir -p $(dir $@)
	$(hide) ln -sfn ../etc/firmware/$(notdir $@) $@
ALL_DEFAULT_INSTALLED_MODULES += $(M5C_FW_LINKS)

# ---------------------------------------------------------------------------
# MediaTek sources and objects the device tree builds with but may not carry:
# their files say "confidential and proprietary to MediaTek" (moved here from
# device/meizu/m5c on 2026-09-30, byte-identical).  The consumers stay in the
# device tree: device/meizu/m5c/ril/rild links rild-prop-md1 by name,
# ril/libril includes ril/libril/mtk_ril_unsol_commands.h from here.
#
# rild-prop-md1.a: MediaTek's prebuilt property helper object that came with
# the Oreo RIL port (mtkInit, signal_treatment, isUserLoad).
ifeq ($(ENABLE_VENDOR_RIL_SERVICE),true)
include $(CLEAR_VARS)
LOCAL_MODULE := rild-prop-md1
LOCAL_MODULE_CLASS := STATIC_LIBRARIES
LOCAL_MODULE_SUFFIX := .a
LOCAL_PROPRIETARY_MODULE := true
LOCAL_UNINSTALLABLE_MODULE := true
LOCAL_MULTILIB := 64
LOCAL_SRC_FILES_64 := ril/rild/arm64/rild-prop-md1.a
include $(BUILD_PREBUILT)

include $(CLEAR_VARS)
LOCAL_MODULE := rild-prop-md1
LOCAL_MODULE_CLASS := STATIC_LIBRARIES
LOCAL_MODULE_SUFFIX := .a
LOCAL_PROPRIETARY_MODULE := true
LOCAL_UNINSTALLABLE_MODULE := true
LOCAL_MULTILIB := 32
LOCAL_SRC_FILES_32 := ril/rild/arm/rild-prop-md1.a
include $(BUILD_PREBUILT)
endif

# gps.mt6737m, the MTK Gen-N GPS HAL (gps/gps_hal/Android.mk).  Last: the
# included file sets LOCAL_PATH to its own directory.
include $(LOCAL_PATH)/gps/gps_hal/Android.mk

endif
