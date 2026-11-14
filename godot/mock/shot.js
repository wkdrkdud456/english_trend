const { chromium } = require('playwright');
(async()=>{
const b=await chromium.launch();
const p=await b.newPage({viewport:{width:390,height:844},deviceScaleFactor:2});
const e=[];
p.on('pageerror',x=>e.push(x.message));
p.on('console',m=>{if(m.type()==='error')e.push('console: '+m.text())});
await p.goto('file:///tmp/claude-0/-home-user-english-trend/7373ad61-54e9-5bb4-989b-0bde1287835a/scratchpad/mock/paris2d.html');
await p.waitForTimeout(500);
await p.locator('#c').screenshot({path:'/tmp/claude-0/-home-user-english-trend/7373ad61-54e9-5bb4-989b-0bde1287835a/scratchpad/mock/paris2d.png'});
console.log('ERR:',e.length?e:'none');
await b.close();
})();
