const { chromium } = require('playwright');
(async()=>{const b=await chromium.launch();
for(const [n,q] of [['p1','?key=0_1&x=5&z=1'],['p2','?key=0_2&x=0&z=-2'],['c1','?key=2_1&x=0&z=1'],['r2','?key=3_2&x=0&z=-5'],['l2','?key=7_2&x=-3&z=4'],['s2','?key=6_2&x=2&z=0'],['i1','?key=5_1&x=-3&z=0'],['k1','?key=1_1&x=-5&z=-2']]){
const p=await b.newPage({viewport:{width:432,height:864},deviceScaleFactor:2});
const e=[];p.on('pageerror',x=>e.push(x.message));p.on('console',m=>console.log(n,m.text()));
await p.goto('file:///home/user/english_trend/godot/mock/flat4_sim.html'+q);await p.waitForTimeout(300);
await p.locator('#cv').screenshot({path:'/tmp/claude-0/-home-user-english-trend/7373ad61-54e9-5bb4-989b-0bde1287835a/scratchpad/mock/flat4_'+n+'.png',clip:undefined});
console.log(n,'ERR:',e.length?e:'none');await p.close()}
await b.close()})();
