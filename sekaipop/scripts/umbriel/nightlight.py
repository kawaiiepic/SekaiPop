#!/usr/bin/env python3
"""Manage only SekaiPop's own wlsunset instance (gamma-control on wlroots)."""
import fcntl
import json
import os
from pathlib import Path
import signal
import subprocess
import sys
import time


def alive(state):
    try:
        pid = int(state['pid'])
        return (Path(f'/proc/{pid}/stat').read_text().split()[21] == state['start']
                and 'wlsunset' in Path(f'/proc/{pid}/cmdline').read_text())
    except (OSError, KeyError, ValueError):
        return False


def main():
    runtime = Path(os.environ['XDG_RUNTIME_DIR'])
    state_file = runtime / 'sekaipop-nightlight.json'
    with (runtime / 'sekaipop-nightlight.lock').open('w') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        try:
            state = json.loads(state_file.read_text())
        except (OSError, ValueError):
            state = {}
        command = sys.argv[1]
        if command == 'status':
            print(state.get('kelvin', 6000) if alive(state) else 6000)
            return
        if command not in ('off', 'set'):
            raise ValueError('usage: nightlight.py status | off | set KELVIN')
        kelvin = max(1000, min(6500, int(sys.argv[2]))) if command == 'set' else 6000
        if command == 'set' and alive(state) and state.get('kelvin') == kelvin:
            return
        if alive(state):
            os.kill(state['pid'], signal.SIGTERM)
            for _ in range(25):
                if not alive(state):
                    break
                time.sleep(.02)
        state_file.unlink(missing_ok=True)
        if command == 'off':
            return
        # Day and night temperatures differ by only one kelvin, so this is a
        # fixed tint. Using explicit times avoids needing the user's location.
        process = subprocess.Popen(['wlsunset', '-t', str(kelvin), '-T', str(kelvin + 1),
                                    '-S', '00:00', '-s', '23:59'],
                                   stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
                                   stderr=subprocess.DEVNULL, start_new_session=True)
        time.sleep(.15)
        if process.poll() is not None:
            raise RuntimeError('wlsunset failed; check gamma-control support and other color managers')
        state = {'pid': process.pid, 'start': Path(f'/proc/{process.pid}/stat').read_text().split()[21],
                 'kelvin': kelvin}
        state_file.write_text(json.dumps(state))


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError, KeyError, RuntimeError) as error:
        print(f'Night Light: {error}', file=sys.stderr)
        sys.exit(1)
