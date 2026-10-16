# gps.mt6737m — MTK Gen-N legacy GPS HAL (hardware/gps.h), from the working
# 14.1 tree via LOS 16 of this device (los16-ct07 device/meizu/m5c/gps/gps_hal,
# 379ae87; source unchanged).  Talks to the Gen-N mnld blob over the abstract
# sockets mtk_hal2mnl / mtk_mnl2hal.
#
# Android 13 (2026-09-28): same module.  FACT (A13, set 9): the 64-bit
# android.hardware.gnss@1.0-service restarted every 5 s with
# "gnss hw_get_module gps failed: -2" — no gps.mt6737m on /vendor.  The
# sources compile against the A13 headers for both ABIs with the global
# -Werror= set of build/soong/cc/config/global.go (clang-r450784d
# -fsyntax-only, 0 errors); what remains are the MTK warnings below.
# Guarded: Make sees every Android.mk of the workspace.  Included from
# vendor/meizu/m5c/Android.mk (moved from device/meizu/m5c/gps/gps_hal on
# 2026-09-30: MediaTek-proprietary sources stay out of the device tree).
ifeq ($(TARGET_DEVICE),m5c)
LOCAL_PATH := $(call my-dir)

include $(CLEAR_VARS)

LOCAL_MODULE_RELATIVE_PATH := hw
LOCAL_PROPRIETARY_MODULE := true
LOCAL_SHARED_LIBRARIES := \
		liblog \
		libcutils \
		libhardware

LOCAL_C_INCLUDES += \
      $(LOCAL_PATH)/inc \
      $(LOCAL_PATH)/inc/hardware \

# MTK 2016 sources: cutils/log.h is deprecated in Pie (#warning), unused
# parameters throughout. Keep them warnings.
LOCAL_CFLAGS += -Wno-error -Wno-unused-parameter -Wno-unused-variable

LOCAL_SRC_FILES += \
	    src/hal2mnl_interface.c \
		  src/hal_mnl_interface_common.c \
		  src/data_coder.c \
		  src/mtk_lbs_utility.c \
		  src/agpsinf.c \
		  src/gpshal.c \
		  src/gpshal_worker.c \
		  src/gpsinf.c \

LOCAL_MODULE := gps.$(TARGET_BOARD_PLATFORM)

LOCAL_MODULE_TAGS := optional

include $(BUILD_SHARED_LIBRARY)

endif
