const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');
const source = fs.readFileSync(path.join(__dirname, '../../services/RegionService.qml'), 'utf8');
const root = {jobs:[], current:null, monitorShotSerial:0, tmpDir:'/tmp/test', script:'/script'};
const outputs = [{name:'DP-1'}, {name:'HDMI-A-1'}];
const Compositor = {focusedMonitor:{name:'HDMI-A-1'}};
let delayed=0, crop=0, hidden=0, previewHidden=0;
const errors=[];
const context = vm.createContext({root, Compositor, Quickshell:{screens:outputs, execDetached:a=>errors.push(a)},
 openTimer:{stop(){}}, laterTimer:{stop(){}}, SettingsService:{flag:()=>true}, Date:{now:()=>100}, monitorCaptureDelay:{restart:()=>delayed++}, cropper:{exec:()=>crop++}});
for (const name of ['captureMonitor','pump']) {
 const start=source.indexOf('    function '+name+'(')+4;
 let end=source.indexOf('{',start), depth=1;
 while(depth){end++;if(source[end]==='{')depth++;else if(source[end]==='}')depth--;}
 vm.runInContext(source.slice(start,end+1)+'\nroot.'+name+'='+name, context);
}
root.hide=()=>hidden++;root.hidePreview=()=>previewHidden++;
root.captureMonitor();
assert.equal(root.current.monitor,'HDMI-A-1');
assert.equal(root.current.act,'save');
assert.equal(delayed,1);assert.equal(crop,0);assert.equal(hidden,1);assert.equal(previewHidden,1);
const first=root.current.out;
Compositor.focusedMonitor={name:'DP-1'};
assert.equal(root.current.monitor,'HDMI-A-1','focus changes do not redirect a pending shot');
root.captureMonitor();
assert.equal(root.jobs[0].monitor,'DP-1');assert.notEqual(root.jobs[0].out,first,'burst shots have unique temporary files');
assert.equal(delayed,1,'jobs are serialized');
root.current=null;root.pump();assert.equal(delayed,2);
Compositor.focusedMonitor={name:'unplugged'};root.captureMonitor();assert.equal(errors.length,1);
assert.equal(root.jobs.length,0,'missing output must not capture another monitor');
Compositor.focusedMonitor=null;root.captureMonitor();assert.equal(root.jobs[0].monitor,'DP-1');
console.log('Monitor screenshots: focus, delayed capture, queue, burst names, disconnect and fallback passed');
