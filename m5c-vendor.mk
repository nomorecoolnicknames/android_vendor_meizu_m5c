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

# Entry point of the m5c vendor tree, inherited by device/meizu/m5c/device.mk.
# Maintained by hand (there is no setup-makefiles.sh for this tree).

$(call inherit-product, vendor/meizu/m5c/m5c-vendor-blobs.mk)

# SPM PCM code for the forge 4.9 kernel, loaded by request_firmware when
# /dev/spm is opened (device/meizu/m5c init.m5c.power.rc).  Generated from the
# GPL arrays of the m5c 3.18 kernel, not a proprietary blob: firmware/spm/README.
PRODUCT_COPY_FILES += \
    vendor/meizu/m5c/firmware/spm/pcm_suspend_2.bin:$(TARGET_COPY_OUT_VENDOR)/firmware/pcm_suspend_2.bin \
    vendor/meizu/m5c/firmware/spm/pcm_sodi_2.bin:$(TARGET_COPY_OUT_VENDOR)/firmware/pcm_sodi_2.bin \
    vendor/meizu/m5c/firmware/spm/pcm_deepidle_2.bin:$(TARGET_COPY_OUT_VENDOR)/firmware/pcm_deepidle_2.bin \
    vendor/meizu/m5c/firmware/spm/pcm_vcore_dvfs_2.bin:$(TARGET_COPY_OUT_VENDOR)/firmware/pcm_vcore_dvfs_2.bin
