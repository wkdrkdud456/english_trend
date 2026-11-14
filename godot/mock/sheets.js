const { chromium } = require('playwright');
const base='file:///tmp/claude-0/-home-user-english-trend/7373ad61-54e9-5bb4-989b-0bde1287835a/scratchpad/mock/sheet_sim.html?s=';
(async()=>{const b=await chromium.launch();
for(const s of ['0','1','2','3','shop0','shop1','shop2']){
 const p=await b.newPage({viewport:{width:432,height:864},deviceScaleFactor:2});
 const e=[];p.on('pageerror',x=>e.push(x.message));
 await p.goto(base+s); await p.waitForTimeout(250);
 await p.locator('#cv').screenshot({path:'/tmp/claude-0/-home-user-english-trend/7373ad61-54e9-5bb4-989b-0bde1287835a/scratchpad/mock/sheet_'+s+'.png'});
 console.log(s, e.length?e:'ok'); await p.close();}
await b.close()})();
