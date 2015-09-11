#!/usr/bin/env python

import errno
from xapi.storage import log
import os
import xapi
import subprocess


# Attempts to create an empty regular file with the given prefix and suffix
# If the name "prefix.suffix" exists, this will try "prefix.%d.suffix" until
# a unique name has been found. Suffix may be an empty string.


def touch_file_unique(dbg, prefix, suffix, mode=0644):
    if suffix.startswith("."):
        suffix = suffix[1:]
    counter = 0
    unique = prefix
    while True:
        try:
            if counter > 0:
                unique = "%s.%d" % (prefix, counter)
            if suffix != "":
                unique = "%s.%s" % (unique, suffix)
            fd = os.open(unique, os.O_CREAT | os.O_EXCL | os.O_WRONLY, mode)
            os.close(fd)
            break
        except OSError as e:
            if e.errno != errno.EEXIST:
                raise
            counter = counter + 1
    return unique
