"""Run with Blender --background --factory-startup --disable-autoexec --python.

Reads models only, never installs or enables supplied addons. Writes JSONL
checkpoints and isometric geometry projections, not production renderings.
"""
import bpy
import json
import math
from pathlib import Path
import sys
import traceback
from mathutils import Vector

args=sys.argv[sys.argv.index('--')+1:]
root, catalog, output=map(Path,args)
records=json.loads(catalog.read_text())
output.mkdir(parents=True,exist_ok=True)
thumbs=output/'geometry';thumbs.mkdir(exist_ok=True)
log=output/'blender-models.jsonl'
completed=set()
if log.exists():
    for line in log.read_text().splitlines():
        try:completed.add(json.loads(line)['sha256'])
        except json.JSONDecodeError:pass
models=[r for r in records if r['extension'] in {'.fbx','.blend','.gltf','.glb','.obj','.hdr','.exr'}]
for index,record in enumerate(models):
    digest=record['sha256']
    if digest in completed:continue
    path=root/record['path']
    result={'path':record['path'],'sha256':digest,'blender':bpy.app.version_string}
    try:
        bpy.ops.wm.read_factory_settings(use_empty=True)
        bpy.context.preferences.filepaths.use_scripts_auto_execute=False
        ext=record['extension']
        if ext in {'.hdr','.exr'}:
            image=bpy.data.images.load(str(path),check_existing=False)
            # Access actual pixels to force decoder execution.
            result['image']={'width':image.size[0],'height':image.size[1], 'channels':image.channels,'float':image.is_float,'pixel_values':len(image.pixels),'first_pixel':list(image.pixels[:4])}
        else:
            if ext=='.fbx':bpy.ops.import_scene.fbx(filepath=str(path),use_anim=True)
            elif ext=='.blend':bpy.ops.wm.open_mainfile(filepath=str(path),load_ui=False,use_scripts=False)
            elif ext in {'.gltf','.glb'}:bpy.ops.import_scene.gltf(filepath=str(path))
            elif ext=='.obj':bpy.ops.wm.obj_import(filepath=str(path))
            meshes=[o for o in bpy.context.scene.objects if o.type=='MESH']
            arms=[o for o in bpy.context.scene.objects if o.type=='ARMATURE']
            result.update(objects=len(bpy.context.scene.objects),meshes=len(meshes),vertices=sum(len(o.data.vertices) for o in meshes),polygons=sum(len(o.data.polygons) for o in meshes),triangles=sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in meshes), materials=len(bpy.data.materials),armatures=len(arms),bones=sum(len(o.data.bones) for o in arms),actions=[{'name':a.name,'frames':[float(f) for f in a.frame_range]} for a in bpy.data.actions],object_names=[o.name for o in bpy.context.scene.objects],images=[{'name':im.name,'filepath':im.filepath,'packed':im.packed_file is not None} for im in bpy.data.images])
            points=[o.matrix_world@Vector(corner) for o in meshes for corner in o.bound_box]
            if points:
                low=[min(v[i] for v in points) for i in range(3)];high=[max(v[i] for v in points) for i in range(3)]
                result['bounds']=[low,high];result['dimensions']=[high[i]-low[i] for i in range(3)]
            polygons=[];lines=[]
            for o in meshes:
                vertices=[o.matrix_world@v.co for v in o.data.vertices]
                step=max(1,math.ceil(len(o.data.polygons)/6000))
                for p in list(o.data.polygons)[::step]:
                    pts=[vertices[v] for v in p.vertices]
                    color=(0.55,0.65,0.72,1)
                    if p.material_index<len(o.data.materials) and o.data.materials[p.material_index]:
                        mat=o.data.materials[p.material_index];color=mat.diffuse_color
                        if mat.use_nodes:
                            node=next((n for n in mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED'),None)
                            if node:color=node.inputs['Base Color'].default_value
                    normal=o.matrix_world.to_3x3()@p.normal
                    shade=0.55+0.45*abs(normal.normalized().dot(Vector((0.4,-0.5,0.8)).normalized()))
                    rgb=[min(255,max(0,int((max(0,c)**(1/2.2))*255*shade))) for c in color[:3]]
                    polygons.append({'points':[[float(v.x-v.y)*0.7071,float(v.z*0.8165-(v.x+v.y)*0.4082)] for v in pts],'depth':sum(v.x+v.y+v.z for v in pts)/len(pts),'rgb':rgb})
            for o in arms:
                for bone in o.data.bones:
                    a=o.matrix_world@bone.head_local;b=o.matrix_world@bone.tail_local
                    lines.append([[float(v.x-v.y)*0.7071,float(v.z*0.8165-(v.x+v.y)*0.4082)] for v in [a,b]])
            (thumbs/(digest+'.json')).write_text(json.dumps({'polygons':polygons,'bones':lines},separators=(',',':')))
            result['preview']='isometric untextured geometry projection; max 6000 sampled polygons per object; rest pose'
        result['status']='ok'
    except Exception as exc:
        result.update(status='error',error=f'{type(exc).__name__}: {exc}')
        traceback.print_exc()
    with log.open('a') as f:f.write(json.dumps(result,ensure_ascii=False)+'\n')
    completed.add(digest)
    print('INSPECT_PROGRESS',index+1,'/',len(models),path.name,result['status'],flush=True)
print('INSPECT_COMPLETE',len(completed),flush=True)
