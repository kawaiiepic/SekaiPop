const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const base = path.resolve(__dirname, '../..');
const math = vm.createContext({console});
vm.runInContext(fs.readFileSync(base + '/modules/common/functions/UmbrielMath.js', 'utf8').replace(/^\.pragma library\n/, ''), math);
// Exercise the actual QML service methods with minimal Qt object/socket stand-ins.
const source = fs.readFileSync(base + '/services/Compositor.qml', 'utf8');
const root = { cache: {}, workspaceIds: {}, nextWorkspaceId: 0, outputSnapshot: [], workspaceSnapshot: [],
  windowSnapshot: [], connected: true, actionQueue: [], socketPath: "/fake/umbriel.sock", toplevels: {values: []}, workspaces: {values: []}, monitors: {values: []}, errors: [] };
root.actionError = message => root.errors.push(message);
root.rawEvent = () => {};
const sent = [];
const context = vm.createContext({root, UM: math, console,
  entry: {createObject: () => ({toplevels: {values: []}, destroy() {this.destroyed = true}})},
  requester: {running: false, exec: args => sent.push(JSON.parse(args.at(-1)))},
  Directories: {script: path => path}, Qt: {callLater: callback => callback()}});
for (const match of source.matchAll(/^    function (\w+)\([^\n]*\) \{/gm)) {
  const start = match.index + 4;
  let end = source.indexOf('{', start), depth = 1;
  while (depth) { ++end; if (source[end] === '{') ++depth; else if (source[end] === '}') --depth; }
  const declaration = source.slice(start, end + 1);
  vm.runInContext(declaration + '\nroot.' + match[1] + ' = ' + match[1], context);
}
function event(type, data) {root.consume(JSON.stringify({event: type, data}));}
const workspaces = [
  {id: 'left-1', index: 1, name: '1', named: false, output: 'DP-1', active: true},
  {id: 'right-1', index: 1, name: '1', named: true, output: 'HDMI-A-1', active: true}
];
event('workspaces', workspaces);
const w1 = root.workspaces.values[0];
event('outputs', [
  {name: 'DP-1', enabled: true, focused: true, active_workspace: 'left-1', position: {x: -1280, y: 0},
   logical_size: {width: 1280, height: 720}, usable_area: {x: -1280, y: 40, width: 1280, height: 680},
   scale: 1.5, modes: [{width: 1920, height: 1080, refresh_mhz: 144000, current: true}], transform: 'normal'},
  {name: 'HDMI-A-1', enabled: true, active_workspace: 'right-1', position: {x: 0, y: 0},
   logical_size: {width: 1920, height: 1080}, usable_area: {x: 0, y: 0, width: 1920, height: 1080}, modes: [], scale: 1}
]);
assert.equal(root.workspaces.values[0], w1, 'model identity survives an output snapshot');
assert.notEqual(root.workspaces.values[0].id, root.workspaces.values[1].id, 'same index on two outputs stays distinct');
assert.equal(root.focusedWorkspace, w1);
assert.deepEqual(Array.from(root.monitorData[0].reserved), [0,40,0,0]);
assert.equal(root.monitorData[0].width, 1920);
assert.equal(root.monitorData[0].scale, 1.5);
event('windows', [{id: 'opaque-window-id', workspace: 'left-1', output: 'DP-1', app_id: 'kitty', title: 'A',
 x: -1200, y: 50, w: 800, h: 600, floating: true, active: true, visible: true, minimizable: true}]);
const window = root.activeToplevel;
assert.equal(window.address, 'opaque-window-id');
assert.equal(w1.toplevels.values[0], window);
event('windows', [{id: 'opaque-window-id', workspace: 'right-1', output: 'HDMI-A-1', app_id: 'kitty', title: 'B',
 x: 0, y: 50, w: 800, h: 600, visible: false, minimized: true}]);
assert.equal(root.toplevels.values[0], window);
assert.equal(window.title, 'B');
assert.equal(w1.toplevels.values.length, 0);
assert.equal(window.lastIpcObject.hidden, true);
root.workspaceAction('workspace-switch', root.workspaces.values[1].id);
assert.equal(sent.at(-1).workspace, '1', 'numeric names remain strings');
assert.equal(sent.at(-1).output, 'HDMI-A-1');
root.focusWorkspace('DP-1', 3);
assert.equal(sent.at(-1).workspace, 3, 'position selectors remain numbers');
root.dispatch('closewindow address:opaque-window-id');
assert.equal(sent.at(-1).window, 'opaque-window-id');
assert.equal(sent.at(-1).action, 'window-close');
root.consume('not json');
assert.equal(root.toplevels.values.length, 1, 'malformed input does not erase state');
root.consume('{"err":"refused"}');
assert.equal(root.errors.at(-1), 'refused');
root.actionQueue = [{action: 'window-move-to-workspace-silent'}];
root.requestFinished(1, 'focus failed');
assert.equal(root.actionQueue.length, 0, 'failed focus cancels dependent moves');
root.clear();
assert.equal(root.toplevels.values.length, 0);
assert.equal(root.focusedMonitor, null);
assert.equal(window.destroyed, true);
console.log('Umbriel adapter: state, identity, multi-output selectors, geometry, actions, errors and disconnect passed');
