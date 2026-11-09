#!/usr/bin/env python3
"""Read Workshop project titles in one batch; malformed packages keep their IDs."""
import json
from pathlib import Path
import sys


def titles_for(root):
    titles = {}
    try:
        folders = list(Path(root).iterdir())
    except OSError:
        return titles
    for folder in folders:
        if not folder.is_dir():
            continue
        try:
            project = folder / 'project.json'
            if project.stat().st_size > 4 * 1024 * 1024:
                continue
            data = json.loads(project.read_text(encoding='utf-8-sig'))
            title = data.get('title') if isinstance(data, dict) else None
            if isinstance(title, str) and title.strip():
                titles[folder.name] = title.strip()
        except (OSError, ValueError, UnicodeError):
            continue
    return titles


if __name__ == '__main__':
    print(json.dumps(titles_for(sys.argv[1]), ensure_ascii=True))
