import {chromium as playwright} from 'playwright-core';
import chromium from '@sparticuz/chromium';
import fs from 'node:fs';
const out=process.env.LAB_OUTPUT||'../artifacts/model-lab';fs.mkdirSync(out,{recursive:true});
const browser=await playwright.launch({executablePath:await chromium.executablePath(),args:chromium.args,headless:true});
const page=await browser.newPage({viewport:{width:1440,height:900}});const errors=[];page.on('pageerror',error=>errors.push(String(error)));
page.on('console',msg=>console.log('BROWSER',msg.type(),msg.text()));
await page.goto('http://127.0.0.1:5173');try {await page.waitForFunction(()=>window.labReady===true,null,{timeout:30000});}catch(error){console.log(await page.locator('body').innerText());await page.screenshot({path:out+'/failed.png'});await browser.close();throw error;}
for(const [view,clip,time,name] of [
 ['grip','Sword_Idle',.3,'01-grip-idle'],['third','Sword_Regular_A',.3,'02-third-strike-A'],
 ['first','Sword_Idle',.3,'03-fps-idle'],['first','Sword_Regular_A',.3,'04-fps-strike-A'],
 ['first','Sword_Regular_B',.3,'05-fps-strike-B'],['first','Sword_Regular_C',.3,'06-fps-strike-C'],
 ['first','Walk_Loop',.3,'07-fps-walk'],['first','Jump_Loop',.3,'08-fps-jump']]){
 await page.evaluate(({view,clip,time})=>{const name=window.lab.rigs[0].clips.some(c=>c.name===clip)?clip:window.lab.rigs[0].clips.find(c=>c.name.startsWith(clip.split('_')[0]))?.name;window.lab.chooseClip(name);window.lab.sample(time);window.lab.chooseView(view);},{view,clip,time});
 await page.screenshot({path:`${out}/${name}.png`});
}
fs.writeFileSync(`${out}/browser-errors.json`,JSON.stringify(errors,null,2));console.log('Browser errors:',errors);await browser.close();if(errors.length)process.exitCode=1;
