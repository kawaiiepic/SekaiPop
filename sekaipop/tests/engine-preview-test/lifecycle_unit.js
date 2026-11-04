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
