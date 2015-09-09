#!/usr/bin/env python

import errno
import log
import os
import xapi
import subprocess


# [call dbg cmd_args] executes [cmd_args]
# if [error] and exit code != expRc, log and throws a BackendError
# if [simple], returns only stdout


def call(dbg, cmd_args, error=True, simple=True, expRc=0):
    log.debug("%s: Running cmd %s" % (dbg, cmd_args))
    p = subprocess.Popen(
        cmd_args,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        close_fds=True)
    stdout, stderr = p.communicate()
    if error and p.returncode != expRc:
        log.error("%s: %s exitted with code %d: %s" %
                  (dbg, " ".join(cmd_args), p.returncode, stderr))
        raise xapi.InternalError("%s exitted with non-zero code %d: %s"
                                 % (" ".join(cmd_args), p.returncode, stderr))
    if simple:
        return stdout
    return stdout, stderr, p.returncode


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
