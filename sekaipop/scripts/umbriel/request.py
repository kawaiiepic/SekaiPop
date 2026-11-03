#!/usr/bin/env python3
"""Send one Umbriel action per connection; ordinary replies close the connection."""
import json
import socket
import sys


def request(path, payload):
    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as connection:
        connection.settimeout(3)
        connection.connect(path)
        connection.sendall((json.dumps(payload) + '\n').encode())
        with connection.makefile('rb') as stream:
            line = stream.readline(65537)
        if not line or len(line) > 65536 or not line.endswith(b'\n'):
            raise ValueError('incomplete or oversized Umbriel reply')
        reply = json.loads(line)
        if not isinstance(reply, dict):
            raise ValueError('invalid Umbriel reply')
        if 'err' in reply:
            raise ValueError(str(reply['err']))
        if 'ok' not in reply:
            raise ValueError('Umbriel reply has no result')
        return reply['ok']


if __name__ == '__main__':
    try:
        request(sys.argv[1], json.loads(sys.argv[2]))
    except (OSError, ValueError, IndexError) as error:
        print(f'Umbriel: {error}', file=sys.stderr)
        sys.exit(1)
