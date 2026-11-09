.pragma library

// Umbriel IDs are opaque strings. Never add an address prefix or parse them as numbers.
function workspaceSelector(workspace) {
    return workspace.named ? workspace.name : workspace.index
}

function monitor(output, index, workspaceId) {
    const mode = (output.modes || []).find(m => m.current) || {}
    const area = output.usable_area || {}
    const p = output.position || { x: 0, y: 0 }
    const size = output.logical_size || { width: 0, height: 0 }
    return {
        id: index, name: output.name, description: output.description || "",
        x: p.x, y: p.y, width: mode.width || size.width,
        height: mode.height || size.height, scale: output.scale || 1,
        transform: ["normal", "90", "180", "270", "flipped", "flipped-90", "flipped-180", "flipped-270"].indexOf(output.transform),
        refreshRate: (mode.refresh_mhz || 0) / 1000,
        disabled: !output.enabled, focused: output.focused === true,
        activeWorkspace: { id: workspaceId || 0 }, specialWorkspace: { id: 0, name: "" },
        reserved: [Math.max(0, (area.x || 0) - p.x), Math.max(0, (area.y || 0) - p.y),
            Math.max(0, p.x + size.width - (area.x || 0) - (area.width || 0)),
            Math.max(0, p.y + size.height - (area.y || 0) - (area.height || 0))],
        availableModes: (output.modes || []).map(m => m.width + "x" + m.height + "@" + (m.refresh_mhz / 1000) + "Hz")
    }
}

function windowData(window, workspaceId, monitorId) {
    return {
        address: window.id, class: window.app_id || "", initialClass: window.app_id || "",
        title: window.title || "", pid: window.pid, at: [window.x || 0, window.y || 0],
        size: [window.w || 0, window.h || 0], monitor: monitorId,
        workspace: { id: workspaceId || 0 }, mapped: true,
        hidden: window.visible === false, floating: window.floating === true,
        pinned: window.pinned === true, fullscreen: window.fullscreen ? 1 : 0,
        minimized: window.minimized === true, minimizable: window.minimizable === true
    }
}
