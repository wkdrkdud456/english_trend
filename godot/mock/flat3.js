const { chromium } = require('playwright');
(async()=>{const b=await chromium.launch();
for(const [n,q] of [['ui','?x=-0.45&z=8'],['a1','?area=1&wide=1&x=0&z=0'],['a2','?area=2&wide=1&x=0&z=0'],['a1n','?area=1&x=9&z=0']]){
const p=await b.newPage({viewport:{width:432,height:864},deviceScaleFactor:2});
const e=[];p.on('pageerror',x=>e.push(x.message));p.on('console',m=>console.log(n,m.text()));
await p.goto('file:///home/user/english_trend/godot/mock/flat3_sim.html'+q);await p.waitForTimeout(300);
await p.locator('#cv').screenshot({path:'/tmp/claude-0/-home-user-english-trend/7373ad61-54e9-5bb4-989b-0bde1287835a/scratchpad/mock/flat3_'+n+'.png',clip:undefined});
console.log(n,'ERR:',e.length?e:'none');await p.close()}
await b.close()})();
