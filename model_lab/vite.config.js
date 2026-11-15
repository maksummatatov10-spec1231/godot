import { defineConfig } from 'vite';
import fs from 'node:fs';
import path from 'node:path';
const sibling = path.resolve(import.meta.dirname, '../forest_game');
const game = fs.existsSync(sibling) ? sibling : path.resolve(import.meta.dirname, '..');
function validVector(v, bound) { return Array.isArray(v) && v.length === 3 && v.every(n => typeof n === 'number' && Number.isFinite(n) && Math.abs(n) <= bound); }
export default defineConfig({build:{target:'esnext'},server:{host:'0.0.0.0',allowedHosts:true},plugins:[{
 name:'pose-workspace',configureServer(server){
  server.middlewares.use('/game/',(req,res)=>{
   const file=path.resolve(game,decodeURIComponent(req.url.split('?')[0]).replace(/^\//,''));
   if(!file.startsWith(game+path.sep)||!fs.existsSync(file)||!fs.statSync(file).isFile()){res.statusCode=404;res.end();return;}
   const types={'.gltf':'model/gltf+json','.bin':'application/octet-stream','.png':'image/png','.json':'application/json'};
   res.setHeader('Content-Type',types[path.extname(file)]||'application/octet-stream');
   fs.createReadStream(file).pipe(res);
  });
  server.middlewares.use('/api/pose',(req,res)=>{
   res.setHeader('Content-Type','application/json');
   const file=path.join(game,'combat_pose.json');
   if(req.method==='GET'){res.end(fs.readFileSync(file));return;}
   if(req.method!=='POST'){res.statusCode=405;res.end('{}');return;}
   let body='';req.on('data',chunk=>{body+=chunk;if(body.length>8192)req.destroy();});
   req.on('end',()=>{try{
    const data=JSON.parse(body);
    for(const key of ['weapon','first_person']){
     const item=data[key];
     if(!item||!validVector(item.position,3)||!validVector(item.rotation_degrees,360)||!Number.isFinite(item.scale)||item.scale<0.1||item.scale>2)throw Error('Invalid bounded pose');
    }
    fs.writeFileSync(file,JSON.stringify({version:1,weapon:data.weapon,first_person:data.first_person},null,2)+'\n');
    res.end(JSON.stringify({saved:'forest_game/combat_pose.json'}));
   }catch(error){res.statusCode=400;res.end(JSON.stringify({error:String(error)}));}});
  });
 }
}]});
