#!/system/bin/sh
# On this ROM /sdcard is a symlink that lives in the read-only initramfs
# rootfs and points at /storage/emulated/legacy, which has mode 000 because
# Android 5.1 legacy storage is switched off. Result: `adb push x /sdcard/`
# and `python /sdcard/script.py` both fail for *any* app, not just Python.
#
# The symlink cannot be edited (rootfs is ro and lives in RAM), so bind the
# real volume over the path it points at instead. Nothing on disk changes;
# this is runtime-only and has to be re-run after every reboot.
#
# Undo: umount /storage/emulated/legacy

echo "-- before --"
ls -ld /storage/emulated/legacy /storage/emulated/0

echo "-- bind mount --"
mount -o bind /storage/emulated/0 /storage/emulated/legacy
echo "rc=$?"
mount | grep legacy

echo "-- after --"
ls -ld /storage/emulated/legacy
echo "/sdcard now points at the real internal storage"

echo "-- done --"
