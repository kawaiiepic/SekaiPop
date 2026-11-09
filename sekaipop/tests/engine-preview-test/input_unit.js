// Exercise the actual layer policy through transitions, including edit mode.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const base = path.resolve(__dirname, '../..');
const layer = fs.readFileSync(path.join(base, 'modules/sekai/background/WallpaperLayer.qml'), 'utf8');
const expression = layer.match(/readonly property bool enginePointerPassThrough: ([\s\S]*?)\n    mask:/)[1];
const service = fs.readFileSync(path.join(base, 'services/WallpaperService.qml'), 'utf8');
const ownership = service.match(/readonly property bool engineOwnsDesktop: ([\s\S]*?)\n\n/)[1];
const shell = fs.readFileSync(path.join(base, 'shell.qml'), 'utf8');
const widgets = shell.match(/readonly property bool widgetsAllowed: ([\s\S]*?)\n\n/)[1];
const width = layer.match(/mask: Region \{\s*width: ([^\n]+)/)[1];
const height = layer.match(/mask: Region \{[\s\S]*?height: ([^\n]+)/)[1];
const win = {engineActive:false, width:1920, height:1080};
const EditMode = {active:false};
let interactive = true;
const WallpaperService = {};
const ctx = vm.createContext({root:win, win, EditMode, WallpaperService, GameModeService:{loaded:true, enabled:false}, LockState:{desktopAsleep:false}, SettingsService:{flag:()=>interactive}});
function region() {
    WallpaperService.engineOwnsDesktop = vm.runInContext(ownership, ctx);
    win.enginePointerPassThrough = vm.runInContext(expression, ctx);
    assert.equal(vm.runInContext(widgets, ctx), !win.enginePointerPassThrough,
        'widget loader visibility and pointer ownership must always agree');
    return [vm.runInContext(width, ctx), vm.runInContext(height, ctx)];
}
assert.deepEqual(region(), [1920,1080], 'normal desktop retains context menu');
win.engineActive = true;
assert.deepEqual(region(), [0,0], 'Engine gets pointer input via an empty shell mask');
EditMode.active = true;
assert.deepEqual(region(), [1920,1080], 'editing restores background selection input');
EditMode.active = false;
assert.deepEqual(region(), [0,0], 'finishing edit releases pointer to Engine');
interactive = false;
assert.deepEqual(region(), [1920,1080], 'user can restore desktop right-click live');
interactive = true;
assert.deepEqual(region(), [0,0]);
win.engineActive = false;
assert.deepEqual(region(), [1920,1080], 'selecting an image restores desktop input');
const settings = fs.readFileSync(path.join(base, 'services/SettingsService.qml'), 'utf8');
assert.match(settings, /"wallpaper.engine.interactive": true/, 'registered setting persists and defaults to interaction');
// All desktop widget loaders, including cloned plugin widgets, must use the gate.
const loaders = shell.slice(shell.indexOf('id: todoWidgetLoader'), shell.indexOf('// The lyrics source picker'));
for (const line of loaders.split('\n').filter(line => /^\s*active:/.test(line)))
    assert.match(line, /shellRoot.widgetsAllowed/, 'desktop loader bypasses wallpaper ownership');
console.log('Engine desktop ownership: input/widget agreement, editing, toggles, stop and all loaders passed');
