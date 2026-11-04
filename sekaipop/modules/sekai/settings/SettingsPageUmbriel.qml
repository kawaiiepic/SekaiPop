import QtQuick
import Quickshell
import qs.services
import qs.modules.common
import qs.modules.common.widgets

// The route name is kept for compatibility with existing `quickpanel page hyprland` binds.
SettingsPage {
    id: page
    SectionCard {
        title: "Umbriel"
        SettingAction {
            icon: "edit_note"
            label: "Edit compositor configuration"
            detail: "Umbriel watches config.toml and applies valid changes when you save"
            onActivated: Quickshell.execDetached(["xdg-open", Quickshell.env("UMBRIEL_CONFIG") ||
                (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/umbriel/config.toml"])
        }
        SettingAction {
            icon: "refresh"
            label: "Reload configuration"
            detail: Compositor.connected ? "Umbriel IPC connected" : "Waiting for Umbriel IPC"
            onActivated: Compositor.action("config-reload")
        }
        SettingAction {
            icon: "help"
            label: "Configuration reference"
            detail: "Appearance, outputs, input, rules and shortcuts"
            onActivated: Quickshell.execDetached(["xdg-open", "https://docs.noctalia.dev/umbriel/"])
        }
    }
    SectionCard {
        title: "Workspace layout"
        Repeater {
            model: ["scrolling", "dwindle", "master", "stacking"]
            delegate: SettingAction {
                required property string modelData
                icon: "view_quilt"
                label: modelData.charAt(0).toUpperCase() + modelData.slice(1)
                detail: "Apply to the focused workspace"
                onActivated: Compositor.action("workspace-set-layout", { layout: modelData })
            }
        }
        SettingAction {
            icon: "view_carousel"
            label: "Overview"
            detail: "Umbriel's live workspace and window overview"
            onActivated: Compositor.action("overview-toggle")
        }
    }
    SectionCard {
        title: "Displays & input"
        Repeater {
            model: Compositor.outputSnapshot
            delegate: SettingAction {
                required property var modelData
                icon: "monitor"
                label: modelData.name
                detail: modelData.enabled
                    ? modelData.logical_size.width + " × " + modelData.logical_size.height + " · scale " + modelData.scale
                    : "Disabled"
                onActivated: Quickshell.execDetached(["xdg-open", "https://docs.noctalia.dev/umbriel/outputs/"])
            }
        }
        SettingAction {
            icon: "keyboard"
            label: "Switch keyboard layout"
            detail: KeyboardLayoutService.layoutName || "Configure input.keyboard in config.toml"
            onActivated: KeyboardLayoutService.cycle()
        }
    }
    SectionCard {
        title: "Shortcuts"
        SettingAction {
            icon: "keyboard_keys"
            label: "Edit shortcuts"
            detail: "The [keybinds] section in your Umbriel configuration"
            onActivated: Quickshell.execDetached(["xdg-open",
                (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/umbriel/config.toml"])
        }
    }
}
