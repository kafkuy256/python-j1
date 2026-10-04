#!/system/bin/sh
# Post-install setup. Run this after flashing new firmware, which wipes
# /data/local/tmp (the interpreter) and the changes made to /system
# (the PATH symlinks and /etc/resolv.conf).
#
#   adb push pyhome /data/local/tmp/
#   adb push py /data/local/tmp/py
#   adb push device/setup.sh /data/local/tmp/
#   adb shell "su -c 'chmod 755 /data/local/tmp/py'"
#   adb shell "su -c 'sh /data/local/tmp/setup.sh'"
#
# Nothing here is specific to a particular firmware; DNS is taken from the
# net.dns1 property so it follows whatever router the phone is on.

PY=/data/local/tmp/py
PYHOME=/data/local/tmp/pyhome

echo "== 1. interpreter =="
ls -l "$PY" "$PYHOME/bin/python3" "$PYHOME/bin/python3.11"
"$PY" -V

echo
echo "== 2. python/python3/py on PATH =="
mount -o remount,rw /system
for name in python python3 py; do
    rm -f "/system/bin/$name"
    ln -s "$PY" "/system/bin/$name"
done
mount -o remount,ro /system
ls -l /system/bin/python /system/bin/python3 /system/bin/py

echo
echo "== 3. /etc/resolv.conf for musl =="
DNS=$(getprop net.dns1)
[ -z "$DNS" ] && DNS=$(getprop net.dns2)
if [ -z "$DNS" ]; then
    echo "   WARNING: no DNS server in net.dns1/net.dns2, skipping"
else
    mount -o remount,rw /system
    echo "nameserver $DNS" > /system/etc/resolv.conf
    chmod 644 /system/etc/resolv.conf
    mount -o remount,ro /system
    echo "   nameserver $DNS"
fi
cat /etc/resolv.conf

echo
echo "== 4. TLS certificate bundle =="
CACERTS=/system/etc/security/cacerts
BUNDLE="$PYHOME/ssl/cert.pem"
if [ -d "$CACERTS" ]; then
    mkdir -p "$PYHOME/ssl"
    cat "$CACERTS"/*.0 > "$BUNDLE"
    chmod 755 "$PYHOME/ssl"
    chmod 644 "$BUNDLE"
    echo "   $(ls -l "$BUNDLE")"
else
    echo "   WARNING: $CACERTS not found"
fi

echo
echo "== 5. /sdcard =="
ls -l /sdcard
echo "   (/sdcard -> $(readlink /sdcard))"
if ! ls /sdcard > /dev/null 2>&1 && [ ! -d /storage/self/primary ]; then
    echo "   /sdcard looks unusable; see device/sdcard.sh"
fi

echo
echo "== 6. smoke test =="
"$PY" -c 'import math,struct,socket,select,json,random,datetime,hashlib,zlib,subprocess,threading'
echo "   imports OK"
"$PY" -c 'import socket; print("   dns:", socket.gethostbyname("example.com"))'
"$PY" -c 'import ssl,urllib.request; r=urllib.request.urlopen("https://example.com/",timeout=20); print("   https:", r.status)'

echo
echo "== done =="