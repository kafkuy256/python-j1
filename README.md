# python-j1

Static **CPython 3.11.17** for the **Samsung Galaxy J1 mini (SM-J105H)**:
ARMv7 32-bit, Android 5.1, musl libc, hard-float, one self-contained binary
with every C extension compiled in (no `dlopen`, no `.so` files, no second
Python install).

Everything is cross-compiled in GitHub Actions on `ubuntu-22.04`; nothing is
built on Windows and no Python app is installed on the phone.

## Build

```
gh workflow run build.yml
gh run watch
```

| stage | what |
|---|---|
| toolchain | `cross-tools/musl-cross` release `20261001`, `armv7-unknown-linux-musleabihf` (fallbacks: Bootlin `armv7-eabihf` musl, then musl.cc) |
| CPython | 3.11.17, host interpreter of the same version built for `--with-build-python` |
| deps | zlib 1.3.2, OpenSSL 3.0.22, SQLite 3.53.4 — all cross-built as static `.a` for the same target |

Key flags:

```
--host=armv7-linux-musleabihf  --disable-shared  --without-ensurepip
--prefix=/data/local/tmp/pyhome  --with-build-python=<host python>
ac_cv_file__dev_ptmx=yes  ac_cv_file__dev_ptc=no  ac_cv_buggy_getaddrinfo=no
LDFLAGS="-static -no-pie"
```

The tool names are normalised to `armv7-linux-musleabihf-*` through symlinks so
the workflow works with any of the three toolchains.

### All modules are static

A static binary has no `dlopen`, so every extension is linked straight into the
interpreter. `Modules/Setup.local` (section `*static*`) lists 60+ modules
including `math`, `_struct`, `_socket`, `select`, `binascii`, `zlib`,
`_random`, `_datetime`, `_json`, `_ssl`, `_hashlib`, `_sqlite3`,
`unicodedata`, `pyexpat` and `_multiprocessing`. The result is 85 builtin
modules and no `lib-dynload` content.

Not built (they need libraries that would be pointless on this device):
`ctypes`, `curses`, `tkinter`, `readline`, `bz2`, `lzma`, `crypt`, `uuid`,
`gdbm`.

## Install on the phone

```
adb push pyhome /data/local/tmp/
adb push py /data/local/tmp/py
adb push device/setup.sh /data/local/tmp/
adb shell "su -c 'chmod 755 /data/local/tmp/py /data/local/tmp/setup.sh'"
adb shell "su -c 'sh /data/local/tmp/setup.sh'"
```

`setup.sh` does the three things that live outside `/data/local/tmp` and are
therefore lost on every firmware flash: the `python`/`python3`/`py` symlinks in
`/system/bin`, `/etc/resolv.conf` for musl (DNS is taken from the `net.dns1`
property, so it follows whatever router the phone is on), and the TLS
certificate bundle. It finishes with a smoke test.

Individual pieces, if you need them:

| script | what it does |
|---|---|
| `device/setup.sh` | everything below, plus a smoke test |
| `device/python-links.sh` | only the `/system/bin` symlinks |
| `device/dns.sh` | only `/etc/resolv.conf` (router address hard-coded) |
| `device/sdcard.sh` | bind mount, only needed if `/sdcard` is a dead link |

## Run

```
adb shell "su -c '/data/local/tmp/py /sdcard/script.py'"
adb shell "/data/local/tmp/py -c 'print(1+1)'"
```

`py` is only a launcher: it sets `PYTHONHOME`, `HOME`, `TMPDIR`, `PYTHONUTF8=1`,
builds the CA bundle on first run, then `exec`s `pyhome/bin/python3.11`.

## Running files the usual way

After `python-links.sh` the phone behaves like a normal Linux box:

```
adb shell                              # shell user
cd /storage/emulated/0
python3 script.py arg1                 # python / py also work
python3 -c 'print(1+1)'
python3 -m json.tool < data.json
python3                                # interactive REPL
```

Standard semantics apply, verified on the device:

* `sys.path[0]` is the script's folder, so `import sibling` works for modules
  next to the script;
* `__file__` and `sys.argv` are normal;
* a relative `open("data.txt")` resolves against the **current directory**,
  exactly like on Linux and Windows — so either `cd` to the script first or use
  `os.path.dirname(__file__)`.

### `./script.py`

Android's kernel cannot use a shell script as a `#!/...` interpreter, so a
plain `#!/data/local/tmp/py` header does not work. Use a four-line
sh/Python polyglot instead — copy the header from
[`device/script-template.py`](device/script-template.py):

```python
#!/system/bin/sh
""":"
exec /data/local/tmp/py "$0" "$@"
":"""
# ordinary Python from here on
```

Then:

```
adb push script.py /storage/emulated/0/
adb shell "su -c 'chmod 755 /storage/emulated/0/script.py'"
adb shell "su -c 'cd /storage/emulated/0 && ./script.py'"
```

This works from `/data` and from `/sdcard`, keeps full arguments, and gets the
complete environment. (`chmod +x` is required — that is the Linux rule too.)

## Device notes

**DNS.** musl only reads `/etc/resolv.conf`, which Android 5.1 does not ship
(`/etc` is a symlink to the read-only `/system/etc`). Create it once:

```
adb shell "su -c 'sh /data/local/tmp/dns.sh'"     # remount,rw /system + write the file
```

Use the **router's** address (`getprop net.dns1`, here `192.168.0.1`).
Public resolvers do not answer on this network — UDP/53 to `8.8.8.8` and
`1.1.1.1` is filtered. Undo with `rm /system/etc/resolv.conf` plus
`mount -o remount,ro /system`.

**Certificates.** Android's CA files are named with a hash format OpenSSL 3.x
does not match when it walks a `capath`, so the launcher concatenates them into
`pyhome/ssl/cert.pem` — the name OpenSSL was configured with via
`--openssldir` — and exports `SSL_CERT_FILE`. With that,
`ssl.create_default_context()` verifies normally (TLS 1.3, HTTP 200 verified),
and even the bare `pyhome/bin/python3.11` works with no environment at all.

**Run your own scripts.**

```
adb shell "su -c '/data/local/tmp/py /sdcard/myscript.py arg1 arg2'"
adb shell "/data/local/tmp/py /sdcard/myscript.py"          # shell user, subprocess works
adb shell "su -c 'sh /data/local/tmp/t.py'"                  # interactive-ish
```

Use `/sdcard` only after running `device/sdcard.sh` (see below), otherwise
point at `/storage/emulated/0/myscript.py`.

**`/sdcard` is a dead symlink on this ROM.** It lives in the read-only
initramfs rootfs and points at `/storage/emulated/legacy`, which has mode `000`
because Android 5.1 legacy storage is off, so `adb push x /sdcard/` and any
app's `/sdcard/...` access fails. The symlink cannot be edited, so
`device/sdcard.sh` bind-mounts the real volume over the path it points at.
Nothing on disk changes; it must be re-run after each reboot:

```
adb shell "su -c 'sh /data/local/tmp/sdcard.sh'"      # umount to undo
```

**Root vs. `shell`.** This ROM's SELinux policy denies `execve` to processes
running in the `init` domain that SuperSU gives you, so under `su` **any**
`subprocess` call fails with `PermissionError: [Errno 13]` — including
`os.execv` of Python's own binary. Everything else (threads, sockets, ssl,
sqlite3, file I/O) works as root. Run as the `shell` user instead if you need
`subprocess`:

```
adb shell "/data/local/tmp/py /sdcard/myscript.py"      # subprocess works
```

**Time zones.** Android has no `zoneinfo` tree and `tzdata` is not installed,
so `zoneinfo` and `time.localtime()` only know UTC.
