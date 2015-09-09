import mock
import os
import sys
import unittest

sys.path.append(os.path.join(os.path.dirname(__file__), '..'))
import plugin


class test_plugin(unittest.TestCase):

    def test_diagnostics_returns_string(self):
        mock.Mock()

        diagnostics_result = plugin.Implementation().diagnostics(None)

        assert isinstance(diagnostics_result, str)

    def test_query_returns_valid_dict(self):
        dbg = mock.Mock()

        query_result = plugin.Implementation().query(dbg)

        self.assertIsInstance(query_result["plugin"], str)
        self.assertIsInstance(query_result["name"], str)
        self.assertIsInstance(query_result["description"], str)
        self.assertIsInstance(query_result["vendor"], str)
        self.assertIsInstance(query_result["copyright"], str)
        self.assertIsInstance(query_result["version"], str)
        self.assertIsInstance(query_result["required_api_version"], str)
        self.assertIsInstance(query_result["features"], list)
        self.assertIsInstance(query_result["configuration"], dict)
        self.assertIsInstance(query_result["required_cluster_stack"], list)
