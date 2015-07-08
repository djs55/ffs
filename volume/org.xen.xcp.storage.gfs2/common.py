#!/usr/bin/env python

# For a block device /a/b/c, we will mount it at <mountpoint_root>/a/b/c
mountpoint_root = "/var/run/sr-mount/"

# FIXME FIXME FIXME FIXME FIXME
class Lock():
    def __init__(self, lock_path):
        self.lock_path = lock_path
    def __enter__(self):
        return self.lock_path
    def __exit__(self, type, value, traceback):
        return
