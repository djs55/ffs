#!/usr/bin/env python

import json
import os
import shutil
import tempfile


class TestFFSPath:
    path = None
    dummy_volumes = []

    def __enter__(self, testvolume_count=0):
        self.path = tempfile.mkdtemp()
        for x in range(0, testvolume_count):
            self.create_test_volume()
        return self

    def __exit__(self, type, value, traceback):
        shutil.rmtree(self.path)

    def get_uri(self):
        return "file://" + self.path

    test_volume_data = {"uuid": "testuuid",
                        "name": "testname",
                        "description": "testdescription",
                        "keys": {"testkey1": "testvalue1",
                                 "testkey2": "testvalue2"}}

    def create_test_volume(self):
        volume_path = tempfile.mkstemp(dir=self.path)[1]
        with open(volume_path, 'wb') as fout:
            content = os.urandom(1024)
            fout.write(content)
        with open(volume_path + ".json", "wb") as fout:
            fout.write(json.dumps(self.test_volume_data))
        return os.path.basename(volume_path)
