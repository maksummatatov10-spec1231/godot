"""Deterministic village composition; authored routes, single trees and shared art/physics."""
from pathlib import Path
import json
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
    image.save(OUT / (name+'.png'))
    # Sort at the physical base, NEVER the transparent bottom of an atlas crop.
    base = footprint[1]+footprint[3] if footprint else image.height
    objects.append({'art':name+'.png','position':[x,y], 'size':list(image.size),
                    'sort_y':base,'sway':sway})
    if footprint:
        a,b,c,d=footprint
        solid(name.split('_')[0],x+a,y+b,c,d)


background = Image.new('RGBA',(W,H))
for y in range(0,H,16):
    for x in range(0,W,16):
        background.paste(crop('TilesetField',rng.choice([1,3,4]),7), (x,y))
paths = set()
def path(points, radius=1):
    # Only orthogonal authored routes: no diagonal single-tile stepping stones.
    for (ax,ay),(bx,by) in zip(points, points[1:]):
        assert ax==bx or ay==by
        count=max(abs(bx-ax),abs(by-ay))
        for i in range(count+1):
            x=round(ax+(bx-ax)*i/max(count,1)); y=round(ay+(by-ay)*i/max(count,1))
            for dx in range(-radius,radius+1):
                for dy in range(-radius,radius+1): paths.add((x+dx,y+dy))

# Three residential streets, an unobstructed square, woodland loop and farm approach.
path([(48,2),(48,69)])
path([(8,38),(65,38)])
path([(24,27),(65,27),(65,51),(24,51),(24,27)])
path([(24,27),(24,16),(14,16),(14,27),(24,27)])
path([(48,12),(61,12),(61,20),(65,20),(65,27)])
path([(65,51),(71,51),(71,57)])
path([(65,51),(62,51),(62,65),(85,65),(85,57)])
houses=[(448,320,0),(576,320,1),(832,320,0),(960,320,2),
        (448,480,1),(576,480,0),(832,480,2),(960,480,1),
        (448,672,2),(576,672,1),(832,672,0),(960,672,0)]
doors=[]
for x,y,k in houses:
    street={320:27,480:38,672:51}[y]
    # Door is the SECOND tile of the facade, not the centre of the whole building.
    xx=(x+24)//16; yy=(y+72)//16
    path([(xx,yy),(xx,street)])
    doors.append([x+24,y+79])
plaza={(x,y) for x in range(43,51) for y in range(35,44)}
paths |= plaza


def terrain_tile(mask,x,y,ox,oy):
    # 3x3 terrain with genuine concave corners from the same atlas family.
    left=(x-1,y) in mask;right=(x+1,y) in mask
    up=(x,y-1) in mask;down=(x,y+1) in mask
    tx=0 if not left else (2 if not right else 1)
    ty=0 if not up else (2 if not down else 1)
    image=crop('TilesetFloor',ox+tx,oy+ty)
    for dx,dy,qx,qy,cx,cy in [(-1,-1,0,0,4,7), (1,-1,8,0,7,7),
                              (-1,1,0,8,4,10),(1,1,8,8,7,10)]:
        if (x+dx,y) in mask and (x,y+dy) in mask and (x+dx,y+dy) not in mask:
            corner=crop('TilesetFloor',cx,cy)
            image.paste(corner.crop((qx,qy,qx+8,qy+8)),(qx,qy))
    return image

for x,y in sorted(paths):
    background.alpha_composite(terrain_tile(paths,x,y,0,7),(x*16,y*16))

# Organic shore; exact cyan-water collision, not a rectangular lake collider.
lake={(x,y) for x in range(67,87) for y in range(27,48)
      if ((x-77)/10)**2+((y-37)/10.5)**2<1}
for x,y in sorted(lake):
    tx=0 if (x-1,y) not in lake else (2 if (x+1,y) not in lake else 1)
    ty=0 if (x,y-1) not in lake else (2 if (x,y+1) not in lake else 1)
    tile=crop('TilesetWater',tx,6+ty)
    background.alpha_composite(tile,(x*16,y*16))
    runs={}
    for py in range(16):
        xs=[px for px in range(16) if (lambda c:c[2]>130 and c[1]>145 and c[0]<155)(tile.getpixel((px,py)))]
        if xs:
            key=(min(xs),max(xs))
            if key in runs and runs[key][1]==py:runs[key][1]+=1
            else:
                if key in runs:
                    start,end=runs[key];solid('water',x*16+key[0],y*16+start,key[1]-key[0]+1,end-start)
                runs[key]=[py,py+1]
    for (a,b),(start,end) in runs.items():solid('water',x*16+a,y*16+start,b-a+1,end-start)
for x,y in sorted(lake):
    if (x,y-1) in lake and rng.random()<.08:
        animations.append({'kind':'ripple','position':[x*16,y*16]})

# A small shore-side fishing platform, with an actual rim, supports and land approach.
platform=Image.new('RGBA',(32,48));pd=ImageDraw.Draw(platform)
pd.rectangle((0,0,31,47),fill='#5a4935')
for yy in range(2,46,6):
    pd.rectangle((2,yy,29,yy+4),fill='#b48b53');pd.line((3,yy,28,yy),fill='#d9b675')
    pd.point((4,yy+2),fill='#705635');pd.point((27,yy+2),fill='#705635')
for xx in (0,29):pd.rectangle((xx,0,xx+2,47),fill='#6f583a')
background.alpha_composite(platform,(1064,586))
# Link stays entirely west of cyan shoreline; platform is not a bridge over water.
path_jetty=Image.new('RGBA',(8,20),'#b48b53')
background.alpha_composite(path_jetty,(1056,600))

# Farm: original continuous rails with real corner posts, NOT rotated horizontal tiles.
soil={(x,y) for y in range(53,61) for x in range(66,79)}
for x,y in sorted(soil):
    background.alpha_composite(crop('TilesetFloor',1,8),(x*16,y*16))
# Tilled beds and small coherent seedlings; central 48px aisle stays clear.
bd=ImageDraw.Draw(background)
for yy in (860,892,924,956):
    for xa,xb in ((1064,1112),(1176,1256)):
        bd.rounded_rectangle((xa,yy,xb,yy+16),radius=3,fill='#9e6e48',outline='#bd8e59')
        for xx in range(xa+5,xb-3,12):
            bd.line((xx,yy+4,xx,yy+12),fill='#795c3c')
            bd.line((xx-3,yy+5,xx,yy+9,xx+3,yy+4),fill='#547b38',width=2)
            bd.point((xx-2,yy+4),fill='#bfd16b')

def fence_art(horizontal):
    im=Image.new('RGBA',(16,16));d=ImageDraw.Draw(im)
    if horizontal:
        for yy in (4,9):
            d.rectangle((0,yy,15,yy+2),fill='#594a35');d.line((0,yy,15,yy),fill='#c4a06a')
    else:
        for xx in (5,10):
            d.rectangle((xx,0,xx+2,15),fill='#594a35');d.line((xx,0,xx,15),fill='#c4a06a')
    return im
for x in range(65,80):
    for y in (52,61):
        if y==52 and 70<=x<=72:continue
        art=fence_art(True)
        start,end=0,16
        if x==65:start=8
        elif x==79:end=9
        if start:art.paste((0,0,0,0),(0,0,start,16))
        if end<16:art.paste((0,0,0,0),(end,0,16,16))
        name='fence_h_left' if start else ('fence_h_right' if end<16 else 'fence_h')
        obj(name,art,x*16,y*16,(start,4,end-start,8))
for y in range(52,62):
    for x in (65,79):
        art=fence_art(False);start,end=0,16
        if y==52:start=8
        elif y==61:end=9
        if start:art.paste((0,0,0,0),(0,0,16,start))
        if end<16:art.paste((0,0,0,0),(0,end,16,16))
        name='fence_v_top' if start else ('fence_v_bottom' if end<16 else 'fence_v')
        obj(name,art,x*16,y*16,(5,start,8,end-start))
post=Image.new('RGBA',(8,20));d=ImageDraw.Draw(post)
d.rectangle((1,2,6,19),fill='#624f38',outline='#3e4433');d.rectangle((0,0,7,4),fill='#d0b27b',outline='#624f38');d.line((2,5,2,18),fill='#b29360')
for x,y in [(1048,848),(1272,848),(1048,992),(1272,992),(1116,848),(1172,848)]:
    obj('fencepost',post,x-4,y-20,(1,16,6,4))

# Wall base = visible pixel base = sorting pivot. No unused transparent bottom margin.
for i,(x,y,variant) in enumerate(houses):
    house=Image.new('RGBA',(64,72))
    roof=crop('TilesetHouse',0 if variant!=2 else 12,0,4,3)
    if variant==1:
        pix=roof.load()
        for yy in range(roof.height):
            for xx in range(roof.width):
                r,g,b,a=pix[xx,yy]
                if a and r>g*1.15:pix[xx,yy]=(int(r*.55),int(g*.95+30),int(b*.7+20),a)
    house.alpha_composite(roof,(0,24))
    obj('house_'+str(variant),house,x,y,(3,56,58,16))
    obj('pot',crop('TilesetNature',5,13),x-12,y+58,(4,9,9,6))
    # Small flowerbeds placed BESIDE the facade, never under the doorway.
    bd.rounded_rectangle((x+68,y+56,x+88,y+74),radius=3,fill='#826645',outline='#b09b60')
    for xx in (x+70,x+80):
        background.alpha_composite(crop('TilesetNature',1,11),(xx,y+54))
    if i%3==0:
        crate=Image.new('RGBA',(16,16));cd=ImageDraw.Draw(crate)
        cd.rectangle((1,2,14,15),fill='#aa8551',outline='#514a35')
        for xx in (4,8,12):cd.line((xx,3,xx,14),fill='#705a3b')
        cd.rectangle((2,3,13,5),fill='#d1ad72');cd.rectangle((2,11,13,13),fill='#c29b62')
        cd.line((3,6,12,10),fill='#d1ad72',width=2)
        obj('crate',crate,x+72,y+80,(1,4,14,12))

well=Image.new('RGBA',(32,32));wd=ImageDraw.Draw(well)
wd.ellipse((1,10,30,31),fill='#626b59',outline='#364840')
wd.rectangle((3,17,28,26),fill='#89927a');wd.ellipse((1,6,30,24),fill='#b9b994',outline='#526553',width=2)
wd.ellipse((5,9,26,20),fill='#4eafbe',outline='#417f8c');wd.arc((7,10,24,19),0,150,fill='#a9ece6')
for xx in (7,15,23):wd.line((xx,23,xx,29),fill='#626b59')
wd.line((4,27,27,27),fill='#a2a88c')
obj('well',well,752,586,(2,12,28,18))
for x,y in [(696,568),(788,568),(696,680),(788,680)]:
    obj('bench',crop('TilesetElement',12,1,2,1),x,y,(1,7,30,8))
# Stalls are off the street, with counters and goods rather than empty roofs.
for x,y in [(648,472),(704,472),(872,864)]:
    stall=crop('TilesetHouse',16,3,3,3);sd=ImageDraw.Draw(stall)
    sd.rectangle((5,34,42,45),fill='#846342',outline='#493f31')
    sd.line((5,34,42,34),fill='#e1ba79',width=2)
    for xx in (10,18,26,34):sd.ellipse((xx,29,xx+5,34),fill='#bc653e' if xx%3 else '#a8b454',outline='#58623b')
    obj('stall',stall,x,y,(3,34,42,12))
# Beacons have their own sortable sprites. Positions are on free square corners.
lantern=Image.new('RGBA',(12,28));ld=ImageDraw.Draw(lantern)
ld.rectangle((5,8,7,27),fill='#65543a');ld.rectangle((2,2,10,10),fill='#38483a');ld.rectangle((4,4,8,8),fill='#d7c78c');ld.polygon([(1,2),(6,0),(11,2)],fill='#596647')
lantern.save(OUT/'lantern.png')
for x,y in [(684,556),(812,556),(684,716),(812,716),(1032,812),(400,600)]:
    animations.append({'kind':'lantern','position':[x,y]})
    solid('lantern',x+6,y+11,4,4)

# Every tree is ONE coherent source sprite with ONE physically matching trunk.
# The previous 4x3 crops were whole clusters with uncollidable side trunks.
tree_choices=[(3,18,3,3),(2,0,2,2),(0,0,2,2),(0,18,3,3)]
tree_positions=[]
for y in range(48,H-24,43):
    for x in range(40,W-24,46):
        xx=x+rng.randint(-12,12); yy=y+rng.randint(-10,10)
        village=420<xx<1032 and 284<yy<858
        if village or (1016<xx<1312 and 794<yy<1032):continue
        # Entire canopy and roots get clearance from roads, shore and buildings.
        if any((xx//16+dx,yy//16+dy) in paths|lake for dx in (-2,-1,0,1,2) for dy in (-2,-1,0,1)):continue
        if rng.random()<.17:continue
        tree_positions.append((xx,yy))
# Composed village trees, separated from front doors and through routes.
for x,y in [(424,355),(424,515),(424,707),(552,310),(936,310),
            (552,478),(936,478),(552,662),(936,662),(672,772),(912,772)]:
    tree_positions.append((x,y))
for x,y in tree_positions:
    choice=rng.choices(range(4),weights=[58,26,13,3])[0]
    tx,ty,tw,th=tree_choices[choice]
    trunk_w=14 if choice in (0,3) else (18 if choice==1 else 12)
    # No tree canopy may swallow an authored facade, counter, pot or crate.
    bx,by,bw,bh=x-tw*8,y-th*16,tw*16,th*16
    if any(bx<o['position'][0]+o['size'][0] and bx+bw>o['position'][0]
           and by<o['position'][1]+o['size'][1] and by+bh>o['position'][1]
           for o in objects if not o['sway']):continue
    obj('tree_'+str(choice),crop('TilesetNature',tx,ty,tw,th),x-tw*8,y-th*16,
        (tw*8-trunk_w//2,th*16-12,trunk_w,12),True)

# Coherent small flower clusters; NEVER select the crate at Nature(7,11).
for cx,cy in [(320,270),(300,480),(592,270),(860,260),(360,740),(920,1060),(1350,820),(1400,370),(280,990),(1200,280)]:
    for j in range(8):
        x=cx+rng.randint(-24,24);y=cy+rng.randint(-16,16)
        if any((x//16+dx,y//16+dy) in paths|lake for dx in (-1,0,1) for dy in (-1,0,1)):continue
        if any(a-10<x<a+c+10 and b-20<y<b+d+10 for a,b,c,d in [s['rect'] for s in solids if s['kind']!='water']):continue
        background.alpha_composite(crop('TilesetNature',rng.choice([1,2,3]),11),(x,y))
for i in range(100):
    x=rng.randrange(32,W-32);y=rng.randrange(32,H-32)
    if any((x//16+dx,y//16+dy) in paths|lake for dx in (-1,0,1) for dy in (-1,0,1)) or 420<x<1312 and 284<y<1032:continue
    animations.append({'kind':'flower','position':[x,y]})

# Static projected sunlight shadows: pixel silhouettes, unified NW -> SE direction.
# One pre-baked translucent layer is cheap; no hundreds of live shadow-casting lights.
shadow=Image.new('RGBA',(W,H));contact=ImageDraw.Draw(shadow)
for item in objects:
    x,y=item['position'];iw,ih=item['size'];base=y+item['sort_y']
    art=Image.open(OUT/item['art']).convert('RGBA')
    if item['art'].startswith('fence'):
        length=6
    elif item['art'].startswith('house'):
        length=28
    else:length=18 if item['sway'] else 9
    # Project each source row onto the ground toward bottom-right.
    mask=Image.new('L',(iw+length,ih+length))
    for sy in range(ih):
        height=max(0,item['sort_y']-sy)
        dx=round(height*length/max(ih,1));dy=round(height*.27)
        row=art.getchannel('A').crop((0,sy,iw,sy+1))
        mask.paste(row,(dx,max(0,ih+dy-1)))
    ink=Image.new('RGBA',mask.size,(35,57,48,0));ink.putalpha(mask.point(lambda a:round(a*.20)))
    shadow.alpha_composite(ink,(x,base-ih))
    contact.ellipse((x+iw*.27,base-3,x+iw*.77,base+3),fill=(35,53,41,48))
# Terrain shadow alpha is zero over water: no painted artefacts on cyan collision samples.
shadow.save(OUT/'sun_shadows.png')
for rect in [(0,0,W,20),(0,H-20,W,20),(0,0,20,H),(W-20,0,20,H)]:solid('boundary',*rect)
background.save(OUT/'ground.png')
manifest={'size':[W,H],'spawn':[776,658],'wanderer':[792,622], 'objects':objects,'solids':solids,'animations':animations,
          'paths':[list(p) for p in sorted(paths)],'doors':doors,
          'sun_direction':[0.8,0.6],
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
