#!/usr/bin/env python

import errno
import json
import uuid
import urlparse
import os
import os.path
import subprocess
import sys
import xapi.storage.api.volume
from xapi.storage import log
import ffs.poolhelper
from ffs.common import touch_file_unique


class Implementation(xapi.storage.api.volume.Volume_skeleton):

    def clone(self, dbg, sr, key):
        u = urlparse.urlparse(sr)
        if not(os.path.isdir(u.path)):
            raise xapi.storage.api.volume.Sr_not_attached(sr)
        path = os.path.join(u.path, key)
        if not(os.path.exists(path)):
            raise xapi.storage.api.volume.Volume_does_not_exist(path)
        new_name = touch_file_unique(dbg, path, "")

        # both cp --reflink and cp may require that the image is quiesced
        ffs.poolhelper.suspend_datapath_in_pool(dbg, path)
        try:
            code = subprocess.call(["cp", "--reflink=always", path, new_name])
            if code != 0:
                code = subprocess.call(["cp", path, new_name])
                if code != 0:
                    os.unlink(new_name)
                    raise xapi.storage.api.volume.Unimplemented("Copy failed?")
        finally:
            ffs.poolhelper.resume_datapath_in_pool(dbg, path)

        key = os.path.basename(new_name)
        uuid_ = str(uuid.uuid4())
        name = key
        description = ""
        keys = {}
        if os.path.exists(path + ".json"):
            with open(path + ".json", "r") as fd:
                js = json.load(fd)
                name = js["name"]
                description = js["description"]
        meta = {
            "uuid": uuid_,
            "name": name,
            "description": description,
            "keys": keys
        }
        with open(new_name + ".json", "w") as json_fd:
            json.dump(meta, json_fd)
            json_fd.write("\n")

        stat = os.stat(new_name)
        size = stat.st_size
        return {
            "key": key,
            "uuid": uuid_,
            "name": name,
            "description": description,
            "read_write": True,
            "virtual_size": size,
            "physical_utilisation": 0,
            "uri": ["raw+file://" + new_name],
            "keys": {}
        }

    def create(self, dbg, sr, name, description, size):
        # [djs55/xapi-storage#33]
        size = int(size)

        u = urlparse.urlparse(sr)
        if not(os.path.isdir(u.path)):
            raise xapi.storage.api.volume.Sr_not_attached(sr)
        # sanitise characters used in the volume name
        sanitised = ""
        for c in name:
            if c == os.sep or c in [
                    "<",
                    ">",
                    ":",
                    "\"",
                    "/",
                    "\"",
                    "|",
                    "?",
                    "*"]:
                sanitised = sanitised + "_"
            else:
                sanitised = sanitised + c
        if sanitised == "":
            sanitised = "unknown"
        # attempt to create a key based on the name
        counter = 0
        path = None
        key = None
        fd = None
        while key is None:
            try:
                filename = sanitised
                if counter > 0:
                    filename = "%s.%d" % (sanitised, counter)
                path = os.path.join(u.path, filename)
                fd = os.open(path, os.O_CREAT | os.O_EXCL | os.O_WRONLY)
                key = filename
            except OSError as e:
                if e.errno != errno.EEXIST:
                    raise
                counter = counter + 1

        uuid_ = str(uuid.uuid4())
        meta = {
            "uuid": uuid_,
            "name": name,
            "description": description,
            "keys": {}
        }
        with open(path + ".json", "w") as json_fd:
            json.dump(meta, json_fd)
            json_fd.write("\n")

        if size > 0:
            os.lseek(fd, size - 1, os.SEEK_SET)
            os.write(fd, "\000")
        os.close(fd)
        stat = os.stat(path)
        virtual_size = stat.st_size
        physical_utilisation = stat.st_blocks * 512
        return {
            "key": key,
            "uuid": uuid_,
            "name": name,
            "description": description,
            "read_write": True,
            "virtual_size": virtual_size,
            "physical_utilisation": physical_utilisation,
            "uri": ["raw+file://" + path],
            "keys": {},
        }

    def destroy(self, dbg, sr, key):
        u = urlparse.urlparse(sr)
        if not(os.path.isdir(u.path)):
            raise xapi.storage.api.volume.Sr_not_attached(sr)
        path = os.path.join(u.path, key)
        if os.path.exists(path):
            os.unlink(path)
        if os.path.exists(path + ".json"):
            os.unlink(path + ".json")
        return

    def resize(self, dbg, sr, key, new_size):
        new_size = int(new_size)
        u = urlparse.urlparse(sr)
        path = os.path.join(u.path, key)
        if not(os.path.exists(path)):
            raise xapi.storage.api.volume.Volume_does_not_exist(key)
        size = os.stat(path).st_size
        if new_size < size:
            raise xapi.storage.api.volume.Unimplemented("Shrinking is not supported")
        elif new_size == size:
            # No action needed
            pass
        elif new_size > size:
            # Expand the virtual disk
            try:
                fd = os.open(path, os.O_EXCL | os.O_WRONLY)
                os.lseek(fd, new_size - 1, os.SEEK_SET)
                os.write(fd, "\000")
                os.close(fd)
            except OSError:
                # ToDo: we ought to raise something more meaningful here
                raise
        return None

    def set(self, dbg, sr, key, k, v):
        u = urlparse.urlparse(sr)
        if not(os.path.isdir(u.path)):
            raise xapi.storage.api.volume.Sr_not_attached(sr)
        path = os.path.join(u.path, key)

        uuid_ = None
        name = ""
        description = ""
        keys = {}
        if os.path.exists(path + ".json"):
            with open(path + ".json", "r") as json_fd:
                js = json.load(json_fd)
                uuid_ = js["uuid"]
                name = js["name"]
                description = js["description"]
                keys = js["keys"]

        keys[k] = v

        meta = {
            "uuid": uuid_,
            "name": name,
            "description": description,
            "keys": keys
        }
        with open(path + ".json", "w") as json_fd:
            json.dump(meta, json_fd)
            json_fd.write("\n")

        return None

    def set_description(self, dbg, sr, key, new_description):
        u = urlparse.urlparse(sr)
        if not(os.path.isdir(u.path)):
            raise xapi.storage.api.volume.Sr_not_attached(sr)
        path = os.path.join(u.path, key)

        uuid_ = None
        name = ""
        description = ""
        keys = {}
        if os.path.exists(path + ".json"):
            with open(path + ".json", "r") as json_fd:
                js = json.load(json_fd)
                uuid_ = js["uuid"]
                name = js["name"]
                description = js["description"]
                keys = js["keys"]

        description = new_description

        meta = {
            "uuid": uuid_,
            "name": name,
            "description": description,
            "keys": keys
        }
        with open(path + ".json", "w") as json_fd:
            json.dump(meta, json_fd)
            json_fd.write("\n")

        return None

    def set_name(self, dbg, sr, key, new_name):
        u = urlparse.urlparse(sr)
        if not(os.path.isdir(u.path)):
            raise xapi.storage.api.volume.Sr_not_attached(sr)
        path = os.path.join(u.path, key)

        uuid_ = None
        name = ""
        description = ""
        keys = {}
        if os.path.exists(path + ".json"):
            with open(path + ".json", "r") as json_fd:
                js = json.load(json_fd)
                uuid_ = js["uuid"]
                name = js["name"]
                description = js["description"]
                keys = js["keys"]

        name = new_name

        meta = {
            "uuid": uuid_,
            "name": name,
            "description": description,
            "keys": keys
        }
        with open(path + ".json", "w") as json_fd:
            json.dump(meta, json_fd)
            json_fd.write("\n")

        return None

    def snapshot(self, dbg, sr, key):
        u = urlparse.urlparse(sr)
        if not(os.path.isdir(u.path)):
            raise xapi.storage.api.volume.Sr_not_attached(sr)
        path = os.path.join(u.path, key)
        if not(os.path.exists(path)):
            raise xapi.storage.api.volume.Volume_does_not_exist(path)
        new_name = touch_file_unique(dbg, path, "")

        # both cp --reflink and cp may require that the image is quiesced
        ffs.poolhelper.suspend_datapath_in_pool(dbg, path)
        try:
            code = subprocess.call(["cp", "--reflink=always", path, new_name])
            if code != 0:
                code = subprocess.call(["cp", path, new_name])
                if code != 0:
                    os.unlink(new_name)
                    raise xapi.storage.api.volume.Unimplemented("Copy failed?")
        finally:
            ffs.poolhelper.resume_datapath_in_pool(dbg, path)

        key = os.path.basename(new_name)
        uuid_ = str(uuid.uuid4())
        name = key
        description = ""
        keys = {}
        if os.path.exists(path + ".json"):
            with open(path + ".json", "r") as fd:
                js = json.load(fd)
                name = js["name"]
                description = js["description"]
        meta = {
            "uuid": uuid_,
            "name": name,
            "description": description,
            "keys": keys
        }
        with open(new_name + ".json", "w") as json_fd:
            json.dump(meta, json_fd)
            json_fd.write("\n")

        stat = os.stat(new_name)
        size = stat.st_size
        return {
            "key": key,
            "uuid": uuid_,
            "name": name,
            "description": description,
            "read_write": True,
            "virtual_size": size,
            "physical_utilisation": 0,
            "uri": ["raw+file://" + new_name],
            "keys": {}
        }

    def stat(self, dbg, sr, key):
        u = urlparse.urlparse(sr)
        path = os.path.join(u.path, key)
        if not(os.path.exists(path)):
            raise xapi.storage.api.volume.Volume_does_not_exist(key)
        stat = os.stat(path)
        virtual_size = stat.st_size
        physical_utilisation = stat.st_blocks * 512
        uuid_ = None
        name = key
        description = key
        keys = {}
        if os.path.exists(path + ".json"):
            with open(path + ".json", "r") as fd:
                js = json.load(fd)
                uuid_ = js["uuid"]
                name = js["name"]
                description = js["description"]
                keys = js["keys"]
        if uuid_ is None:
            uuid_ = str(uuid.uuid4())
        return {
            "key": key,
            "uuid": uuid_,
            "name": name,
            "description": description,
            "read_write": True,
            "virtual_size": virtual_size,
            "physical_utilisation": physical_utilisation,
            "uri": ["raw+file://" + path],
            "keys": keys
        }

    def unset(self, dbg, sr, key, k):
        u = urlparse.urlparse(sr)
        if not(os.path.isdir(u.path)):
            raise xapi.storage.api.volume.Sr_not_attached(sr)
        path = os.path.join(u.path, key)

        uuid_ = None
        name = ""
        description = ""
        keys = {}
        if os.path.exists(path + ".json"):
            with open(path + ".json", "r") as json_fd:
                js = json.load(json_fd)
                uuid_ = js["uuid"]
                name = js["name"]
                description = js["description"]
                keys = js["keys"]

        del keys[k]

        meta = {
            "uuid": uuid_,
            "name": name,
            "description": description,
            "keys": keys
        }
        with open(path + ".json", "w") as json_fd:
            json.dump(meta, json_fd)
            json_fd.write("\n")

        return None

if __name__ == "__main__":
    log.log_call_argv()
    cmd = xapi.storage.api.volume.Volume_commandline(Implementation())
    base = os.path.basename(sys.argv[0])
    if base == "Volume.clone":
        cmd.clone()
    elif base == "Volume.create":
        cmd.create()
    elif base == "Volume.destroy":
        cmd.destroy()
    elif base == "Volume.resize":
        cmd.resize()
    elif base == "Volume.set":
        cmd.set()
    elif base == "Volume.set_description":
        cmd.set_description()
    elif base == "Volume.set_name":
        cmd.set_name()
    elif base == "Volume.snapshot":
        cmd.snapshot()
    elif base == "Volume.stat":
        cmd.stat()
    elif base == "Volume.unset":
        cmd.unset()
    else:
        raise xapi.storage.api.volume.Unimplemented(base)
