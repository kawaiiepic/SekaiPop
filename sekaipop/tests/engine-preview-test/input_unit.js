// Exercise the actual layer policy through transitions, including edit mode.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const base = path.resolve(__dirname, '../..');
const layer = fs.readFileSync(path.join(base, 'modules/sekai/background/WallpaperLayer.qml'), 'utf8');
const expression = layer.match(/readonly property bool enginePointerPassThrough: ([\s\S]*?)\n    mask:/)[1];
const width = layer.match(/mask: Region \{\s*width: ([^\n]+)/)[1];
const height = layer.match(/mask: Region \{[\s\S]*?height: ([^\n]+)/)[1];
const win = {engineActive:false, width:1920, height:1080};
const EditMode = {active:false};
let interactive = true;
const ctx = vm.createContext({win, EditMode, SettingsService:{flag:()=>interactive}});
function region() {
    win.enginePointerPassThrough = vm.runInContext(expression, ctx);
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
console.log('Engine input: normal desktop, Engine, edit entry/exit, live preference and stop passed');
