# Copyright (C) 2016 The CyanogenMod Project
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Stock Flyme blobs of the m5c, copied as they are — full Treble layout
# (branch lineage-20-treble, with device/meizu/m5c lineage-20-treble;
#  the bring-up notes). Maintained by hand: there is
# no setup-makefiles.sh for this tree, and git history is the changelog.
#
# Two rules decide what may appear here:
#  - PRODUCT_COPY_FILES is first-wins per destination, and it silently beats
#    a module the build installs to the same path (build/make/core/Makefile:72
#    overrides the install rule).  A blob here therefore replaces anything
#    Android 13 would build in its place.
#  - A comment inside the backslash-continued list below breaks the list and
#    lunch fails silently.  Keep notes up here.
#
# Where things go:
#  -> vendor/bin, vendor/lib{,64} (incl. egl/, hw/*.mt6737m.so, res/), and the
#     former system/lib* set (RIL/MAL chain, codec cores, libvcodecdrv,
#     libperfservicenative, libccci_util): a vendor process cannot dlopen()
#     anything under /system/lib* (the vendor namespace allows /odm, /vendor,
#     /system/vendor), so absolute /system paths inside blobs are fixed at the
#     source (Android.mk, m5c-treble-blob) instead of kept alive.
#  -> vendor/etc/firmware: modem images (modem_*, dsp_*, catcher_filter_*,
#     em_filter_*); ccci_mdinit probes /custom/etc/firmware/ first and
#     init.mt6735.rc makes /custom -> /vendor.
#  -> vendor/etc: mddb, ecc_list, agps_profiles_conf2 (mtk_agpsd also probes
#     /vendor/etc), perfservscntbl, trustzone.bin, factory.ini, wifi/*.conf
#     (the AIDL supplicant reads /vendor/etc/wifi).
#  -> odm/etc (= /vendor/odm/etc via the /odm/etc symlink): the three .tp
#     thermal tables; thermal_manager is patched "/etc/.tp/" -> "/odm/etc/".
#  -> vendor/lib{,64}/libfs_mgr.so: stock N build.  libnvram (both ABIs) NEEDs
#     it for fs_mgr_read_fstab / fs_mgr_get_entry_for_mount_point /
#     fs_mgr_free_fstab, and Android 13 builds libfs_mgr static-only.  The blob
#     NEEDs only libc/libc++/libdl/libm, all imports resolve (nm, both ABIs).
#  -> system/etc: only what the KERNEL opens by path with filp_open(), not
#     request_firmware() (m5c 4.9 source, forge/m5c-49-a13):
#       etc/firmware/*  conn_soc wmt_conf.h:34 "/system/etc/firmware/", wlan
#                       gen2 gl_kal.c:825-851 "/etc/firmware/", fmradio
#                       mt6627_fm_lib.c:33-42 "/etc/firmware/mt6627/";
#                       gt9xx_fw.bin rides along (consumer unproven);
#       etc/fmr/mt6627_fm_cust.cfg  mt6627_fm_config.c:141, relative path;
#       etc/slp_conf    slpd opens "/etc/slp_conf", which has no same-length
#                       spelling under /vendor.
#
# Installed elsewhere, not copied here:
#  - vendor/meizu/m5c/Android.mk: the path-patched blobs (libvcodecdrv,
#    libMtkOmxCore, audio.primary.mt6737m, libmal_imsmngr, thermal_manager,
#    fuelgauged, mtkrild, factory), the DT_NEEDED-wired ELFs of
#    treble-elf-wiring.txt (filtered out of this list at the end of the
#    file), and the prebuilt modules librilimp, librilmtk, mtk-ril.
#  - device/meizu/m5c/configs: audio_device.xml, audio_policy.conf,
#    audio_param/AudioParamOptions.xml, mtk_omx_core.cfg (this file is
#    inherited first, so a copy here would shadow the device's).
#  - vendor/meizu/m5c/m5c-vendor.mk: the SPM PCM files (generated, not blobs).
#
# Deliberately absent — do not re-add:
#  - hwcomposer.mt6737m.so: the device builds forge_hwc under that module
#    name.  With the blob shipped, it died in GameDetector::LayersStrategy
#    ("getPrivateHandleInfo err(fffffff9)"), SurfaceFlinger went with it and
#    system_server hung at "Starting phase 100": black screen.
#  - bin/md_ctrl: built against an older android_fork_execvp_ext; on N and
#    later it hits FORTIFY in __write_chk ("write: count > SSIZE_MAX"), init
#    respawns it and the loop ends in a watchdog reboot (WDT_STATUS
#    0x40000000 in pstore).  Nothing replaces it: LTE data and voice
#    registration work without it the bring-up notes, RIL
#    2026-09-29 02:05).
#  - bin/netdiag: MediaTek's network capture daemon (runs tcpdump on request,
#    debug.netlog.* / debug.mtklog.netlog.* in its strings).  No rc of this
#    tree starts it, and a packet logger has no place in the image.
#  - Stock builds of AOSP code, which Android 13 builds itself and installs to
#    the same vendor paths:
#      vendor/lib64/mediadrm/{libdrmclearkeyplugin,libmockdrmcryptoplugin}.so;
#      lib{,64}/hw/{audio_policy.stub,local_time.default,vibrator.default}.so
#      (2014 GCC 4.9 toolchain string and the verbatim hw_module_t .name of
#      hardware/libhardware/modules/{audio/audio_policy.c:345,
#      local_time/local_time_hw.c:108, vibrator/vibrator.c:33});
#      lib{,64}/hw/keystore.default.so (AOSP softkeymaster; its DT_NEEDED
#      libkeystore_binder and libsoftkeymaster no longer exist, so it cannot
#      even load — keystore2 is the implementation).
#    power.default.so is NOT one of them and stays: its .name is "Legacy
#    PowerHAL" (AOSP's is "Default Power HAL", power.c:59) and it drives
#    /proc/hps/power_mode and /proc/cpufreq/cpufreq_power_mode.
#  - The Widevine classic / MTK OMA DRM cluster: libwvm, libwvdrm_L3,
#    libWVStreamControlAPI_L3, drm/libdrmwvmplugin (32-bit) and
#    lib{,64}/libdrm{mtkutil,mtkwhitelist}.  Nothing outside the cluster NEEDs
#    or names any of them (readelf and strings over all of proprietary/); its
#    entry points are a drmserver plugin, which A13 loads only from
#    /system/lib/drm (frameworks/av/drm/drmserver/DrmManager.cpp:214), and
#    WVMExtractor, which A13 stagefright no longer has.  Both also NEED the
#    system-only libdrmframework, which the vendor namespace cannot load.
#
# The remaining copy/module collisions reported by the first `m nothing`
# parse are the ones where the blob is what we want:
#  the bring-up notes

PRODUCT_COPY_FILES += \
    vendor/meizu/m5c/proprietary/bin/6620_launcher:$(TARGET_COPY_OUT_VENDOR)/bin/6620_launcher \
    vendor/meizu/m5c/proprietary/bin/ccci_fsd:$(TARGET_COPY_OUT_VENDOR)/bin/ccci_fsd \
    vendor/meizu/m5c/proprietary/bin/ccci_mdinit:$(TARGET_COPY_OUT_VENDOR)/bin/ccci_mdinit \
    vendor/meizu/m5c/proprietary/bin/gsm0710muxd:$(TARGET_COPY_OUT_VENDOR)/bin/gsm0710muxd \
    vendor/meizu/m5c/proprietary/bin/muxreport:$(TARGET_COPY_OUT_VENDOR)/bin/muxreport \
    vendor/meizu/m5c/proprietary/bin/terservice:$(TARGET_COPY_OUT_VENDOR)/bin/terservice \
    vendor/meizu/m5c/proprietary/lib/libaed.so:$(TARGET_COPY_OUT_VENDOR)/lib/libaed.so \
    vendor/meizu/m5c/proprietary/lib64/libaed.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libaed.so \
    vendor/meizu/m5c/proprietary/lib/libccci_util.so:$(TARGET_COPY_OUT_VENDOR)/lib/libccci_util.so \
    vendor/meizu/m5c/proprietary/lib64/libccci_util.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libccci_util.so \
    vendor/meizu/m5c/proprietary/lib/libmdloggerrecycle.so:$(TARGET_COPY_OUT_VENDOR)/lib/libmdloggerrecycle.so \
    vendor/meizu/m5c/proprietary/lib64/libmdloggerrecycle.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libmdloggerrecycle.so \
    vendor/meizu/m5c/proprietary/lib/libmemoryDumpEncoder.so:$(TARGET_COPY_OUT_VENDOR)/lib/libmemoryDumpEncoder.so \
    vendor/meizu/m5c/proprietary/lib/libmrdump.so:$(TARGET_COPY_OUT_VENDOR)/lib/libmrdump.so \
    vendor/meizu/m5c/proprietary/lib64/libmrdump.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libmrdump.so \
    vendor/meizu/m5c/proprietary/lib64/libterservice.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libterservice.so \
    vendor/meizu/m5c/proprietary/etc/ecc_list.xml:$(TARGET_COPY_OUT_VENDOR)/etc/ecc_list.xml \
    vendor/meizu/m5c/proprietary/etc/firmware/catcher_filter_1_lwg_n.bin:$(TARGET_COPY_OUT_VENDOR)/etc/firmware/catcher_filter_1_lwg_n.bin \
    vendor/meizu/m5c/proprietary/etc/firmware/dsp_1_lwg_n.bin:$(TARGET_COPY_OUT_VENDOR)/etc/firmware/dsp_1_lwg_n.bin \
    vendor/meizu/m5c/proprietary/etc/firmware/modem_1_lwg_n.img:$(TARGET_COPY_OUT_VENDOR)/etc/firmware/modem_1_lwg_n.img \
    vendor/meizu/m5c/proprietary/etc/mddb/BPLGUInfoCustomAppSrcP_MT6735_S00_MOLY_LR9_W1444_MD_LWTG_MP_V106_P5_1_lwg_n:$(TARGET_COPY_OUT_VENDOR)/etc/mddb/BPLGUInfoCustomAppSrcP_MT6735_S00_MOLY_LR9_W1444_MD_LWTG_MP_V106_P5_1_lwg_n \
    vendor/meizu/m5c/proprietary/etc/mddb/BPMdMetaDatabase_MOLY_LR9_W1444_MD_LWTG_MP_V106_P5_1_lwg_n:$(TARGET_COPY_OUT_VENDOR)/etc/mddb/BPMdMetaDatabase_MOLY_LR9_W1444_MD_LWTG_MP_V106_P5_1_lwg_n \
    vendor/meizu/m5c/proprietary/etc/mddb/mdm_layout_desc_1_lwg_n.dat:$(TARGET_COPY_OUT_VENDOR)/etc/mddb/mdm_layout_desc_1_lwg_n.dat \
    vendor/meizu/m5c/proprietary/etc/mddb/DbgInfo_LR9.W1444.MD.LWTG.MP_HQ6737M_65_1MZ_M0_MOLY_LR9_W1444_MD_LWTG_MP_V106_P5_2017_11_02_17_46_1_lwg_n:$(TARGET_COPY_OUT_VENDOR)/etc/mddb/DbgInfo_LR9.W1444.MD.LWTG.MP_HQ6737M_65_1MZ_M0_MOLY_LR9_W1444_MD_LWTG_MP_V106_P5_2017_11_02_17_46_1_lwg_n \
    vendor/meizu/m5c/proprietary/lib/mtk-rilmd2.so:$(TARGET_COPY_OUT_VENDOR)/lib/mtk-rilmd2.so \
    vendor/meizu/m5c/proprietary/lib64/mtk-rilmd2.so:$(TARGET_COPY_OUT_VENDOR)/lib64/mtk-rilmd2.so \
    vendor/meizu/m5c/proprietary/lib/librilmtkmd2.so:$(TARGET_COPY_OUT_VENDOR)/lib/librilmtkmd2.so \
    vendor/meizu/m5c/proprietary/lib64/librilmtkmd2.so:$(TARGET_COPY_OUT_VENDOR)/lib64/librilmtkmd2.so \
    vendor/meizu/m5c/proprietary/lib/libmal.so:$(TARGET_COPY_OUT_VENDOR)/lib/libmal.so \
    vendor/meizu/m5c/proprietary/lib64/libmal.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libmal.so \
    vendor/meizu/m5c/proprietary/lib/libmal_datamngr.so:$(TARGET_COPY_OUT_VENDOR)/lib/libmal_datamngr.so \
    vendor/meizu/m5c/proprietary/lib64/libmal_datamngr.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libmal_datamngr.so \
    vendor/meizu/m5c/proprietary/lib/libmal_epdga.so:$(TARGET_COPY_OUT_VENDOR)/lib/libmal_epdga.so \
    vendor/meizu/m5c/proprietary/lib64/libmal_epdga.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libmal_epdga.so \
    vendor/meizu/m5c/proprietary/lib/libmal_mdmngr.so:$(TARGET_COPY_OUT_VENDOR)/lib/libmal_mdmngr.so \
    vendor/meizu/m5c/proprietary/lib64/libmal_mdmngr.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libmal_mdmngr.so \
    vendor/meizu/m5c/proprietary/lib/libmal_nwmngr.so:$(TARGET_COPY_OUT_VENDOR)/lib/libmal_nwmngr.so \
    vendor/meizu/m5c/proprietary/lib64/libmal_nwmngr.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libmal_nwmngr.so \
    vendor/meizu/m5c/proprietary/lib/libmal_rds.so:$(TARGET_COPY_OUT_VENDOR)/lib/libmal_rds.so \
    vendor/meizu/m5c/proprietary/lib64/libmal_rds.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libmal_rds.so \
    vendor/meizu/m5c/proprietary/lib/libmal_rilproxy.so:$(TARGET_COPY_OUT_VENDOR)/lib/libmal_rilproxy.so \
    vendor/meizu/m5c/proprietary/lib64/libmal_rilproxy.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libmal_rilproxy.so \
    vendor/meizu/m5c/proprietary/lib/libmal_simmngr.so:$(TARGET_COPY_OUT_VENDOR)/lib/libmal_simmngr.so \
    vendor/meizu/m5c/proprietary/lib64/libmal_simmngr.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libmal_simmngr.so \
    vendor/meizu/m5c/proprietary/lib/libmatv_cust.so:$(TARGET_COPY_OUT_VENDOR)/lib/libmatv_cust.so \
    vendor/meizu/m5c/proprietary/lib64/libmatv_cust.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libmatv_cust.so \
    vendor/meizu/m5c/proprietary/lib/volte_imsm.so:$(TARGET_COPY_OUT_VENDOR)/lib/volte_imsm.so \
    vendor/meizu/m5c/proprietary/lib64/volte_imsm.so:$(TARGET_COPY_OUT_VENDOR)/lib64/volte_imsm.so \
    vendor/meizu/m5c/proprietary/etc/firmware/em_filter_1_lwg_n.bin:$(TARGET_COPY_OUT_VENDOR)/etc/firmware/em_filter_1_lwg_n.bin \
    vendor/meizu/m5c/proprietary/etc/firmware/gt9xx_fw.bin:system/etc/firmware/gt9xx_fw.bin \
    vendor/meizu/m5c/proprietary/bin/akmd09911:$(TARGET_COPY_OUT_VENDOR)/bin/akmd09911 \
    vendor/meizu/m5c/proprietary/bin/akmd8963:$(TARGET_COPY_OUT_VENDOR)/bin/akmd8963 \
    vendor/meizu/m5c/proprietary/bin/akmd8975:$(TARGET_COPY_OUT_VENDOR)/bin/akmd8975 \
    vendor/meizu/m5c/proprietary/bin/ami304d:$(TARGET_COPY_OUT_VENDOR)/bin/ami304d \
    vendor/meizu/m5c/proprietary/bin/bmm050d:$(TARGET_COPY_OUT_VENDOR)/bin/bmm050d \
    vendor/meizu/m5c/proprietary/bin/geomagneticd:$(TARGET_COPY_OUT_VENDOR)/bin/geomagneticd \
    vendor/meizu/m5c/proprietary/bin/memsicd:$(TARGET_COPY_OUT_VENDOR)/bin/memsicd \
    vendor/meizu/m5c/proprietary/bin/memsicd3416x:$(TARGET_COPY_OUT_VENDOR)/bin/memsicd3416x \
    vendor/meizu/m5c/proprietary/bin/msensord:$(TARGET_COPY_OUT_VENDOR)/bin/msensord \
    vendor/meizu/m5c/proprietary/bin/orientationd:$(TARGET_COPY_OUT_VENDOR)/bin/orientationd \
    vendor/meizu/m5c/proprietary/bin/qmcX983d:$(TARGET_COPY_OUT_VENDOR)/bin/qmcX983d \
    vendor/meizu/m5c/proprietary/bin/s62xd:$(TARGET_COPY_OUT_VENDOR)/bin/s62xd \
    vendor/meizu/m5c/proprietary/lib/libhwm.so:$(TARGET_COPY_OUT_VENDOR)/lib/libhwm.so \
    vendor/meizu/m5c/proprietary/lib64/libhwm.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libhwm.so \
    vendor/meizu/m5c/proprietary/lib/hw/sensors.mt6737m.so:$(TARGET_COPY_OUT_VENDOR)/lib/hw/sensors.mt6737m.so \
    vendor/meizu/m5c/proprietary/lib64/hw/sensors.mt6737m.so:$(TARGET_COPY_OUT_VENDOR)/lib64/hw/sensors.mt6737m.so \
    vendor/meizu/m5c/proprietary/bin/mtk_agpsd:$(TARGET_COPY_OUT_VENDOR)/bin/mtk_agpsd \
    vendor/meizu/m5c/proprietary/bin/slpd:$(TARGET_COPY_OUT_VENDOR)/bin/slpd \
    vendor/meizu/m5c/proprietary/bin/wifi2agps:$(TARGET_COPY_OUT_VENDOR)/bin/wifi2agps \
    vendor/meizu/m5c/proprietary/lib/libmnl.so:$(TARGET_COPY_OUT_VENDOR)/lib/libmnl.so \
    vendor/meizu/m5c/proprietary/xbin/mnld:$(TARGET_COPY_OUT_VENDOR)/bin/mnld \
    vendor/meizu/m5c/proprietary/lib/libcurl.so:$(TARGET_COPY_OUT_VENDOR)/lib/libcurl.so \
    vendor/meizu/m5c/proprietary/etc/agps_profiles_conf2.xml:$(TARGET_COPY_OUT_VENDOR)/etc/agps_profiles_conf2.xml \
    vendor/meizu/m5c/proprietary/etc/slp_conf:system/etc/slp_conf \
    vendor/meizu/m5c/proprietary/lib/libperfservicenative.so:$(TARGET_COPY_OUT_VENDOR)/lib/libperfservicenative.so \
    vendor/meizu/m5c/proprietary/lib64/libperfservicenative.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libperfservicenative.so \
    vendor/meizu/m5c/proprietary/lib/libmtcloader.so:$(TARGET_COPY_OUT_VENDOR)/lib/libmtcloader.so \
    vendor/meizu/m5c/proprietary/lib/libfgauge.so:$(TARGET_COPY_OUT_VENDOR)/lib/libfgauge.so \
    vendor/meizu/m5c/proprietary/lib/libmtklimiter.so:$(TARGET_COPY_OUT_VENDOR)/lib/libmtklimiter.so \
    vendor/meizu/m5c/proprietary/lib64/libmtklimiter.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libmtklimiter.so \
    vendor/meizu/m5c/proprietary/lib/hw/power.default.so:$(TARGET_COPY_OUT_VENDOR)/lib/hw/power.default.so \
    vendor/meizu/m5c/proprietary/lib64/hw/power.default.so:$(TARGET_COPY_OUT_VENDOR)/lib64/hw/power.default.so \
    vendor/meizu/m5c/proprietary/etc/.tp/.ht120.mtc:$(TARGET_COPY_OUT_ODM)/etc/.ht120.mtc \
    vendor/meizu/m5c/proprietary/etc/.tp/thermal.conf:$(TARGET_COPY_OUT_ODM)/etc/thermal.conf \
    vendor/meizu/m5c/proprietary/etc/.tp/thermal.off.conf:$(TARGET_COPY_OUT_ODM)/etc/thermal.off.conf \
    vendor/meizu/m5c/proprietary/bin/nvram_daemon:$(TARGET_COPY_OUT_VENDOR)/bin/nvram_daemon \
    vendor/meizu/m5c/proprietary/lib/libcustom_nvram.so:$(TARGET_COPY_OUT_VENDOR)/lib/libcustom_nvram.so \
    vendor/meizu/m5c/proprietary/lib64/libcustom_nvram.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libcustom_nvram.so \
    vendor/meizu/m5c/proprietary/lib/libnvramagentclient.so:$(TARGET_COPY_OUT_VENDOR)/lib/libnvramagentclient.so \
    vendor/meizu/m5c/proprietary/lib64/libnvramagentclient.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libnvramagentclient.so \
    vendor/meizu/m5c/proprietary/lib/libnvram_daemon_callback.so:$(TARGET_COPY_OUT_VENDOR)/lib/libnvram_daemon_callback.so \
    vendor/meizu/m5c/proprietary/lib64/libnvram_daemon_callback.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libnvram_daemon_callback.so \
    vendor/meizu/m5c/proprietary/lib/libnvram_platform.so:$(TARGET_COPY_OUT_VENDOR)/lib/libnvram_platform.so \
    vendor/meizu/m5c/proprietary/lib64/libnvram_platform.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libnvram_platform.so \
    vendor/meizu/m5c/proprietary/lib/libnvram_sec.so:$(TARGET_COPY_OUT_VENDOR)/lib/libnvram_sec.so \
    vendor/meizu/m5c/proprietary/lib64/libnvram_sec.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libnvram_sec.so \
    vendor/meizu/m5c/proprietary/lib/libnvram.so:$(TARGET_COPY_OUT_VENDOR)/lib/libnvram.so \
    vendor/meizu/m5c/proprietary/lib64/libnvram.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libnvram.so \
    vendor/meizu/m5c/proprietary/lib/libfs_mgr.so:$(TARGET_COPY_OUT_VENDOR)/lib/libfs_mgr.so \
    vendor/meizu/m5c/proprietary/lib64/libfs_mgr.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libfs_mgr.so \
    vendor/meizu/m5c/proprietary/bin/pq:$(TARGET_COPY_OUT_VENDOR)/bin/pq \
    vendor/meizu/m5c/proprietary/lib/libblisrc32.so:$(TARGET_COPY_OUT_VENDOR)/lib/libblisrc32.so \
    vendor/meizu/m5c/proprietary/lib64/libblisrc32.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libblisrc32.so \
    vendor/meizu/m5c/proprietary/lib/libblisrc.so:$(TARGET_COPY_OUT_VENDOR)/lib/libblisrc.so \
    vendor/meizu/m5c/proprietary/lib64/libblisrc.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libblisrc.so \
    vendor/meizu/m5c/proprietary/lib/libdpframework.so:$(TARGET_COPY_OUT_VENDOR)/lib/libdpframework.so \
    vendor/meizu/m5c/proprietary/lib64/libdpframework.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libdpframework.so \
    vendor/meizu/m5c/proprietary/lib/libgas.so:$(TARGET_COPY_OUT_VENDOR)/lib/libgas.so \
    vendor/meizu/m5c/proprietary/lib64/libgas.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libgas.so \
    vendor/meizu/m5c/proprietary/lib/libged.so:$(TARGET_COPY_OUT_VENDOR)/lib/libged.so \
    vendor/meizu/m5c/proprietary/lib64/libged.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libged.so \
    vendor/meizu/m5c/proprietary/lib/libgralloc_extra.so:$(TARGET_COPY_OUT_VENDOR)/lib/libgralloc_extra.so \
    vendor/meizu/m5c/proprietary/lib64/libgralloc_extra.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libgralloc_extra.so \
    vendor/meizu/m5c/proprietary/lib/libgui_ext.so:$(TARGET_COPY_OUT_VENDOR)/lib/libgui_ext.so \
    vendor/meizu/m5c/proprietary/lib64/libgui_ext.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libgui_ext.so \
    vendor/meizu/m5c/proprietary/lib/libgpu_aux.so:$(TARGET_COPY_OUT_VENDOR)/lib/libgpu_aux.so \
    vendor/meizu/m5c/proprietary/lib64/libgpu_aux.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libgpu_aux.so \
    vendor/meizu/m5c/proprietary/lib/libion_mtk.so:$(TARGET_COPY_OUT_VENDOR)/lib/libion_mtk.so \
    vendor/meizu/m5c/proprietary/lib64/libion_mtk.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libion_mtk.so \
    vendor/meizu/m5c/proprietary/lib64/libpq_cust.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libpq_cust.so \
    vendor/meizu/m5c/proprietary/lib/libpq_prot.so:$(TARGET_COPY_OUT_VENDOR)/lib/libpq_prot.so \
    vendor/meizu/m5c/proprietary/lib64/libpq_prot.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libpq_prot.so \
    vendor/meizu/m5c/proprietary/lib/libpqservice.so:$(TARGET_COPY_OUT_VENDOR)/lib/libpqservice.so \
    vendor/meizu/m5c/proprietary/lib64/libpqservice.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libpqservice.so \
    vendor/meizu/m5c/proprietary/lib/libui_ext.so:$(TARGET_COPY_OUT_VENDOR)/lib/libui_ext.so \
    vendor/meizu/m5c/proprietary/lib64/libui_ext.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libui_ext.so \
    vendor/meizu/m5c/proprietary/lib/hw/gralloc.mt6737m.so:$(TARGET_COPY_OUT_VENDOR)/lib/hw/gralloc.mt6737m.so \
    vendor/meizu/m5c/proprietary/lib64/hw/gralloc.mt6737m.so:$(TARGET_COPY_OUT_VENDOR)/lib64/hw/gralloc.mt6737m.so \
    vendor/meizu/m5c/proprietary/lib/egl/libGLES_mali.so:$(TARGET_COPY_OUT_VENDOR)/lib/egl/libGLES_mali.so \
    vendor/meizu/m5c/proprietary/lib64/egl/libGLES_mali.so:$(TARGET_COPY_OUT_VENDOR)/lib64/egl/libGLES_mali.so \
    vendor/meizu/m5c/proprietary/bin/wmt_loader:$(TARGET_COPY_OUT_VENDOR)/bin/wmt_loader \
    vendor/meizu/m5c/proprietary/lib/libbluetooth_mtk_pure.so:$(TARGET_COPY_OUT_VENDOR)/lib/libbluetooth_mtk_pure.so \
    vendor/meizu/m5c/proprietary/lib64/libbluetooth_mtk_pure.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libbluetooth_mtk_pure.so \
    vendor/meizu/m5c/proprietary/lib/libbluetooth_relayer.so:$(TARGET_COPY_OUT_VENDOR)/lib/libbluetooth_relayer.so \
    vendor/meizu/m5c/proprietary/lib64/libbluetooth_relayer.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libbluetooth_relayer.so \
    vendor/meizu/m5c/proprietary/lib/libbluetoothem_mtk.so:$(TARGET_COPY_OUT_VENDOR)/lib/libbluetoothem_mtk.so \
    vendor/meizu/m5c/proprietary/lib64/libbluetoothem_mtk.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libbluetoothem_mtk.so \
    vendor/meizu/m5c/proprietary/lib/libbluetooth_mtk.so:$(TARGET_COPY_OUT_VENDOR)/lib/libbluetooth_mtk.so \
    vendor/meizu/m5c/proprietary/lib/libbt-vendor.so:$(TARGET_COPY_OUT_VENDOR)/lib/libbt-vendor.so \
    vendor/meizu/m5c/proprietary/lib/libfmcust.so:$(TARGET_COPY_OUT_VENDOR)/lib/libfmcust.so \
    vendor/meizu/m5c/proprietary/lib64/libfmcust.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libfmcust.so \
    vendor/meizu/m5c/proprietary/lib/hw/radio.fm.mt6737m.so:$(TARGET_COPY_OUT_VENDOR)/lib/hw/radio.fm.mt6737m.so \
    vendor/meizu/m5c/proprietary/etc/firmware/mt6627/mt6627_fm_v1_coeff.bin:system/etc/firmware/mt6627/mt6627_fm_v1_coeff.bin \
    vendor/meizu/m5c/proprietary/etc/firmware/mt6627/mt6627_fm_v1_patch.bin:system/etc/firmware/mt6627/mt6627_fm_v1_patch.bin \
    vendor/meizu/m5c/proprietary/etc/firmware/mt6627/mt6627_fm_v2_coeff.bin:system/etc/firmware/mt6627/mt6627_fm_v2_coeff.bin \
    vendor/meizu/m5c/proprietary/etc/firmware/mt6627/mt6627_fm_v2_patch.bin:system/etc/firmware/mt6627/mt6627_fm_v2_patch.bin \
    vendor/meizu/m5c/proprietary/etc/firmware/mt6627/mt6627_fm_v3_coeff.bin:system/etc/firmware/mt6627/mt6627_fm_v3_coeff.bin \
    vendor/meizu/m5c/proprietary/etc/firmware/mt6627/mt6627_fm_v3_patch.bin:system/etc/firmware/mt6627/mt6627_fm_v3_patch.bin \
    vendor/meizu/m5c/proprietary/etc/firmware/mt6627/mt6627_fm_v4_coeff.bin:system/etc/firmware/mt6627/mt6627_fm_v4_coeff.bin \
    vendor/meizu/m5c/proprietary/etc/firmware/mt6627/mt6627_fm_v4_patch.bin:system/etc/firmware/mt6627/mt6627_fm_v4_patch.bin \
    vendor/meizu/m5c/proprietary/etc/firmware/mt6627/mt6627_fm_v5_coeff.bin:system/etc/firmware/mt6627/mt6627_fm_v5_coeff.bin \
    vendor/meizu/m5c/proprietary/etc/firmware/mt6627/mt6627_fm_v5_patch.bin:system/etc/firmware/mt6627/mt6627_fm_v5_patch.bin \
    vendor/meizu/m5c/proprietary/etc/fmr/mt6627_fm_cust.cfg:system/etc/fmr/mt6627_fm_cust.cfg \
    vendor/meizu/m5c/proprietary/etc/wifi/wpa_supplicant.conf:$(TARGET_COPY_OUT_VENDOR)/etc/wifi/wpa_supplicant.conf \
    vendor/meizu/m5c/proprietary/etc/wifi/p2p_supplicant_overlay.conf:$(TARGET_COPY_OUT_VENDOR)/etc/wifi/p2p_supplicant_overlay.conf \
    vendor/meizu/m5c/proprietary/etc/wifi/wpa_supplicant_overlay.conf:$(TARGET_COPY_OUT_VENDOR)/etc/wifi/wpa_supplicant_overlay.conf \
    vendor/meizu/m5c/proprietary/lib/lib3a.so:$(TARGET_COPY_OUT_VENDOR)/lib/lib3a.so \
    vendor/meizu/m5c/proprietary/lib64/lib3a.so:$(TARGET_COPY_OUT_VENDOR)/lib64/lib3a.so \
    vendor/meizu/m5c/proprietary/lib/libcam1_utils.so:$(TARGET_COPY_OUT_VENDOR)/lib/libcam1_utils.so \
    vendor/meizu/m5c/proprietary/lib64/libcam1_utils.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libcam1_utils.so \
    vendor/meizu/m5c/proprietary/lib/libcam3_app.so:$(TARGET_COPY_OUT_VENDOR)/lib/libcam3_app.so \
    vendor/meizu/m5c/proprietary/lib64/libcam3_app.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libcam3_app.so \
    vendor/meizu/m5c/proprietary/lib/libcam3_hwnode.so:$(TARGET_COPY_OUT_VENDOR)/lib/libcam3_hwnode.so \
    vendor/meizu/m5c/proprietary/lib64/libcam3_hwnode.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libcam3_hwnode.so \
    vendor/meizu/m5c/proprietary/lib/libcam3_hwpipeline.so:$(TARGET_COPY_OUT_VENDOR)/lib/libcam3_hwpipeline.so \
    vendor/meizu/m5c/proprietary/lib64/libcam3_hwpipeline.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libcam3_hwpipeline.so \
    vendor/meizu/m5c/proprietary/lib/libcam3_pipeline.so:$(TARGET_COPY_OUT_VENDOR)/lib/libcam3_pipeline.so \
    vendor/meizu/m5c/proprietary/lib64/libcam3_pipeline.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libcam3_pipeline.so \
    vendor/meizu/m5c/proprietary/lib/libcam3_utils.so:$(TARGET_COPY_OUT_VENDOR)/lib/libcam3_utils.so \
    vendor/meizu/m5c/proprietary/lib64/libcam3_utils.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libcam3_utils.so \
    vendor/meizu/m5c/proprietary/lib/libcamalgo.so:$(TARGET_COPY_OUT_VENDOR)/lib/libcamalgo.so \
    vendor/meizu/m5c/proprietary/lib64/libcamalgo.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libcamalgo.so \
    vendor/meizu/m5c/proprietary/lib/libcam.camadapter.so:$(TARGET_COPY_OUT_VENDOR)/lib/libcam.camadapter.so \
    vendor/meizu/m5c/proprietary/lib64/libcam.camadapter.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libcam.camadapter.so \
    vendor/meizu/m5c/proprietary/lib/libcam.camshot.so:$(TARGET_COPY_OUT_VENDOR)/lib/libcam.camshot.so \
    vendor/meizu/m5c/proprietary/lib64/libcam.camshot.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libcam.camshot.so \
    vendor/meizu/m5c/proprietary/lib/libcam.client.so:$(TARGET_COPY_OUT_VENDOR)/lib/libcam.client.so \
    vendor/meizu/m5c/proprietary/lib64/libcam.client.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libcam.client.so \
    vendor/meizu/m5c/proprietary/lib/libcam.device1.so:$(TARGET_COPY_OUT_VENDOR)/lib/libcam.device1.so \
    vendor/meizu/m5c/proprietary/lib64/libcam.device1.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libcam.device1.so \
    vendor/meizu/m5c/proprietary/lib/libcam.device3.so:$(TARGET_COPY_OUT_VENDOR)/lib/libcam.device3.so \
    vendor/meizu/m5c/proprietary/lib64/libcam.device3.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libcam.device3.so \
    vendor/meizu/m5c/proprietary/lib/libcamdrv.so:$(TARGET_COPY_OUT_VENDOR)/lib/libcamdrv.so \
    vendor/meizu/m5c/proprietary/lib64/libcamdrv.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libcamdrv.so \
    vendor/meizu/m5c/proprietary/lib/libcameracustom.so:$(TARGET_COPY_OUT_VENDOR)/lib/libcameracustom.so \
    vendor/meizu/m5c/proprietary/lib64/libcameracustom.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libcameracustom.so \
    vendor/meizu/m5c/proprietary/lib/libcam.exif.so:$(TARGET_COPY_OUT_VENDOR)/lib/libcam.exif.so \
    vendor/meizu/m5c/proprietary/lib64/libcam.exif.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libcam.exif.so \
    vendor/meizu/m5c/proprietary/lib/libcam.exif.v3.so:$(TARGET_COPY_OUT_VENDOR)/lib/libcam.exif.v3.so \
    vendor/meizu/m5c/proprietary/lib64/libcam.exif.v3.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libcam.exif.v3.so \
    vendor/meizu/m5c/proprietary/lib/libcam.hal3a.v3.dng.so:$(TARGET_COPY_OUT_VENDOR)/lib/libcam.hal3a.v3.dng.so \
    vendor/meizu/m5c/proprietary/lib64/libcam.hal3a.v3.dng.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libcam.hal3a.v3.dng.so \
    vendor/meizu/m5c/proprietary/lib/libcam.hal3a.v3.so:$(TARGET_COPY_OUT_VENDOR)/lib/libcam.hal3a.v3.so \
    vendor/meizu/m5c/proprietary/lib64/libcam.hal3a.v3.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libcam.hal3a.v3.so \
    vendor/meizu/m5c/proprietary/lib/libcam.halsensor.so:$(TARGET_COPY_OUT_VENDOR)/lib/libcam.halsensor.so \
    vendor/meizu/m5c/proprietary/lib64/libcam.halsensor.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libcam.halsensor.so \
    vendor/meizu/m5c/proprietary/lib/libcam_hwutils.so:$(TARGET_COPY_OUT_VENDOR)/lib/libcam_hwutils.so \
    vendor/meizu/m5c/proprietary/lib64/libcam_hwutils.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libcam_hwutils.so \
    vendor/meizu/m5c/proprietary/lib/libcam.iopipe.so:$(TARGET_COPY_OUT_VENDOR)/lib/libcam.iopipe.so \
    vendor/meizu/m5c/proprietary/lib64/libcam.iopipe.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libcam.iopipe.so \
    vendor/meizu/m5c/proprietary/lib/libcam.metadataprovider.so:$(TARGET_COPY_OUT_VENDOR)/lib/libcam.metadataprovider.so \
    vendor/meizu/m5c/proprietary/lib64/libcam.metadataprovider.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libcam.metadataprovider.so \
    vendor/meizu/m5c/proprietary/lib/libcam.metadata.so:$(TARGET_COPY_OUT_VENDOR)/lib/libcam.metadata.so \
    vendor/meizu/m5c/proprietary/lib64/libcam.metadata.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libcam.metadata.so \
    vendor/meizu/m5c/proprietary/lib/libcam_mmp.so:$(TARGET_COPY_OUT_VENDOR)/lib/libcam_mmp.so \
    vendor/meizu/m5c/proprietary/lib64/libcam_mmp.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libcam_mmp.so \
    vendor/meizu/m5c/proprietary/lib/libcam.paramsmgr.so:$(TARGET_COPY_OUT_VENDOR)/lib/libcam.paramsmgr.so \
    vendor/meizu/m5c/proprietary/lib64/libcam.paramsmgr.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libcam.paramsmgr.so \
    vendor/meizu/m5c/proprietary/lib/libcam_platform.so:$(TARGET_COPY_OUT_VENDOR)/lib/libcam_platform.so \
    vendor/meizu/m5c/proprietary/lib64/libcam_platform.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libcam_platform.so \
    vendor/meizu/m5c/proprietary/lib/libcam.utils.sensorlistener.so:$(TARGET_COPY_OUT_VENDOR)/lib/libcam.utils.sensorlistener.so \
    vendor/meizu/m5c/proprietary/lib64/libcam.utils.sensorlistener.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libcam.utils.sensorlistener.so \
    vendor/meizu/m5c/proprietary/lib/libcam_utils.so:$(TARGET_COPY_OUT_VENDOR)/lib/libcam_utils.so \
    vendor/meizu/m5c/proprietary/lib64/libcam_utils.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libcam_utils.so \
    vendor/meizu/m5c/proprietary/lib/libcam.utils.so:$(TARGET_COPY_OUT_VENDOR)/lib/libcam.utils.so \
    vendor/meizu/m5c/proprietary/lib64/libcam.utils.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libcam.utils.so \
    vendor/meizu/m5c/proprietary/lib/libfeatureiodrv.so:$(TARGET_COPY_OUT_VENDOR)/lib/libfeatureiodrv.so \
    vendor/meizu/m5c/proprietary/lib64/libfeatureiodrv.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libfeatureiodrv.so \
    vendor/meizu/m5c/proprietary/lib/libfeatureio.so:$(TARGET_COPY_OUT_VENDOR)/lib/libfeatureio.so \
    vendor/meizu/m5c/proprietary/lib64/libfeatureio.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libfeatureio.so \
    vendor/meizu/m5c/proprietary/lib/libfile_op.so:$(TARGET_COPY_OUT_VENDOR)/lib/libfile_op.so \
    vendor/meizu/m5c/proprietary/lib64/libfile_op.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libfile_op.so \
    vendor/meizu/m5c/proprietary/lib/libimageio_plat_drv.so:$(TARGET_COPY_OUT_VENDOR)/lib/libimageio_plat_drv.so \
    vendor/meizu/m5c/proprietary/lib64/libimageio_plat_drv.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libimageio_plat_drv.so \
    vendor/meizu/m5c/proprietary/lib/libimageio.so:$(TARGET_COPY_OUT_VENDOR)/lib/libimageio.so \
    vendor/meizu/m5c/proprietary/lib64/libimageio.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libimageio.so \
    vendor/meizu/m5c/proprietary/lib/libJpgDecPipe.so:$(TARGET_COPY_OUT_VENDOR)/lib/libJpgDecPipe.so \
    vendor/meizu/m5c/proprietary/lib/libSwJpgCodec.so:$(TARGET_COPY_OUT_VENDOR)/lib/libSwJpgCodec.so \
    vendor/meizu/m5c/proprietary/lib/libJpgEncPipe.so:$(TARGET_COPY_OUT_VENDOR)/lib/libJpgEncPipe.so \
    vendor/meizu/m5c/proprietary/lib64/libJpgEncPipe.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libJpgEncPipe.so \
    vendor/meizu/m5c/proprietary/lib/libmhalImageCodec.so:$(TARGET_COPY_OUT_VENDOR)/lib/libmhalImageCodec.so \
    vendor/meizu/m5c/proprietary/lib/libmtkcamera_client.so:$(TARGET_COPY_OUT_VENDOR)/lib/libmtkcamera_client.so \
    vendor/meizu/m5c/proprietary/lib64/libmtkcamera_client.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libmtkcamera_client.so \
    vendor/meizu/m5c/proprietary/lib/libmtkjpeg.so:$(TARGET_COPY_OUT_VENDOR)/lib/libmtkjpeg.so \
    vendor/meizu/m5c/proprietary/lib64/libmtkjpeg.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libmtkjpeg.so \
    vendor/meizu/m5c/proprietary/lib/hw/camera.mt6737m.so:$(TARGET_COPY_OUT_VENDOR)/lib/hw/camera.mt6737m.so \
    vendor/meizu/m5c/proprietary/lib64/hw/camera.mt6737m.so:$(TARGET_COPY_OUT_VENDOR)/lib64/hw/camera.mt6737m.so \
    vendor/meizu/m5c/proprietary/lib/libacdk.so:$(TARGET_COPY_OUT_VENDOR)/lib/libacdk.so \
    vendor/meizu/m5c/proprietary/lib64/libacdk.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libacdk.so \
    vendor/meizu/m5c/proprietary/lib/libmeizucamera.so:$(TARGET_COPY_OUT_VENDOR)/lib/libmeizucamera.so \
    vendor/meizu/m5c/proprietary/lib64/libmeizucamera.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libmeizucamera.so \
    vendor/meizu/m5c/proprietary/lib/libcamdrv_FrmB.so:$(TARGET_COPY_OUT_VENDOR)/lib/libcamdrv_FrmB.so \
    vendor/meizu/m5c/proprietary/lib64/libcamdrv_FrmB.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libcamdrv_FrmB.so \
    vendor/meizu/m5c/proprietary/lib/libcam.iopipe_FrmB.so:$(TARGET_COPY_OUT_VENDOR)/lib/libcam.iopipe_FrmB.so \
    vendor/meizu/m5c/proprietary/lib64/libcam.iopipe_FrmB.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libcam.iopipe_FrmB.so \
    vendor/meizu/m5c/proprietary/lib/libcam.sdkclient.so:$(TARGET_COPY_OUT_VENDOR)/lib/libcam.sdkclient.so \
    vendor/meizu/m5c/proprietary/lib64/libcam.sdkclient.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libcam.sdkclient.so \
    vendor/meizu/m5c/proprietary/lib/libimageio_plat_drv_FrmB.so:$(TARGET_COPY_OUT_VENDOR)/lib/libimageio_plat_drv_FrmB.so \
    vendor/meizu/m5c/proprietary/lib64/libimageio_plat_drv_FrmB.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libimageio_plat_drv_FrmB.so \
    vendor/meizu/m5c/proprietary/lib/libimageio_FrmB.so:$(TARGET_COPY_OUT_VENDOR)/lib/libimageio_FrmB.so \
    vendor/meizu/m5c/proprietary/lib64/libimageio_FrmB.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libimageio_FrmB.so \
    vendor/meizu/m5c/proprietary/lib/libcam.common.meizu.so:$(TARGET_COPY_OUT_VENDOR)/lib/libcam.common.meizu.so \
    vendor/meizu/m5c/proprietary/lib64/libcam.common.meizu.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libcam.common.meizu.so \
    vendor/meizu/m5c/proprietary/lib/libcam.common.meizu.platform.so:$(TARGET_COPY_OUT_VENDOR)/lib/libcam.common.meizu.platform.so \
    vendor/meizu/m5c/proprietary/lib64/libcam.common.meizu.platform.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libcam.common.meizu.platform.so \
    vendor/meizu/m5c/proprietary/lib/libcam.campipe.so:$(TARGET_COPY_OUT_VENDOR)/lib/libcam.campipe.so \
    vendor/meizu/m5c/proprietary/lib64/libcam.campipe.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libcam.campipe.so \
    vendor/meizu/m5c/proprietary/lib/libvfb_render.so:$(TARGET_COPY_OUT_VENDOR)/lib/libvfb_render.so \
    vendor/meizu/m5c/proprietary/lib64/libvfb_render.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libvfb_render.so \
    vendor/meizu/m5c/proprietary/lib/libvmp_render.so:$(TARGET_COPY_OUT_VENDOR)/lib/libvmp_render.so \
    vendor/meizu/m5c/proprietary/lib64/libvmp_render.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libvmp_render.so \
    vendor/meizu/m5c/proprietary/lib/libmpbase.so:$(TARGET_COPY_OUT_VENDOR)/lib/libmpbase.so \
    vendor/meizu/m5c/proprietary/lib64/libmpbase.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libmpbase.so \
    vendor/meizu/m5c/proprietary/lib/libarcsoft_makeup.so:$(TARGET_COPY_OUT_VENDOR)/lib/libarcsoft_makeup.so \
    vendor/meizu/m5c/proprietary/lib64/libarcsoft_makeup.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libarcsoft_makeup.so \
    vendor/meizu/m5c/proprietary/lib/libmakeup_style.so:$(TARGET_COPY_OUT_VENDOR)/lib/libmakeup_style.so \
    vendor/meizu/m5c/proprietary/lib64/libmakeup_style.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libmakeup_style.so \
    vendor/meizu/m5c/proprietary/lib/libfilter_effects.so:$(TARGET_COPY_OUT_VENDOR)/lib/libfilter_effects.so \
    vendor/meizu/m5c/proprietary/lib64/libfilter_effects.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libfilter_effects.so \
    vendor/meizu/m5c/proprietary/lib/libhdrproc.so:$(TARGET_COPY_OUT_VENDOR)/lib/libhdrproc.so \
    vendor/meizu/m5c/proprietary/lib64/libhdrproc.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libhdrproc.so \
    vendor/meizu/m5c/proprietary/lib/libmmsdkservice.so:$(TARGET_COPY_OUT_VENDOR)/lib/libmmsdkservice.so \
    vendor/meizu/m5c/proprietary/lib64/libmmsdkservice.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libmmsdkservice.so \
    vendor/meizu/m5c/proprietary/lib/libmmsdkservice.feature.so:$(TARGET_COPY_OUT_VENDOR)/lib/libmmsdkservice.feature.so \
    vendor/meizu/m5c/proprietary/lib64/libmmsdkservice.feature.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libmmsdkservice.feature.so \
    vendor/meizu/m5c/proprietary/lib/libja3m.so:$(TARGET_COPY_OUT_VENDOR)/lib/libja3m.so \
    vendor/meizu/m5c/proprietary/lib64/libja3m.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libja3m.so \
    vendor/meizu/m5c/proprietary/lib64/libJpgDecPipe.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libJpgDecPipe.so \
    vendor/meizu/m5c/proprietary/lib/libexif.so:$(TARGET_COPY_OUT_VENDOR)/lib/libexif.so \
    vendor/meizu/m5c/proprietary/lib64/libexif.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libexif.so \
    vendor/meizu/m5c/proprietary/lib/libavformat.so:$(TARGET_COPY_OUT_VENDOR)/lib/libavformat.so \
    vendor/meizu/m5c/proprietary/lib64/libavformat.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libavformat.so \
    vendor/meizu/m5c/proprietary/lib/libexif_gallery.so:$(TARGET_COPY_OUT_VENDOR)/lib/libexif_gallery.so \
    vendor/meizu/m5c/proprietary/lib64/libexif_gallery.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libexif_gallery.so \
    vendor/meizu/m5c/proprietary/lib/libjhead.so:$(TARGET_COPY_OUT_VENDOR)/lib/libjhead.so \
    vendor/meizu/m5c/proprietary/lib64/libjhead.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libjhead.so \
    vendor/meizu/m5c/proprietary/lib/libfilterfw.so:$(TARGET_COPY_OUT_VENDOR)/lib/libfilterfw.so \
    vendor/meizu/m5c/proprietary/lib64/libfilterfw.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libfilterfw.so \
    vendor/meizu/m5c/proprietary/lib/liba3m.so:$(TARGET_COPY_OUT_VENDOR)/lib/liba3m.so \
    vendor/meizu/m5c/proprietary/lib64/liba3m.so:$(TARGET_COPY_OUT_VENDOR)/lib64/liba3m.so \
    vendor/meizu/m5c/proprietary/lib/libaudiocompensationfilter.so:$(TARGET_COPY_OUT_VENDOR)/lib/libaudiocompensationfilter.so \
    vendor/meizu/m5c/proprietary/lib64/libaudiocompensationfilter.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libaudiocompensationfilter.so \
    vendor/meizu/m5c/proprietary/lib/libaudiocomponentengine.so:$(TARGET_COPY_OUT_VENDOR)/lib/libaudiocomponentengine.so \
    vendor/meizu/m5c/proprietary/lib64/libaudiocomponentengine.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libaudiocomponentengine.so \
    vendor/meizu/m5c/proprietary/lib/libaudiocustparam.so:$(TARGET_COPY_OUT_VENDOR)/lib/libaudiocustparam.so \
    vendor/meizu/m5c/proprietary/lib64/libaudiocustparam.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libaudiocustparam.so \
    vendor/meizu/m5c/proprietary/lib/libbessound_hd_mtk.so:$(TARGET_COPY_OUT_VENDOR)/lib/libbessound_hd_mtk.so \
    vendor/meizu/m5c/proprietary/lib64/libbessound_hd_mtk.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libbessound_hd_mtk.so \
    vendor/meizu/m5c/proprietary/lib/libbwc.so:$(TARGET_COPY_OUT_VENDOR)/lib/libbwc.so \
    vendor/meizu/m5c/proprietary/lib64/libbwc.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libbwc.so \
    vendor/meizu/m5c/proprietary/lib/libcvsd_mtk.so:$(TARGET_COPY_OUT_VENDOR)/lib/libcvsd_mtk.so \
    vendor/meizu/m5c/proprietary/lib64/libcvsd_mtk.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libcvsd_mtk.so \
    vendor/meizu/m5c/proprietary/lib/libHEVCdec_sa.ca7.android.so:$(TARGET_COPY_OUT_VENDOR)/lib/libHEVCdec_sa.ca7.android.so \
    vendor/meizu/m5c/proprietary/lib/libm4u.so:$(TARGET_COPY_OUT_VENDOR)/lib/libm4u.so \
    vendor/meizu/m5c/proprietary/lib64/libm4u.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libm4u.so \
    vendor/meizu/m5c/proprietary/lib/libmdfx.so:$(TARGET_COPY_OUT_VENDOR)/lib/libmdfx.so \
    vendor/meizu/m5c/proprietary/lib64/libmdfx.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libmdfx.so \
    vendor/meizu/m5c/proprietary/lib/libmmprofile.so:$(TARGET_COPY_OUT_VENDOR)/lib/libmmprofile.so \
    vendor/meizu/m5c/proprietary/lib64/libmmprofile.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libmmprofile.so \
    vendor/meizu/m5c/proprietary/lib/libmp4enc_sa.ca7.so:$(TARGET_COPY_OUT_VENDOR)/lib/libmp4enc_sa.ca7.so \
    vendor/meizu/m5c/proprietary/lib/libmsbc_mtk.so:$(TARGET_COPY_OUT_VENDOR)/lib/libmsbc_mtk.so \
    vendor/meizu/m5c/proprietary/lib64/libmsbc_mtk.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libmsbc_mtk.so \
    vendor/meizu/m5c/proprietary/lib/libmtk_drvb.so:$(TARGET_COPY_OUT_VENDOR)/lib/libmtk_drvb.so \
    vendor/meizu/m5c/proprietary/lib64/libmtk_drvb.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libmtk_drvb.so \
    vendor/meizu/m5c/proprietary/lib/libmtk_mmutils.so:$(TARGET_COPY_OUT_VENDOR)/lib/libmtk_mmutils.so \
    vendor/meizu/m5c/proprietary/lib64/libmtk_mmutils.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libmtk_mmutils.so \
    vendor/meizu/m5c/proprietary/lib/libmtkshifter.so:$(TARGET_COPY_OUT_VENDOR)/lib/libmtkshifter.so \
    vendor/meizu/m5c/proprietary/lib64/libmtkshifter.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libmtkshifter.so \
    vendor/meizu/m5c/proprietary/lib/libspeech_enh_lib.so:$(TARGET_COPY_OUT_VENDOR)/lib/libspeech_enh_lib.so \
    vendor/meizu/m5c/proprietary/lib64/libspeech_enh_lib.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libspeech_enh_lib.so \
    vendor/meizu/m5c/proprietary/lib/libstagefrighthw.so:$(TARGET_COPY_OUT_VENDOR)/lib/libstagefrighthw.so \
    vendor/meizu/m5c/proprietary/lib64/libstagefrighthw.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libstagefrighthw.so \
    vendor/meizu/m5c/proprietary/lib/libvc1dec_sa.ca7.so:$(TARGET_COPY_OUT_VENDOR)/lib/libvc1dec_sa.ca7.so \
    vendor/meizu/m5c/proprietary/lib/libvcodec_oal.so:$(TARGET_COPY_OUT_VENDOR)/lib/libvcodec_oal.so \
    vendor/meizu/m5c/proprietary/lib64/libvcodec_oal.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libvcodec_oal.so \
    vendor/meizu/m5c/proprietary/lib/libvcodec_utility.so:$(TARGET_COPY_OUT_VENDOR)/lib/libvcodec_utility.so \
    vendor/meizu/m5c/proprietary/lib64/libvcodec_utility.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libvcodec_utility.so \
    vendor/meizu/m5c/proprietary/lib/libvp8dec_sa.ca7.so:$(TARGET_COPY_OUT_VENDOR)/lib/libvp8dec_sa.ca7.so \
    vendor/meizu/m5c/proprietary/lib/libvp9dec_sa.ca7.so:$(TARGET_COPY_OUT_VENDOR)/lib/libvp9dec_sa.ca7.so \
    vendor/meizu/m5c/proprietary/lib/hw/audio.a2dp.default.so:$(TARGET_COPY_OUT_VENDOR)/lib/hw/audio.a2dp.default.so \
    vendor/meizu/m5c/proprietary/lib64/hw/audio.a2dp.default.so:$(TARGET_COPY_OUT_VENDOR)/lib64/hw/audio.a2dp.default.so \
    vendor/meizu/m5c/proprietary/lib/libaudiodcrflt.so:$(TARGET_COPY_OUT_VENDOR)/lib/libaudiodcrflt.so \
    vendor/meizu/m5c/proprietary/lib64/libaudiodcrflt.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libaudiodcrflt.so \
    vendor/meizu/m5c/proprietary/lib/libaudiomtkdcremoval.so:$(TARGET_COPY_OUT_VENDOR)/lib/libaudiomtkdcremoval.so \
    vendor/meizu/m5c/proprietary/lib/libwebrtc_audio_preprocessing.so:$(TARGET_COPY_OUT_VENDOR)/lib/libwebrtc_audio_preprocessing.so \
    vendor/meizu/m5c/proprietary/lib64/libwebrtc_audio_preprocessing.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libwebrtc_audio_preprocessing.so \
    vendor/meizu/m5c/proprietary/lib/libaudiosetting.so:$(TARGET_COPY_OUT_VENDOR)/lib/libaudiosetting.so \
    vendor/meizu/m5c/proprietary/lib64/libaudiosetting.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libaudiosetting.so \
    vendor/meizu/m5c/proprietary/lib/libMtkOmxAdpcmDec.so:$(TARGET_COPY_OUT_VENDOR)/lib/libMtkOmxAdpcmDec.so \
    vendor/meizu/m5c/proprietary/lib/libMtkOmxAdpcmEnc.so:$(TARGET_COPY_OUT_VENDOR)/lib/libMtkOmxAdpcmEnc.so \
    vendor/meizu/m5c/proprietary/lib/libMtkOmxAlacDec.so:$(TARGET_COPY_OUT_VENDOR)/lib/libMtkOmxAlacDec.so \
    vendor/meizu/m5c/proprietary/lib/libMtkOmxApeDec.so:$(TARGET_COPY_OUT_VENDOR)/lib/libMtkOmxApeDec.so \
    vendor/meizu/m5c/proprietary/lib/libMtkOmxFlacDec.so:$(TARGET_COPY_OUT_VENDOR)/lib/libMtkOmxFlacDec.so \
    vendor/meizu/m5c/proprietary/lib/libMtkOmxG711Dec.so:$(TARGET_COPY_OUT_VENDOR)/lib/libMtkOmxG711Dec.so \
    vendor/meizu/m5c/proprietary/lib/libMtkOmxGsmDec.so:$(TARGET_COPY_OUT_VENDOR)/lib/libMtkOmxGsmDec.so \
    vendor/meizu/m5c/proprietary/lib/libMtkOmxMp3Dec.so:$(TARGET_COPY_OUT_VENDOR)/lib/libMtkOmxMp3Dec.so \
    vendor/meizu/m5c/proprietary/lib/libMtkOmxRawDec.so:$(TARGET_COPY_OUT_VENDOR)/lib/libMtkOmxRawDec.so \
    vendor/meizu/m5c/proprietary/lib/libMtkOmxVdecEx.so:$(TARGET_COPY_OUT_VENDOR)/lib/libMtkOmxVdecEx.so \
    vendor/meizu/m5c/proprietary/lib/libMtkOmxVenc.so:$(TARGET_COPY_OUT_VENDOR)/lib/libMtkOmxVenc.so \
    vendor/meizu/m5c/proprietary/lib/libMtkOmxVorbisEnc.so:$(TARGET_COPY_OUT_VENDOR)/lib/libMtkOmxVorbisEnc.so \
    vendor/meizu/m5c/proprietary/lib64/libmhalImageCodec.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libmhalImageCodec.so \
    vendor/meizu/m5c/proprietary/lib64/libSwJpgCodec.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libSwJpgCodec.so \
    vendor/meizu/m5c/proprietary/lib/libBnMtkCodec.so:$(TARGET_COPY_OUT_VENDOR)/lib/libBnMtkCodec.so \
    vendor/meizu/m5c/proprietary/lib64/libBnMtkCodec.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libBnMtkCodec.so \
    vendor/meizu/m5c/proprietary/lib/libvcodec_cap.so:$(TARGET_COPY_OUT_VENDOR)/lib/libvcodec_cap.so \
    vendor/meizu/m5c/proprietary/lib64/libvcodec_cap.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libvcodec_cap.so \
    vendor/meizu/m5c/proprietary/lib/libh264enc_sa.ca7.so:$(TARGET_COPY_OUT_VENDOR)/lib/libh264enc_sa.ca7.so \
    vendor/meizu/m5c/proprietary/lib64/libh264enc_sa.ca7.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libh264enc_sa.ca7.so \
    vendor/meizu/m5c/proprietary/lib/libh264enc_sb.ca7.so:$(TARGET_COPY_OUT_VENDOR)/lib/libh264enc_sb.ca7.so \
    vendor/meizu/m5c/proprietary/lib/libmp4enc_xa.ca7.so:$(TARGET_COPY_OUT_VENDOR)/lib/libmp4enc_xa.ca7.so \
    vendor/meizu/m5c/proprietary/lib/libem_bt_jni.so:$(TARGET_COPY_OUT_VENDOR)/lib/libem_bt_jni.so \
    vendor/meizu/m5c/proprietary/lib64/libem_bt_jni.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libem_bt_jni.so \
    vendor/meizu/m5c/proprietary/lib/libem_gpio_jni.so:$(TARGET_COPY_OUT_VENDOR)/lib/libem_gpio_jni.so \
    vendor/meizu/m5c/proprietary/lib64/libem_gpio_jni.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libem_gpio_jni.so \
    vendor/meizu/m5c/proprietary/lib/libem_lte_jni.so:$(TARGET_COPY_OUT_VENDOR)/lib/libem_lte_jni.so \
    vendor/meizu/m5c/proprietary/lib64/libem_lte_jni.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libem_lte_jni.so \
    vendor/meizu/m5c/proprietary/lib/libem_modem_jni.so:$(TARGET_COPY_OUT_VENDOR)/lib/libem_modem_jni.so \
    vendor/meizu/m5c/proprietary/lib64/libem_modem_jni.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libem_modem_jni.so \
    vendor/meizu/m5c/proprietary/lib/libem_sensor_jni.so:$(TARGET_COPY_OUT_VENDOR)/lib/libem_sensor_jni.so \
    vendor/meizu/m5c/proprietary/lib64/libem_sensor_jni.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libem_sensor_jni.so \
    vendor/meizu/m5c/proprietary/lib/libem_support_jni.so:$(TARGET_COPY_OUT_VENDOR)/lib/libem_support_jni.so \
    vendor/meizu/m5c/proprietary/lib64/libem_support_jni.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libem_support_jni.so \
    vendor/meizu/m5c/proprietary/lib/libem_usb_jni.so:$(TARGET_COPY_OUT_VENDOR)/lib/libem_usb_jni.so \
    vendor/meizu/m5c/proprietary/lib64/libem_usb_jni.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libem_usb_jni.so \
    vendor/meizu/m5c/proprietary/lib/libem_wifi_jni.so:$(TARGET_COPY_OUT_VENDOR)/lib/libem_wifi_jni.so \
    vendor/meizu/m5c/proprietary/lib64/libem_wifi_jni.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libem_wifi_jni.so \
    vendor/meizu/m5c/proprietary/bin/meta_tst:$(TARGET_COPY_OUT_VENDOR)/bin/meta_tst \
    vendor/meizu/m5c/proprietary/etc/factory.ini:$(TARGET_COPY_OUT_VENDOR)/etc/factory.ini \
    vendor/meizu/m5c/proprietary/lib64/libminiui.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libminiui.so \
    vendor/meizu/m5c/proprietary/res/sound/ringtone.wav:$(TARGET_COPY_OUT_VENDOR)/res/sound/ringtone.wav \
    vendor/meizu/m5c/proprietary/lib/hw/lights.mt6737m.so:$(TARGET_COPY_OUT_VENDOR)/lib/hw/lights.mt6737m.so \
    vendor/meizu/m5c/proprietary/lib64/hw/lights.mt6737m.so:$(TARGET_COPY_OUT_VENDOR)/lib64/hw/lights.mt6737m.so \
    vendor/meizu/m5c/proprietary/lib/hw/memtrack.mt6737m.so:$(TARGET_COPY_OUT_VENDOR)/lib/hw/memtrack.mt6737m.so \
    vendor/meizu/m5c/proprietary/lib64/hw/memtrack.mt6737m.so:$(TARGET_COPY_OUT_VENDOR)/lib64/hw/memtrack.mt6737m.so \
    vendor/meizu/m5c/proprietary/etc/perfservscntbl.txt:$(TARGET_COPY_OUT_VENDOR)/etc/perfservscntbl.txt \
    vendor/meizu/m5c/proprietary/etc/trustzone.bin:$(TARGET_COPY_OUT_VENDOR)/etc/trustzone.bin \
    vendor/meizu/m5c/proprietary/etc/firmware/ROMv2_lm_patch_1_0_hdr.bin:system/etc/firmware/ROMv2_lm_patch_1_0_hdr.bin \
    vendor/meizu/m5c/proprietary/etc/firmware/ROMv2_lm_patch_1_1_hdr.bin:system/etc/firmware/ROMv2_lm_patch_1_1_hdr.bin \
    vendor/meizu/m5c/proprietary/etc/firmware/WIFI_RAM_CODE_6735:system/etc/firmware/WIFI_RAM_CODE_6735 \
    vendor/meizu/m5c/proprietary/etc/firmware/WMT_SOC.cfg:system/etc/firmware/WMT_SOC.cfg \
    vendor/meizu/m5c/proprietary/vendor/etc/dirac_types.xml:$(TARGET_COPY_OUT_VENDOR)/etc/dirac_types.xml \
    vendor/meizu/m5c/proprietary/vendor/etc/diracmobile.config:$(TARGET_COPY_OUT_VENDOR)/etc/diracmobile.config \
    vendor/meizu/m5c/proprietary/vendor/etc/pdc.txt:$(TARGET_COPY_OUT_VENDOR)/etc/pdc.txt

# Full Treble: the ELFs of treble-elf-wiring.txt are installed by
# vendor/meizu/m5c/Android.mk (rule m5c-treble-blob: DT_NEEDED wired to the
# shims), not copied as they are.  Drop their plain copies here — the copy
# rules come later in the build than Android.mk and would override the
# wired ones.  This node's PRODUCT_COPY_FILES holds only the lines above.
M5C_ELF_WIRED := $(shell sed -n 's/^\([^#[:space:]][^[:space:]]*\).*/\1/p' vendor/meizu/m5c/treble-elf-wiring.txt)
PRODUCT_COPY_FILES := $(filter-out $(foreach f,$(M5C_ELF_WIRED),vendor/meizu/m5c/proprietary/$(f):%),$(PRODUCT_COPY_FILES))
