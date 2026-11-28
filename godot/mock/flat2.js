const { chromium } = require('playwright');
(async()=>{const b=await chromium.launch();
for(const [n,q] of [['a','?x=-0.45&z=8'],['b','?x=-4&z=-2.2'],['c','?x=1&z=-7']]){
const p=await b.newPage({viewport:{width:432,height:864},deviceScaleFactor:2});
const e=[];p.on('pageerror',x=>e.push(x.message));p.on('console',m=>console.log(n,m.text()));
await p.goto('file:///home/user/english_trend/godot/mock/flat2_sim.html'+q);await p.waitForTimeout(300);
await p.locator('#cv').screenshot({path:'/tmp/claude-0/-home-user-english-trend/7373ad61-54e9-5bb4-989b-0bde1287835a/scratchpad/mock/flat2_'+n+'.png',clip:undefined});
console.log(n,'ERR:',e.length?e:'none');await p.close()}
await b.close()})();
