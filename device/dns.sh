#!/system/bin/sh
# Make musl's resolver work: Android 5.1 ships no /etc/resolv.conf and /etc
# is a symlink to /system/etc, which is mounted read-only.
# Undo with: rm /system/etc/resolv.conf && mount -o remount,ro /system

set -e

echo "-- before --"
mount | grep ' /system ' || true
ls -l /etc

echo "-- remount /system rw --"
mount -o remount,rw /system
mount | grep ' /system ' || true

echo "-- write resolv.conf --"
echo "nameserver 192.168.0.1" > /system/etc/resolv.conf
chmod 644 /system/etc/resolv.conf
cat /system/etc/resolv.conf
ls -l /system/etc/resolv.conf
ls -l /etc/resolv.conf

echo "-- done --"
