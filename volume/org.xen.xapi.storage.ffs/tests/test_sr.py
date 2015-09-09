import mock
import os
import sys
import unittest
import util
from . import TestSrnotattachedexception

sys.path.append(os.path.join(os.path.dirname(__file__), '..'))
import sr


class test_sr(unittest.TestCase):

    def test_attach_returns_uri(self):
        dbg = mock.Mock()
        uri = "file:///magic/ffs/path"

        attach_result = sr.Implementation().attach(dbg, uri)

        self.assertEqual(attach_result, uri)

    def test_create_returns_none(self):
        dbg = mock.Mock()
        uri = "file:///magic/ffs/path"
        name = "testname"
        description = "testdescription"
        configuration = {}

        create_result = sr.Implementation().create(
            dbg,
            uri,
            name,
            description,
            configuration)

        self.assertEquals(create_result, None)

    def test_destroy_returns_None(self):
        dbg = mock.Mock()
        uri = "file:///magic/ffs/path"

        destroy_result = sr.Implementation().destroy(dbg, uri)

        self.assertEquals(destroy_result, None)

    def test_sr_detach_returns_None(self):
        dbg = mock.Mock()
        uri = "file:///magic/ffs/path"

        detach_result = sr.Implementation().detach(dbg, uri)

        self.assertEquals(detach_result, None)

    def test_sr_ls_raises_sr_not_attached(self):
        dbg = mock.Mock()
        uri = "file:///magic/nonexistent/ffs/path"

        with self.assertRaises(TestSrnotattachedexception):

            sr.Implementation().ls(dbg, uri)

    def test_sr_ls_returns_volumes(self):
        dbg = mock.Mock()
        with util.TestFFSPath() as testffspath:
            key = testffspath.create_test_volume()

            ls_result = sr.Implementation().ls(dbg, testffspath.get_uri())

        self.assertEqual(len(ls_result), 1)
        self.assertEqual(ls_result[0]['key'], key)
        self.assertEqual(
            ls_result[0]['uuid'], testffspath.test_volume_data['uuid'])
        self.assertEqual(
            ls_result[0]['name'],  testffspath.test_volume_data['name'])
        self.assertEqual(
            ls_result[0]['description'],
            testffspath.test_volume_data['description'])
        self.assertEqual(
            ls_result[0]['keys'], testffspath.test_volume_data['keys'])
        self.assertIn("uri", ls_result[0])

    def test_sr_stat_returns_valid_dict(self):
        dbg = mock.Mock()
        with util.TestFFSPath() as testffspath:

            stat_result = sr.Implementation().stat(dbg, testffspath.get_uri())

        self.assertIsInstance(stat_result["sr"], str)
        self.assertIsInstance(stat_result["name"], str)
        self.assertIsInstance(stat_result["description"], str)
        self.assertIsInstance(stat_result["total_space"], int)
        self.assertIsInstance(stat_result["free_space"], int)
        self.assertIsInstance(stat_result["datasources"], list)
        self.assertIsInstance(stat_result["clustered"], bool)
        self.assertIsInstance(stat_result["health"][0], str)
        self.assertEqual(len(stat_result), 8)
