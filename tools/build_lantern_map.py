"""Deterministic art assembly. Visual footprints and physics share one manifest."""
from pathlib import Path
import json
import math
import random
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1] / 'lantern_game'
ART = ROOT / 'assets/ninja'
OUT = ROOT / 'assets/world'
OUT.mkdir(parents=True, exist_ok=True)
rng = random.Random(317)
W, H = 1536, 1152
sheets = {}
objects, solids, animations = [], [], []


def crop(sheet, x, y, w=1, h=1):
    if sheet not in sheets:
        sheets[sheet] = Image.open(ART / ('Backgrounds/Tilesets/' + sheet + '.png')).convert('RGBA')
    return sheets[sheet].crop((x*16, y*16, (x+w)*16, (y+h)*16))


def solid(kind, x, y, w, h):
    solids.append({'kind': kind, 'rect': [x,y,w,h]})


def obj(name, image, x, y, footprint=None, sway=False):
    target = OUT / (name+'.png')
    image.save(target)
    objects.append({'art': name+'.png', 'position': [x,y], 'size': list(image.size), 'sway': sway})
    if footprint:
        a,b,c,d = footprint
        solid(name.split('_')[0],x+a,y+b,c,d)


background = Image.new('RGBA',(W,H))
for y in range(0,H,16):
    for x in range(0,W,16):
        background.paste(crop('TilesetField',rng.choice([1,3,4]),7), (x,y))
paths = set()
def path(points, radius=1):
    for (ax,ay),(bx,by) in zip(points, points[1:]):
        count=max(abs(bx-ax),abs(by-ay))
        for i in range(count+1):
            x=round(ax+(bx-ax)*i/max(count,1)); y=round(ay+(by-ay)*i/max(count,1))
            for dx in range(-radius,radius+1):
                for dy in range(-radius,radius+1): paths.add((x+dx,y+dy))

path([(48,6),(48,66)],1)
path([(8,38),(85,38)],1)
path([(24,24),(24,51),(61,51)],1)
path([(24,24),(62,24),(62,38)],1)
path([(62,38),(62,57),(78,57),(85,64)],1)
path([(24,38),(17,31),(10,29)],0)
path([(48,14),(60,12),(74,17),(82,22)],0)
# Doorways connect every building, not decorative dead ends.
houses=[(448,320,0),(576,320,1),(832,320,0),(960,320,2),
        (448,480,1),(576,480,0),(832,480,2),(960,480,1),
        (448,672,2),(576,672,1),(832,672,0),(960,672,0)]
for x,y,k in houses:
    xx=(x+32)//16; yy=(y+80)//16
    nearest=min(paths,key=lambda p:(p[0]-xx)**2+(p[1]-yy)**2)
    path([(xx,yy), (xx,nearest[1]),nearest],0)

def autotile(mask, x,y, ox,oy):
    xx=0 if (x-1,y) not in mask else (2 if (x+1,y) not in mask else 1)
    yy=0 if (x,y-1) not in mask else (2 if (x,y+1) not in mask else 1)
    return ox+xx,oy+yy
for x,y in sorted(paths):
    tx,ty=autotile(paths,x,y,0,7)
    background.alpha_composite(crop('TilesetFloor',tx,ty),(x*16,y*16))
plaza={(x,y) for x in range(43,53) for y in range(33,44)}
for x,y in plaza:
    tx,ty=autotile(plaza,x,y,0,0)
    background.alpha_composite(crop('TilesetFloor',tx,ty),(x*16,y*16))
# Organic tile shoreline, grass-edged rather than a blue rectangle.
lake={(x,y) for x in range(67,87) for y in range(27,48)
      if ((x-77)/10)**2+((y-37)/10.5)**2<1}
for x,y in sorted(lake):
    tx,ty=autotile(lake,x,y,0,6)
    tile=crop('TilesetWater',tx,ty)
    background.alpha_composite(tile,(x*16,y*16))
    # Derive exact cyan-water runs from the source artwork, then merge vertically.
    runs={}
    for py in range(16):
        xs=[px for px in range(16) if (lambda c: c[2]>130 and c[1]>145 and c[0]<155)(tile.getpixel((px,py)))]
        if xs:
            key=(min(xs),max(xs))
            if key in runs and runs[key][1]==py: runs[key][1]+=1
            else:
                if key in runs:
                    start,end=runs[key];solid('water',x*16+key[0],y*16+start,key[1]-key[0]+1,end-start)
                runs[key]=[py,py+1]
    for (a,b),(start,end) in runs.items(): solid('water',x*16+a,y*16+start,b-a+1,end-start)
# Water ripples remain animated in play.
for x,y in sorted(lake):
    if (x,y-1) in lake and rng.random()<.08:
        animations.append({'kind':'ripple','position':[x*16,y*16]})
# Fishing jetty on the west edge, not over impassable water.
for x in range(65,68):
    for y in range(36,39):
        if (x,y) not in lake: background.alpha_composite(crop('TilesetWater',1,12),(x*16,y*16))
# Farm soil with beds, open central gate, visible fence rails.
for y in range(53,61):
    for x in range(66,79):
        background.alpha_composite(crop('TilesetFloor',6,8),(x*16,y*16))
        if y%2 and x%3!=0:
            background.alpha_composite(crop('TilesetNature',rng.choice([4,5,6]),10),(x*16,y*16-2))
for x in range(65,80):
    for y in (52,61):
        if y==52 and 70<=x<=72: continue
        obj('fence_h',crop('TilesetHouse',11,7),x*16,y*16,(0,4,16,8))
for y in range(53,61):
    for x in (65,79): obj('fence_v',crop('TilesetHouse',11,7).transpose(Image.Transpose.ROTATE_90),x*16,y*16,(4,0,8,16))
# Buildings use opaque wall art below the overhanging roof; feet collide with wall, not canopy.
for i,(x,y,variant) in enumerate(houses):
    name='house_'+str(variant)
    house=Image.new('RGBA',(64,80))
    roof=crop('TilesetHouse',0 if variant!=2 else 12,0,4,3)
    if variant==1:
        # CC0 palette-derived moss roof variant.
        pix=roof.load()
        for yy in range(roof.height):
            for xx in range(roof.width):
                r,g,b,a=pix[xx,yy]
                if a and r>g*1.15: pix[xx,yy]=(int(r*.55),int(g*.95+30),int(b*.7+20),a)
    house.alpha_composite(roof,(0,24))
    obj(name,house,x,y,(3,56,58,16))
    # Pot and sign at individual entrances.
    obj('pot',crop('TilesetNature',5,13),x-12,y+58,(4,9,9,6))
    if i%3==0: obj('crate',crop('TilesetElement',3,0),x+66,y+56,(1,4,14,12))
# Well, benches, market stalls, lantern posts.
well=Image.new('RGBA',(32,32));wd=ImageDraw.Draw(well)
wd.ellipse((1,10,30,31),fill='#626b59',outline='#364840')
wd.rectangle((3,17,28,26),fill='#89927a')
wd.ellipse((1,6,30,24),fill='#b9b994',outline='#526553',width=2)
wd.ellipse((5,9,26,20),fill='#4eafbe',outline='#417f8c')
wd.arc((7,10,24,19),0,150,fill='#a9ece6')
for xx in (7,15,23):wd.line((xx,23,xx,29),fill='#626b59')
wd.line((4,27,27,27),fill='#a2a88c')
obj('well',well,752,586,(2,12,28,18))
for x,y in [(696,584),(820,584),(696,672),(820,672)]:
    obj('bench',crop('TilesetElement',12,1,2,1),x,y,(1,7,30,8))
for x,y in [(648,440),(744,440),(872,792)]:
    obj('stall',crop('TilesetHouse',16,3,3,3),x,y,(3,29,42,16))
for x,y in [(688,544),(848,544),(688,704),(848,704),(1024,832),(400,608)]:
    animations.append({'kind':'lantern','position':[x,y]})
# Deliberately composed grove edges, then a forest ring with clear trails.
tree_choices=[(4,2,4,3),(0,2,4,3),(16,2,4,3),(0,18,3,3),(9,18,3,3)]
tree_positions=[]
for y in range(48,H-48,43):
    for x in range(48,W-48,46):
        xx=x+rng.randint(-14,14); yy=y+rng.randint(-12,12)
        village=352<xx<1056 and 254<yy<870
        if village or (1024<xx<1312 and 800<yy<1024) or (xx//16,yy//16) in lake or (xx//16,yy//16) in paths: continue
        if any((xx//16+dx,yy//16+dy) in paths|lake for dx in (-1,0,1) for dy in (0,1)):continue
        if rng.random()<.22:continue
        tree_positions.append((xx,yy))
for x,y in [(388,326),(388,484),(388,694),(544,404),(932,404),(546,758),(924,758),
            (1100,380),(1180,792),(1024,268),(680,288),(864,864)]: tree_positions.append((x,y))
for i,(x,y) in enumerate(tree_positions):
    tx,ty,tw,th=rng.choices(tree_choices,weights=[45,20,30,4,1])[0]
    obj('tree_'+str(tree_choices.index((tx,ty,tw,th))),crop('TilesetNature',tx,ty,tw,th),x-tw*8,y-th*16,(tw*8-5,th*16-10,10,9),True)
# Low flowers do not block feet. No random detail painted over paths or water.
for i in range(850):
    x=rng.randrange(24,W-24);y=rng.randrange(24,H-24)
    if any((x//16+dx,y//16+dy) in paths|plaza|lake for dx in (-1,0,1) for dy in (-1,0,1)) or 1030<x<1280 and 825<y<996:continue
    if rng.random()<.8:
        tile=crop('TilesetNature',rng.choice([0,1,2,3,4,5,6,7,8]),11)
        background.alpha_composite(tile,(x,y))
    else:animations.append({'kind':'flower','position':[x,y]})
# World edges remain physical, hidden inside dense woods.
for rect in [(0,0,W,20),(0,H-20,W,20),(0,0,20,H),(W-20,0,20,H)]:solid('boundary',*rect)
background.save(OUT/'ground.png')
manifest={'size':[W,H],'spawn':[776,658],'wanderer':[792,622], 'objects':objects,'solids':solids,'animations':animations,
          'views':{'village':[768,620],'lake':[1152,610],'farm':[1136,894],'forest':[300,496]}}
(OUT/'map.json').write_text(json.dumps(manifest,separators=(',',':'))+'\n')
# Original small wildlife sheets: four directions x four phases, matching source palette.
for species in ['fox','rabbit']:
    sheet=Image.new('RGBA',(64,64))
    for direction in range(4):
        for frame in range(4):
            tile=Image.new('RGBA',(16,16));d=ImageDraw.Draw(tile)
            outline='#343e3b';fur='#d58b49' if species=='fox' else '#dcd4ba'; light='#f5e5c4'
            bob=frame%2; side=direction>=2
            if side:
                d.rectangle((3,7+bob,11,12+bob),fill=outline);d.rectangle((4,7+bob,11,11+bob),fill=fur)
                d.polygon([(1,8),(0,5),(5,8),(6,11),(2,11)],fill=fur)
                d.rectangle((0,5,1,7),fill=light)
                d.rectangle((10,5+bob,14,10+bob),fill=fur)
                d.polygon([(10,6),(10,2 if species=='rabbit' else 4),(12,5)],fill=fur)
                d.polygon([(13,6),(14,2 if species=='rabbit' else 4),(15,7)],fill=fur)
                d.point((13,7+bob),fill=outline);d.rectangle((13,10+bob,15,11+bob),fill=light)
                if direction==2:tile=tile.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
            else:
                d.ellipse((4,5+bob,12,13+bob),fill=outline);d.ellipse((5,5+bob,11,12+bob),fill=fur)
                d.rectangle((5,2,6,6),fill=fur);d.rectangle((10,2,11,6),fill=fur)
                if direction==0:
                    d.rectangle((6,10+bob,10,12+bob),fill=light);d.point((6,7+bob),fill=outline);d.point((10,7+bob),fill=outline)
                else:d.rectangle((7,11+bob,9,14+bob),fill=light)
            d.rectangle((4+(frame%2),12,5+(frame%2),14),fill=outline)
            d.rectangle((10-(frame%2),12,11-(frame%2),14),fill=outline)
            sheet.alpha_composite(tile,(frame*16,direction*16))
    sheet.save(OUT/(species+'.png'))
print('MAP_BUILT', len(objects),'objects,',len(solids),'solid shapes')
