# python-j1

Static CPython **3.11.17** for the **Samsung Galaxy J1 mini (SM-J105H)**:
ARMv7 32-bit, Android 5.1, musl libc, hard float, one self-contained binary
with every C extension linked in (no `dlopen`, no `.so` files).

Built entirely in GitHub Actions on `ubuntu-22.04`.

## Build

```
gh workflow run build.yml
gh run watch
```

The workflow cross-compiles with `armv7l-linux-musleabihf` (musl.cc) and also
builds zlib, OpenSSL and SQLite as static libraries for the same target.
The result is uploaded as an artifact `python-j1-<ver>-armv7l-musl`.

## Install on the phone

```
adb push pyhome /data/local/tmp/
adb push py /data/local/tmp/py
adb shell "su -c 'chmod 755 /data/local/tmp/pyhome/bin/python3 /data/local/tmp/py'"
```

## Run

```
adb shell "su -c '/data/local/tmp/py /sdcard/script.py'"
adb shell "su -c '/data/local/tmp/py -c \"print(1+1)\"'"
```

`py` is only a wrapper: it sets `PYTHONHOME`, `HOME`, `TMPDIR`, `PYTHONUTF8=1`
and then execs `pyhome/bin/python3`.

## Notes

* Python was configured with `--disable-shared`, so `pyhome/lib/python3.11`
  contains only the stdlib and no extension modules.
* DNS resolution needs `/etc/resolv.conf`, which Android 5.1 does not ship.
  See `device/resolv.conf` notes in the task history.
* `zoneinfo` needs a `tzdata` tree or the `tzdata` PyPI package; Android has
  none, so only UTC is available through `time`.
