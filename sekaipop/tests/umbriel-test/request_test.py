import importlib.util
import json
from pathlib import Path
import socket
import unittest

spec = importlib.util.spec_from_file_location('umbriel_request', Path(__file__).resolve().parents[2] / 'scripts/umbriel/request.py')
client = importlib.util.module_from_spec(spec)
spec.loader.exec_module(client)


class RequestTests(unittest.TestCase):
    def exchange(self, reply, payload=None):
        # Exercise the real request/reply parser with a mocked transport; the
        # build environment does not allow AF_UNIX sockets.
        from io import BytesIO
        from unittest.mock import MagicMock, patch
        payload = payload or {'cmd': 'action', 'action': 'overview-toggle'}
        connection = MagicMock()
        connection.__enter__.return_value = connection
        connection.makefile.return_value = BytesIO(reply)
        with patch.object(client.socket, 'socket', return_value=connection) as factory:
            result = client.request('/fake/umbriel.sock', payload)
        factory.assert_called_once_with(socket.AF_UNIX, socket.SOCK_STREAM)
        connection.connect.assert_called_once_with('/fake/umbriel.sock')
        self.assertEqual(json.loads(connection.sendall.call_args.args[0]), payload)
        connection.__exit__.assert_called_once()
        return result

    def test_success_with_peer_close(self):
        self.assertIsNone(self.exchange(b'{"ok":null}\n'))

    def test_server_error(self):
        with self.assertRaisesRegex(ValueError, 'unknown window'):
            self.exchange(b'{"err":"unknown window"}\n')

    def test_empty_disconnect(self):
        with self.assertRaisesRegex(ValueError, 'incomplete'):
            self.exchange(b'')

    def test_partial_reply(self):
        with self.assertRaisesRegex(ValueError, 'incomplete'):
            self.exchange(b'{"ok":null}')

    def test_invalid_reply(self):
        with self.assertRaises(ValueError):
            self.exchange(b'not json\n')

    def test_no_result(self):
        with self.assertRaisesRegex(ValueError, 'no result'):
            self.exchange(b'{}\n')


if __name__ == '__main__':
    unittest.main()
