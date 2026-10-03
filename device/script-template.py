#!/system/bin/sh
""":"
exec /data/local/tmp/py "$0" "$@"
":"""
# -*- coding: utf-8 -*-
# Template for a script you want to start directly, like ./script.py on Linux.
#
#   adb push script.py /storage/emulated/0/
#   adb shell "su -c 'chmod 755 /storage/emulated/0/script.py'"
#   adb shell "su -c 'cd /storage/emulated/0 && ./script.py arg1'"
#
# The first three lines are the important part: they make this file a valid
# /system/bin/sh script *and* a valid Python module, so the phone's kernel can
# start it and it still runs through the full launcher (PYTHONHOME, UTF-8,
# TLS certificates, HOME). Delete them and use `python3 script.py` instead.

import sys


def main():
    print("args:", sys.argv[1:])
    print("script:", __file__)
    print("folder on sys.path:", sys.path[0])
    print("привет")


if __name__ == "__main__":
    main()
