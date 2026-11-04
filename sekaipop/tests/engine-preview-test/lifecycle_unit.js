const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const file = path.resolve(__dirname, '../../services/WallpaperEngineService.qml');
const source = fs.readFileSync(file, 'utf8');
function fixture() {
    const saved = {'wallpaper.engine.active': true, 'wallpaper.engine.currentId': '123',
        'wallpaper.engine.currentPath': '/custom Steam library/431960/123'};
    const root = {restorePending: true, workshopPath: '', active: false,
        flagsSetting: '--layer background --fps 30'};
    const settings = {loaded: false, flag: k => !!saved[k], get: k => saved[k], set: (k,v) => {saved[k]=v}};
    const wallpaper = {ready: false};
    let launches = 0;
    const process = {running: false};
    Object.defineProperty(process, 'command', {set: c => {process.lastCommand=c; launches++}});
    const context = vm.createContext({root, SettingsService: settings, WallpaperService: wallpaper,
        Quickshell: {screens:[{name:'DP-1'}, {name:'HDMI-A-1'}]}, engineProc: process,
        helper:{}, lateRestack:{stop(){}}, laterRestack:{stop(){}}});
    for (const match of source.matchAll(/^    function (\w+)\([^\n]*\) \{/gm)) {
        const start = match.index+4;
        let end = source.indexOf('{', start), depth=1;
        while (depth) {++end; if(source[end]==='{')depth++;else if(source[end]==='}')depth--;}
        vm.runInContext(source.slice(start,end+1)+'\nroot.'+match[1]+' = '+match[1], context);
    }
    return {root,settings,wallpaper,process,launches:()=>launches};
}
for (const order of [[0,1,2],[0,2,1],[1,0,2],[1,2,0],[2,0,1],[2,1,0]]) {
    const f=fixture();
    f.root.restoreIfNeeded();
    assert.equal(f.launches(),0);
    order.forEach((gate,i)=>{
        if(gate===0)f.settings.loaded=true;
        if(gate===1)f.wallpaper.ready=true;
        if(gate===2)f.root.workshopPath='/custom Steam library/431960';
        f.root.restoreIfNeeded();
        assert.equal(f.launches(),i===2?1:0,'restore waits for all asynchronous readers');
    });
    assert.equal(f.process.lastCommand.at(-1),'/custom Steam library/431960/123');
    assert.equal(f.root.active,true);
    assert.equal(f.root.currentId,'123');
    f.root.restoreIfNeeded();
    assert.equal(f.launches(),1,'restore happens only once');
}
const f=fixture();
f.root.setWallpaper('/new/456','New selection');
f.settings.loaded=true;f.wallpaper.ready=true;f.root.workshopPath='/workshop';
f.root.restoreIfNeeded();
assert.equal(f.launches(),1,'explicit new selection wins over saved restore');
assert.equal(f.root.currentId,'456');
f.root.stop();
assert.equal(f.root.active,false);
f.root.restoreIfNeeded();
assert.equal(f.launches(),1,'stop cancels pending restore');
console.log('Engine lifecycle: all startup orders, one-shot restore, custom paths, explicit picks and stop passed');

// Exercise the actual settings allowlist and persistence methods as well as
// the lifecycle. A permissive settings mock hid unregistered Engine keys.
const settingsSource = fs.readFileSync(path.resolve(__dirname, '../../services/SettingsService.qml'), 'utf8');
const defaults = vm.runInNewContext(settingsSource.match(/readonly property var defaults: (\(\{[\s\S]*?\}\))/)[1]);
function realSettings() {
    const root = {defaults, values: {}, loaded: true, touched: false};
    const saver = {save: text => { saver.text = text; }};
    const context = vm.createContext({root, saver, console});
    for (const name of ['get', 'set', 'restore']) {
        const start = settingsSource.indexOf('    function ' + name + '(') + 4;
        let end = settingsSource.indexOf('{', start), depth = 1;
        while (depth) { ++end; if (settingsSource[end] === '{') depth++; else if (settingsSource[end] === '}') depth--; }
        vm.runInContext(settingsSource.slice(start, end + 1) + '\nroot.' + name + ' = ' + name, context);
    }
    root.flag = key => !!root.get(key);
    return {root, saver};
}
const first = realSettings();
const selected = fixture();
selected.settings.set = first.root.set;
// setWallpaper uses this object through the fixture's settings binding.
selected.root.setWallpaper('/custom Steam library/431960/123', 'Saved Engine');
first.root.set('wallpaper.engine.workshopPath', '/custom Steam library/431960');
first.root.set('wallpaper.engine.flags', '--fps 24');
first.root.set('appearance.shellTheme', 'cyberpunk');
const restarted = realSettings();
restarted.root.restore(first.saver.text);
assert.equal(restarted.root.get('appearance.shellTheme'), 'cyberpunk', 'shell theme survives restart');
for (const [key, value] of Object.entries({active:true, currentId:'123',
    currentPath:'/custom Steam library/431960/123', workshopPath:'/custom Steam library/431960', flags:'--fps 24'}))
    assert.equal(restarted.root.get('wallpaper.engine.' + key), value);
const restored = fixture();
restored.settings.loaded = true;
restored.settings.get = restarted.root.get;
restored.settings.flag = restarted.root.flag;
restored.wallpaper.ready = true;
restored.root.workshopPath = restarted.root.get('wallpaper.engine.workshopPath');
restored.root.restoreIfNeeded();
assert.equal(restored.launches(), 1, 'persisted Engine selection launches after restart');
assert.equal(restored.process.lastCommand.at(-1), '/custom Steam library/431960/123');
first.root.set('wallpaper.engine.active', false);
restarted.root.restore(first.saver.text);
assert.equal(restarted.root.flag('wallpaper.engine.active'), false, 'stop remains persisted');
console.log('Engine settings: real allowlist, save/reload, restart launch and stop passed');
