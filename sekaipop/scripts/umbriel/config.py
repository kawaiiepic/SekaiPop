#!/usr/bin/env python3
"""Read Umbriel TOML (including includes) for the shell's shortcuts view."""
import json
import os
from pathlib import Path
import sys
import tomllib


def config_path():
    if os.environ.get('UMBRIEL_CONFIG'):
        return Path(os.environ['UMBRIEL_CONFIG']).expanduser()
    user = Path(os.environ.get('XDG_CONFIG_HOME', str(Path.home() / '.config'))) / 'umbriel/config.toml'
    candidates = [user]
    candidates += [Path(d) / 'umbriel/config.toml' for d in os.environ.get('XDG_CONFIG_DIRS', '/etc/xdg').split(':')]
    candidates += [Path('/usr/local/share/umbriel/config.toml'), Path('/usr/share/umbriel/config.toml')]
    return next((p for p in candidates if p.is_file()), user)


def merge(base, extra):
    for key, value in extra.items():
        if isinstance(value, dict) and isinstance(base.get(key), dict):
            merge(base[key], value)
        else:
            base[key] = value
    return base


def read_config(path, seen=None):
    seen = set() if seen is None else seen
    path = path.resolve()
    if path in seen:
        raise ValueError(f'include cycle at {path}')
    seen.add(path)
    data = tomllib.loads(path.read_text())
    result = {}
    include = data.pop('include', {})
    for optional, names in [(False, include.get('files', [])),
                            (True, include.get('optional', {}).get('files', []))]:
        for name in names:
            child = Path(os.path.expandvars(os.path.expanduser(name)))
            if not child.is_absolute():
                child = path.parent / child
            if optional and not child.exists():
                continue
            merge(result, read_config(child, seen))
    seen.remove(path)
    return merge(result, data)


def bindings(config):
    modifiers = {'shift': 1, 'ctrl': 4, 'control': 4, 'alt': 8, 'mod': 64,
                 'super': 64, 'logo': 64, 'win': 64}
    mod = config.get('general', {}).get('mod_key', 'Super').lower()
    modifiers['mod'] = modifiers.get(mod, 64)
    result = []
    for combo, value in config.get('keybinds', {}).items():
        action = value if isinstance(value, str) else value.get('action', '')
        if not action:
            continue
        parts = combo.split('+')
        mask = 0
        for part in parts[:-1]:
            mask |= modifiers.get(part.lower(), 0)
        key = parts[-1]
        if key.lower() in modifiers:
            mask |= modifiers[key.lower()]
            key = {'mod': mod.capitalize(), 'ctrl': 'Control', 'super': 'Super'}.get(key.lower(), key) + '_L'
        spawn = action.startswith('spawn ')
        result.append({'key': key, 'modmask': mask, 'dispatcher': 'exec' if spawn else action.split()[0],
                       'arg': action[6:] if spawn else ' '.join(action.split()[1:]),
                       'description': action, 'has_description': True, 'release': len(parts) == 1 and parts[0].lower() in modifiers})
    return result


def main():
    path = config_path()
    mode = sys.argv[1] if len(sys.argv) > 1 else 'binds'
    if mode == 'path':
        print(path)
        return
    config = read_config(path)
    print(json.dumps(bindings(config) if mode == 'binds' else config))


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError) as error:
        print(f'Umbriel configuration: {error}', file=sys.stderr)
        sys.exit(1)
