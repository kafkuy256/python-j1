#!/system/bin/sh
# Put `python`, `python3` and `py` on PATH so scripts can be started the usual
# way ("python3 script.py") from any shell instead of typing the full path.
#
# /system/bin is in the default PATH and the symlinks are written into the
# ext4 image, so this survives reboots (the rw mount is only needed once).
# Undo with: rm /system/bin/python /system/bin/python3 /system/bin/py

set -e

PY=/data/local/tmp/py

echo "-- before --"
mount | grep ' /system '
ls -l /system/bin/python /system/bin/python3 /system/bin/py 2>&1 || true

echo "-- make /system writable --"
mount -o remount,rw /system

echo "-- link --"
for name in python python3 py; do
    rm -f "/system/bin/$name"
    ln -s "$PY" "/system/bin/$name"
done
ls -l /system/bin/python /system/bin/python3 /system/bin/py

echo "-- put /system back read-only --"
mount -o remount,ro /system
mount | grep ' /system '

echo "-- done --"
