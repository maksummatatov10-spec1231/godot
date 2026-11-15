import * as THREE from 'three';
import {GLTFLoader} from 'three/addons/loaders/GLTFLoader.js';
import {OrbitControls} from 'three/addons/controls/OrbitControls.js';
const $=id=>document.getElementById(id);
const renderer=new THREE.WebGLRenderer({canvas:document.querySelector('canvas'),antialias:true,preserveDrawingBuffer:true});
renderer.setPixelRatio(Math.min(devicePixelRatio,1.5));renderer.shadowMap.enabled=true;renderer.shadowMap.type=THREE.PCFSoftShadowMap;
renderer.outputColorSpace=THREE.SRGBColorSpace;renderer.toneMapping=THREE.ACESFilmicToneMapping;
const scene=new THREE.Scene();scene.background=new THREE.Color('#263b49');
scene.add(new THREE.HemisphereLight(0xd7edff,0x535247,2.5));const sun=new THREE.DirectionalLight(0xffedd3,3);sun.position.set(3,5,-4);sun.castShadow=true;sun.shadow.mapSize.set(1024,1024);scene.add(sun);
const floor=new THREE.Mesh(new THREE.PlaneGeometry(200,200),new THREE.MeshStandardMaterial({color:0x3a4848,roughness:1}));floor.rotation.x=-Math.PI/2;floor.receiveShadow=true;scene.add(floor);scene.add(new THREE.GridHelper(20,40,0x597079,0x394f59));
const camera=new THREE.PerspectiveCamera(68,1,.025,200);camera.position.set(2.7,1.8,-3.3);
const controls=new OrbitControls(camera,renderer.domElement);controls.target.set(0,1,0);controls.enableDamping=true;
const loader=new GLTFLoader();const load=url=>loader.loadAsync('/game/'+url);
let pose=await (await fetch('/api/pose')).json();let mode='third',playing=false,time=0,clipName='Sword_Idle',duration=1;const rigs=[];let markers;
try{
 const [body,arms,weapon]=await Promise.all([load('assets/hero/warden.gltf'),load('assets/hero/warden_arms.gltf'),load('assets/weapon/sword_C.gltf')]);
 for(const [kind,gltf] of [['third',body],['first',arms]]){
  const root=gltf.scene;scene.add(root);const hand=root.getObjectByName('hand_r');if(!hand)throw Error('hand_r not found');
  const sword=weapon.scene.clone(true);hand.add(sword);
  root.traverse(object=>{if(object.isMesh){object.castShadow=true;object.receiveShadow=true;object.frustumCulled=false;}});
  const mixer=new THREE.AnimationMixer(root);const clips=gltf.animations;const rest=[];root.traverse(b=>{if(b.isBone)rest.push([b,b.position.clone(),b.quaternion.clone(),b.scale.clone()]);});rigs.push({kind,root,hand,sword,mixer,clips,rest,action:null});
 }
 const clips=rigs[0].clips.map(c=>c.name);for(const name of clips){const option=new Option(name,name);$('clip').add(option);}
 clipName=clips.find(n=>n==='Sword_Idle')||clips[0];$('clip').value=clipName;
 markers=new THREE.Group();rigs[0].hand.add(markers);markers.add(new THREE.AxesHelper(.2));
 const marker=new THREE.Mesh(new THREE.SphereGeometry(.012,12,8),new THREE.MeshBasicMaterial({color:0x72ffb6}));marker.position.set(-.035,.085,0);markers.add(marker);
 rebuildInputs();chooseClip(clipName);chooseView('third');window.labReady=true;
}catch(error){$('status').textContent=String(error);console.error(error);}
function rebuildInputs(){for(const key of ['weapon','first_person']){
 $(key).replaceChildren();for(const [field,label,step] of [['position','XYZ · метры',.005],['rotation_degrees','XYZ · градусы',1]]){
  const title=document.createElement('label');title.textContent=label;$(key).append(title);const row=document.createElement('div');row.className='row';
  for(let axis=0;axis<3;axis++){const input=document.createElement('input');input.type='number';input.step=step;input.value=pose[key][field][axis];input.title=`${key} ${field} ${'xyz'[axis]}`;input.oninput=()=>{const value=Number(input.value);if(Number.isFinite(value)){pose[key][field][axis]=value;applyPose();}};row.append(input);}$(key).append(row);
 }const scale=document.createElement('input');scale.type='number';scale.min=.1;scale.max=2;scale.step=.01;scale.value=pose[key].scale;scale.oninput=()=>{pose[key].scale=Number(scale.value);applyPose();};const label=document.createElement('label');label.textContent='Масштаб ';label.append(scale);$(key).append(label);
}applyPose();}
function transform(object,data){object.position.fromArray(data.position);object.rotation.set(...data.rotation_degrees.map(THREE.MathUtils.degToRad));object.scale.setScalar(data.scale);}
function applyPose(){for(const rig of rigs){transform(rig.sword,pose.weapon);if(rig.kind==='first')transform(rig.root,pose.first_person);}renderOnce();}
function chooseClip(name){clipName=name;time=0;for(const rig of rigs){rig.mixer.stopAllAction();const clip=rig.clips.find(c=>c.name===name);if(!clip)continue;rig.action=rig.mixer.clipAction(clip);rig.action.play();duration=clip.duration;}$('clip').value=name;$('time').max=duration;sample(0);}
function sample(value){time=THREE.MathUtils.clamp(value,0,duration);for(const rig of rigs){for(const [b,p,q,s] of rig.rest){b.position.copy(p);b.quaternion.copy(q);b.scale.copy(s);}rig.mixer.setTime(time);rig.root.updateMatrixWorld(true);if(rig.kind==='first')anchorShoulders(rig);}$('time').value=time;$('timeLabel').value=time.toFixed(3)+' с';renderOnce();}
function anchorShoulders(rig){
 for(const side of ['r','l']){
  const upper=rig.root.getObjectByName('upperarm_'+side),lower=rig.root.getObjectByName('lowerarm_'+side),wrist=rig.root.getObjectByName('hand_'+side);
  const oldUpper=upper.matrixWorld.clone(),oldLower=lower.matrixWorld.clone(),oldWrist=wrist.matrixWorld.clone();
  const s=new THREE.Vector3(side==='r'?.32:-.32,-.6,.1),target=wrist.getWorldPosition(new THREE.Vector3());
  const reach=target.clone().sub(s),distance=THREE.MathUtils.clamp(reach.length(),.1,.76),dir=reach.normalize();target.copy(s).addScaledVector(dir,distance);
  const along=distance/2,height=Math.sqrt(Math.max(0,.39*.39-along*along));
  const pole=new THREE.Vector3(side==='r'?.6:-.6,-1,-.1).sub(s);pole.addScaledVector(dir,-pole.dot(dir)).normalize();
  const elbow=s.clone().addScaledVector(dir,along).addScaledVector(pole,height);
  const pos=m=>new THREE.Vector3().setFromMatrixPosition(m);
  function segment(bone,source,end,start,finish){
   const before=end.clone().sub(pos(source)),after=finish.clone().sub(start),axis=before.clone().normalize();
   const turn=new THREE.Matrix4().makeRotationFromQuaternion(new THREE.Quaternion().setFromUnitVectors(axis,after.clone().normalize()));
   const k=after.length()/before.length()-1,a=axis;
   const stretch=new THREE.Matrix4().set(1+k*a.x*a.x,k*a.x*a.y,k*a.x*a.z,0,k*a.y*a.x,1+k*a.y*a.y,k*a.y*a.z,0,k*a.z*a.x,k*a.z*a.y,1+k*a.z*a.z,0,0,0,0,1);
   source.setPosition(0,0,0);const matrix=turn.multiply(stretch).multiply(source);matrix.setPosition(start);
   matrix.premultiply(bone.parent.matrixWorld.clone().invert());matrix.decompose(bone.position,bone.quaternion,bone.scale);rig.root.updateMatrixWorld(true);
  }
  segment(upper,oldUpper,pos(oldLower),s,elbow);segment(lower,oldLower,pos(oldWrist),elbow,target);
  oldWrist.setPosition(target);const local=wrist.parent.matrixWorld.clone().invert().multiply(oldWrist);local.decompose(wrist.position,wrist.quaternion,wrist.scale);rig.root.updateMatrixWorld(true);
 }
}
function chooseView(view){mode=view;for(const rig of rigs)rig.root.visible=rig.kind===(view==='first'?'first':'third');floor.visible=view!=='first';scene.children.find(o=>o.type==='GridHelper').visible=view!=='first';controls.enabled=view!=='first';
 if(view==='first'){camera.position.set(0,0,0);camera.quaternion.identity();camera.fov=68;}else if(view==='grip'){
 const hand=rigs[0].hand.getWorldPosition(new THREE.Vector3());camera.position.copy(hand).add(new THREE.Vector3(.24,.18,-.35));controls.target.copy(hand);camera.lookAt(hand);camera.fov=48;
 }else{camera.position.set(2.7,1.8,-3.3);controls.target.set(0,1,0);camera.lookAt(controls.target);camera.fov=68;}camera.updateProjectionMatrix();renderOnce();}
function renderOnce(){if(!rigs.length)return;markers.visible=$('axes').checked&&mode!=='first';renderer.render(scene,camera);$('badge').textContent=`${mode==='first'?'FIRST PERSON':mode==='grip'?'PALM / SOCKET':'THIRD PERSON'}\n${clipName} · ${time.toFixed(3)} s`;
 const hand=rigs.find(r=>r.kind===(mode==='first'?'first':'third')).hand.getWorldPosition(new THREE.Vector3());$('status').textContent=`Кисть: ${hand.toArray().map(n=>n.toFixed(3)).join(' / ')}\n${renderer.info.render.triangles.toLocaleString()} triangles · ${renderer.info.render.calls} draw calls`;
}
$('clip').onchange=()=>chooseClip($('clip').value);$('time').oninput=()=>{playing=false;sample(Number($('time').value));};$('play').onclick=()=>{playing=!playing;$('play').textContent=playing?'❚❚ Пауза':'▶ Играть';};$('prev').onclick=()=>{playing=false;sample(time-1/30);};$('next').onclick=()=>{playing=false;sample(time+1/30);};$('axes').onchange=renderOnce;
for(const button of document.querySelectorAll('[data-view]'))button.onclick=()=>chooseView(button.dataset.view);
$('save').onclick=async()=>{const result=await fetch('/api/pose',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(pose)});$('status').textContent=result.ok?'Сохранено: forest_game/combat_pose.json':await result.text();};
$('reset').onclick=async()=>{pose=await(await fetch('/api/pose')).json();rebuildInputs();};
addEventListener('keydown',event=>{if(['INPUT','SELECT'].includes(event.target.tagName))return;if(event.code==='Space'){event.preventDefault();$('play').click();}if(event.code==='ArrowRight')$('next').click();if(event.code==='ArrowLeft')$('prev').click();});
const observer=new ResizeObserver(()=>{const rect=$('stage').getBoundingClientRect();renderer.setSize(rect.width,rect.height,false);camera.aspect=rect.width/rect.height;camera.updateProjectionMatrix();renderOnce();});observer.observe($('stage'));
let last=performance.now();renderer.setAnimationLoop(now=>{const delta=Math.min((now-last)/1000,.1);last=now;if(playing)sample((time+delta*Number($('speed').value))%duration);if(controls.enabled)controls.update();renderer.render(scene,camera);});
window.lab={sample,chooseClip,chooseView,pose,applyPose,renderer,rigs,camera,controls};
