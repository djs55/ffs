#!/usr/bin/env python

import sys
import xapi
import subprocess


def log(txt):
    print >>sys.stderr, txt

# [call dbg cmd_args] executes [cmd_args]
# if [error] and a non-zero exit code, log and throws a BackendError
# if [simple], returns only stdout


def call(dbg, cmd_args, error=True, simple=True):
    p = subprocess.Popen(
        cmd_args,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        close_fds=True)
    stdout, stderr = p.communicate()
    if error and p.returncode != 0:
        log("%s: %s exitted with code %d: %s" %
            (dbg, " ".join(cmd_args), p.returncode, stderr))
        raise xapi.InternalError("%s exitted with non-zero code %d: %s"
                                 % (" ".join(cmd_args), p.returncode, stderr))
    if simple:
        return stdout
    return stdout, stderr, p.returncode
