const { chromium } = require('playwright');
(async()=>{const b=await chromium.launch();
const p=await b.newPage({viewport:{width:432,height:864},deviceScaleFactor:2});
const e=[];p.on('pageerror',x=>e.push(x.message));
p.on('console',m=>console.log('['+m.type()+']',m.text()));
await p.goto('file:///tmp/claude-0/-home-user-english-trend/7373ad61-54e9-5bb4-989b-0bde1287835a/scratchpad/mock/flat_sim.html');
await p.waitForTimeout(400);
await p.locator('#cv').screenshot({path:'/tmp/claude-0/-home-user-english-trend/7373ad61-54e9-5bb4-989b-0bde1287835a/scratchpad/mock/flat_sim.png'});
console.log('ERR:',e.length?e:'none');await b.close()})();
