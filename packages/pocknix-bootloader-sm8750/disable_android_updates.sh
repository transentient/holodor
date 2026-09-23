#!/bin/sh

# Turn off AYN's Android system update app. An Android update on a dual-boot device
# replaces the bootloader on one slot and broke Android on our test device.
# Undo with enable_android_updates.sh.

pm disable com.odin.fota
