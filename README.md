# SekaiPop for Umbriel

A Project Sekai inspired Quickshell desktop, ported from [Blapples/SekaiPop](https://github.com/Blapples/SekaiPop) to [Umbriel](https://github.com/noctalia-dev/umbriel).

The phone, bar, dock, wallpapers, widgets, lockscreen, media controls, notifications and screenshot tools keep SekaiPop's appearance. Compositor integration uses Umbriel's native IPC. This fork does not require Hyprland or Quickshell's Hyprland module.

## Install

Install Umbriel and Quickshell 0.3 or newer, with Wayland layer-shell, session-lock, screencopy and the service modules used by SekaiPop. Python 3.11+ is required for reading Umbriel's TOML configuration. Qt SVG, multimedia, image formats and Shader Tools are also needed. For screen sharing install `xdg-desktop-portal-umbriel` alongside the common portal service and a GTK file-dialog backend. The dependency checker lists optional features and their tools.

```sh
git clone https://github.com/kawaiiepic/SekaiPop.git
cd SekaiPop
./check-deps.sh
./install.sh
```

The installer backs up an existing `~/.config/quickshell/sekaipop` and installs the shell. It leaves your Umbriel configuration alone. Dependency installation is separate: `./install-deps.sh` supports Arch based distributions; on Void and other distributions install the equivalent packages manually. Install Umbriel using its upstream instructions.

If you do not already have an Umbriel configuration, first copy its packaged starting config to `~/.config/umbriel/config.toml`. Merge the entries from [umbriel/sekaipop.toml](umbriel/sekaipop.toml) into it. Add to existing tables and autostart lists rather than duplicating them. Remove another desktop shell from autostart to avoid competing bars and notification servers.

Validate, then start the shell in your Umbriel session:

```sh
umbriel config validate
qs -c sekaipop
```

For a custom `umbriel -c /path/config.toml` session, export `UMBRIEL_CONFIG=/path/config.toml` before starting Quickshell. The config reader otherwise follows Umbriel's standard user, system and packaged config search order. `UMBRIEL_SOCKET` is used when set; otherwise the shell uses `$XDG_RUNTIME_DIR/umbriel-$WAYLAND_DISPLAY.sock`.

The shipped shaders target Qt 6.12. The installer recompiles them when `qsb` is available; for a different Qt build install its matching Shader Tools and run:

```sh
bash ~/.config/quickshell/sekaipop/shaders/compile-shaders.sh
```

## Integration

- One IPC subscription tracks windows, workspaces, outputs, keyboard layouts, layers and overview state. Disconnection clears stale models and retries.
- Workspace badges use each output's own workspace positions. Explicit numeric workspace names remain names when actions are sent.
- The dock focuses/closes windows using opaque Umbriel window IDs, tracks native minimization, and uses live geometry for smart hiding.
- Desktop focus mode hides or suspends widgets based on the visible windows on each output.
- Overview actions open Umbriel's built-in overview, which supplies live previews. The dock's individual preview cards currently show icons and titles; Quickshell's Hyprland capture handles are unavailable.
- Popups use standard Wayland popup grabs. Layer panels use Umbriel focus notifications and the phone's click-away surface.
- The compositor settings page provides layout actions, output/layout status, configuration editing and the Umbriel reference. Appearance, display configuration, cursor theme and shortcuts are edited in Umbriel's `config.toml`, which reloads when saved. The old `settings page hyprland` route remains an alias; use `settings page umbriel` for new binds.
- Shortcut views read `[keybinds]`, including included TOML files. Editing and capture are delegated to Umbriel configuration rather than Hyprland's bind/submap APIs.
- Night Light uses `wlsunset`, managing only the instance started by SekaiPop. Do not run another gamma/color manager alongside it. Hardware brightness still uses brightnessctl/ddcutil.
- Game Mode reduces the shell's own workload; it does not rewrite Umbriel's visual settings. The Hyprland screen-shader tile and software-gamma slider are removed. Configure Umbriel effects directly.
- Logout uses `umbriel msg session-quit skip-confirmation`. Optional hypridle remains usable as an idle daemon; its generated DPMS commands target Umbriel.

Umbriel only supports minimizing eligible floating windows. A dock minimize request for a tiled window explains that it must be floated first.

## Shortcuts in the example

| Shortcut | Action |
| --- | --- |
| Super tap | Apps |
| Super+A | Quick panel |
| Super+I | Umbriel overview |
| Super+Comma | Umbriel settings page |
| Super+L | Lock |
| Print | Screenshot selector |

## Validation

```sh
node sekaipop/tests/umbriel-test/umbriel_unit.js
python3 sekaipop/tests/umbriel-test/config_test.py
```

The adapter tests exercise actual service methods with a stub transport: multi-output workspace selectors, model identity, geometry, window actions, malformed replies and disconnect cleanup. Configuration tests cover include precedence, optional/missing includes, cycles and custom paths. Installer checks verify dry-run behavior, backups and preservation of the compositor config.

A live Umbriel/Quickshell session is still required to verify visual placement, input/focus, gamma-control, screencopy and lockscreen behavior on your machine. This port has not been tested in a live compositor session here.

## Credits

Original shell and assets: [Blapples/SekaiPop](https://github.com/Blapples/SekaiPop). Original documentation and detailed credits are preserved in [docs/UPSTREAM-README.md](docs/UPSTREAM-README.md). The `hypr/` configuration and Hyprland helper scripts remain upstream reference material and are not installed or used by this port. GPL-3.0 licensing is unchanged.

## Umbriel theme scaffold

[umbriel/theme.example.toml](umbriel/theme.example.toml) starts the compositor theme integration with a commented palette mapping. The installer copies it to `~/.config/umbriel/sekaipop-theme.example.toml` for reference. It contains no active settings, is not included in the compositor config, and is not connected to the shell's theme service. No colors or appearance settings are changed.

`install.sh --deps` can run the existing Arch dependency installer first; the default continues to install only the shell. Shader compilation now happens in staging before the current shell is replaced, and installed copies track the branch they were installed from.
