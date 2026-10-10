#!/system/bin/sh
# Post-install setup. Run this after flashing new firmware, which wipes
# /data/local/tmp (the interpreter) and the changes made to /system
# (the PATH symlinks and /etc/resolv.conf).
#
#   adb push pyhome /data/local/tmp/
#   adb push py /data/local/tmp/py
#   adb push device/setup.sh /data/local/tmp/
#   adb shell "su -c 'chmod 755 /data/local/tmp/py /data/local/tmp/setup.sh'"
#   adb shell "su -c 'sh /data/local/tmp/setup.sh'"
#
# Handles both layouts: Android 9 and older mount /system separately, Android 10
# with system-as-root mounts it at /.

PY=/data/local/tmp/py
PYHOME=/data/local/tmp/pyhome

# Remount the read-only system partition writable (or back to read-only).
# /system is its own mount up to Android 9; on Android 10 system-as-root it is
# the root mount instead.
sys_mount() {
    if mount -o "remount,$1" /system 2>/dev/null; then
        SYS_MP=/system
    elif mount -o "remount,$1" / 2>/dev/null; then
        SYS_MP=/
    else
        echo "   ERROR: could not remount the system partition ($1)"
        return 1
    fi
}

# Android dropped net.dns1 around Android 8, so fall back to the DHCP
# properties and then to the default gateway -- on a home router those are
# the same machine anyway.
find_dns() {
    for p in net.dns1 net.dns2 dhcp.wlan0.dns1 dhcp.eth0.dns1; do
        d=$(getprop "$p" 2>/dev/null)
        case "$d" in
            ""|null) ;;
            *) echo "$d"; return ;;
        esac
    done
    for t in wlan0 rmnet0 eth0; do
        g=$(ip route show table "$t" 2>/dev/null | sed -n 's/^default via \([0-9][0-9.]*\).*/\1/p')
        if [ -n "$g" ]; then
            echo "$g"
            return
        fi
    done
    ip route show default 2>/dev/null | sed -n 's/^default via \([0-9][0-9.]*\).*/\1/p'
}

echo "== 1. interpreter =="
ls -l "$PY" "$PYHOME/bin/python3" "$PYHOME/bin/python3.11"
"$PY" -V

echo
echo "== 2. python/python3/py/pip on PATH =="
sys_mount rw
for name in python python3 py; do
    rm -f "/system/bin/$name"
    ln -s "$PY" "/system/bin/$name"
done
for name in pip pip3; do
    rm -f "/system/bin/$name"
    printf '#!/system/bin/sh\nexec %s -m pip "$@"\n' "$PY" > "/system/bin/$name"
    chmod 755 "/system/bin/$name"
done
sys_mount ro
ls -l /system/bin/python /system/bin/python3 /system/bin/py /system/bin/pip

echo
echo "== 3. /etc/resolv.conf for musl =="
DNS=$(find_dns)
if [ -z "$DNS" ]; then
    echo "   WARNING: no DNS server found, skipping."
    echo "            is the phone on Wi-Fi or mobile data? Re-run this later."
else
    sys_mount rw
    echo "nameserver $DNS" > /system/etc/resolv.conf
    chmod 644 /system/etc/resolv.conf
    sys_mount ro
    echo "   nameserver $DNS"
fi
cat /etc/resolv.conf 2>/dev/null

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
echo "== 5. pip and the time zone database =="
# Needs the network (DNS + TLS). If the phone is offline but /data/local/tmp/wheels
# holds the wheels pushed from a PC, those are used instead.
if "$PY" -m pip --version > /dev/null 2>&1; then
    echo "   pip: $("$PY" -m pip --version)"
elif [ -d /data/local/tmp/wheels ]; then
    echo "   installing pip from the local wheels ..."
    W=$(ls /data/local/tmp/wheels/pip-*.whl 2>/dev/null | sed -n 1p)
    "$PY" "$W/pip" install --no-index --find-links /data/local/tmp/wheels \
        pip setuptools wheel packaging tzdata 2>&1 | tail -3
else
    echo "   installing pip via get-pip.py ..."
    if "$PY" -c 'import urllib.request; urllib.request.urlretrieve("https://bootstrap.pypa.io/get-pip.py","/data/local/tmp/get-pip.py")' 2>/dev/null; then
        "$PY" /data/local/tmp/get-pip.py --no-warn-script-location 2>&1 | tail -3
        rm -f /data/local/tmp/get-pip.py
        "$PY" -m pip install --no-warn-script-location tzdata 2>&1 | tail -2
    else
        echo "   WARNING: no network and no wheels in /data/local/tmp/wheels"
    fi
fi
ZONEINFO="$PYHOME/lib/python3.11/site-packages/tzdata/zoneinfo"
if [ ! -d "$ZONEINFO" ]; then
    "$PY" -m pip install --no-warn-script-location --find-links /data/local/tmp/wheels tzdata 2>&1 | tail -2
fi
if [ -d "$ZONEINFO" ]; then
    echo "   tzdata: $("$PY" -c 'import tzdata; print(tzdata.IANA_VERSION)')"
    if [ ! -r /data/local/tmp/tz ]; then
        echo "Europe/Moscow" > /data/local/tmp/tz
        chmod 644 /data/local/tmp/tz
    fi
    echo "   zone:   $(cat /data/local/tmp/tz)"
else
    echo "   WARNING: tzdata not installed"
fi

echo
echo "== 6. /sdcard =="
ls -l /sdcard
echo "   (/sdcard -> $(readlink /sdcard))"
if [ "$(readlink /sdcard)" = "/storage/emulated/legacy" ]; then
    echo "   /sdcard points at the disabled legacy volume; run device/sdcard.sh"
fi

echo
echo "== 7. smoke test =="
"$PY" -c 'import math,struct,socket,select,json,random,datetime,hashlib,zlib,subprocess,threading'
echo "   imports OK"
"$PY" -c 'import socket; print("   dns:", socket.gethostbyname("example.com"))'
"$PY" -c 'import ssl,urllib.request; r=urllib.request.urlopen("https://example.com/",timeout=20); print("   https:", r.status)'
"$PY" -c 'import time,datetime; from zoneinfo import ZoneInfo; print("   localtime:", time.strftime("%Y-%m-%d %H:%M:%S %Z")); print("   zoneinfo: ", datetime.datetime.now(ZoneInfo("Europe/Moscow")).strftime("%Y-%m-%d %H:%M %Z%z"))'
"$PY" -c 'import subprocess; print("   subprocess:", subprocess.check_output(["id"]).decode().strip())' 2>&1 | tail -1

echo
echo "== done =="