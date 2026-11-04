#!/bin/sh
set -eu
file="${XDG_RUNTIME_DIR:?}/sekaipop-gamemode"
case "${1:-}" in
    on) : > "$file" ;;
    off) rm -f "$file" ;;
    *) exit 2 ;;
esac
