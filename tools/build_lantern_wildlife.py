"""Original CC0 wildlife revision: sculpted silhouettes, clustered fur and planted gait.

32px cells, 12 phases, down/up/left/right × idle/walk/bound. No baked shadows.
All poses are drawn from anatomical layers, not resized or translated old frames.
"""
from pathlib import Path
import math
import json
from PIL import Image, ImageDraw

OUT = Path(__file__).resolve().parents[1] / 'lantern_game/assets/world'
SIZE, FRAMES = 32, 12
FOX = dict(ink='#3a3441', low='#793f3d', shadow='#a94e37', base='#db753d',
           gold='#ed9d50', light='#f8c879', white='#fff0cb', cream='#e8cea8',
           grey='#ae9b91', pink='#d58479')
RABBIT = dict(ink='#514954', low='#817580', shadow='#a39394', base='#c8b6ac',
              gold='#e3cfba', light='#f5e4cb', white='#fff4d9', cream='#e8d6bf',
              grey='#b0a09f', pink='#dc9d9f')


def xy(p):
    return tuple(round(v) for v in p)


def poly(d, pts, color):
    d.polygon([xy(p) for p in pts], fill=color)


def line(d, pts, color, width=1):
    d.line([xy(p) for p in pts], fill=color, width=width)


def oval(d, box, color):
    d.ellipse(tuple(round(v) for v in box), fill=color)


def side(species, gait, phase):
    p=FOX if species=='fox' else RABBIT
    rabbit=species=='rabbit'; moving=gait!='idle'; bound=gait=='bound'
    im=Image.new('RGBA',(32,32));d=ImageDraw.Draw(im)
    s=math.sin(phase);c=math.cos(phase)
    bounce=(-max(0,math.sin(phase*2))*(1.3 if bound else .55)) if moving else 0
    y=(20 if rabbit else 18)+bounce
    # Tail has a broad, recognizable silhouette and a light terminal tuft.
    if not rabbit:
        ty=y+round(s*1.5);tx=round(c)
        poly(d,[(12,y+1),(8,y),(5,ty-3),(2,ty-4),(0,ty-1),(1,ty+3),
                (4+tx,ty+6),(8,ty+6),(12,y+4)],p['ink'])
        poly(d,[(11,y+1),(8,y+1),(5,ty-2),(2,ty-3),(1,ty),(3,ty+3),
                (6+tx,ty+5),(9,ty+4)],p['base'])
        poly(d,[(2,ty-3),(1,ty),(3,ty+3),(5,ty+4),(6,ty+1),(4,ty+1),(4,ty-1)],p['white'])
        line(d,[(6,ty-1),(8,ty+1),(10,y+2)],p['gold'])
        line(d,[(5,ty+5),(8,ty+5)],p['shadow'])
    else:
        oval(d,(4,y-1,11,y+5),p['ink']);oval(d,(5,y-1,10,y+4),p['cream'])
        oval(d,(5,y-1,8,y+1),p['white'])
    # Far legs precede body; near legs are tucked smoothly into haunch/chest.
    def feet(near):
        for front in [False,True]:
            angle=phase+(0 if front else math.pi)+(0 if near or bound else math.pi)
            extension=math.sin(angle)*(3 if bound else 2) if moving else 0
            lift=max(0,math.cos(angle))*2 if moving else 0
            hx=22 if front else 12
            toe=(hx+extension,28-lift)
            if rabbit and not front:
                oval(d,(hx-4,y-1,hx+3,y+6),p['shadow'] if not near else p['base'])
                poly(d,[(hx,y+3),(hx+4,y+5),(toe[0]+3,toe[1]),(toe[0]-2,toe[1]),(hx-2,y+5)],p['ink'])
                line(d,[(hx,y+4),(toe[0],toe[1]-1),(toe[0]+2,toe[1]-1)],p['gold'] if near else p['shadow'],2)
            else:
                line(d,[(hx,y+3),(hx-1+extension*.4,y+6),toe],p['ink'],3)
                line(d,[(hx,y+3),(hx-1+extension*.4,y+6)],p['base'] if near else p['shadow'],2)
                line(d,[(toe[0]-1,toe[1]),(toe[0]+1,toe[1])],p['low'],1)
                if near:d.point(xy((toe[0],toe[1]-1)),fill=p['gold'])
    feet(False)
    poly(d,[(8,y),(10,y-4),(14,y-6),(19,y-5),(23,y-4),(25,y),
            (23,y+5),(18,y+6),(12,y+5),(8,y+3)],p['ink'])
    poly(d,[(9,y),(11,y-3),(14,y-5),(19,y-4),(23,y-3),(24,y),
            (22,y+4),(17,y+5),(12,y+4),(9,y+2)],p['base'])
    poly(d,[(10,y+2),(16,y+2),(21,y+1),(23,y),(22,y+4),(17,y+5),(12,y+4)],p['shadow'])
    poly(d,[(10,y-1),(12,y-3),(16,y-4),(20,y-3),(20,y-1),(15,y),(12,y)],p['gold'])
    line(d,[(12,y-3),(15,y-4),(18,y-3)],p['light'])
    if rabbit:
        oval(d,(8,y-4,17,y+4),p['base']);oval(d,(9,y-4,15,y),p['gold'])
        line(d,[(10,y-3),(12,y-4)],p['light'])
    else:
        poly(d,[(20,y-3),(23,y-4),(25,y),(23,y+4),(21,y+4),(19,y+1)],p['cream'])
        line(d,[(21,y-2),(23,y),(22,y+2)],p['white'])
    feet(True)
    hy=y-7+(round(math.sin(phase+.5)*.6) if moving else 0)
    # Independent far and near ears, with dark outer fur and rose inner planes.
    for ex,lag in [(20,.8),(25,0)]:
        bend=round(math.sin(phase+lag)*(1.4 if moving else .9))
        length=8 if rabbit else 5
        poly(d,[(ex-2,hy+1),(ex-2+bend,hy-length),(ex+bend,hy-length-1),(ex+2,hy+1)],p['ink'])
        line(d,[(ex,hy-1),(ex-1+bend,hy-length+1)],p['shadow'],2)
        line(d,[(ex,hy-2),(ex+bend,hy-length+2)],p['pink'])
    if rabbit:
        oval(d,(19,hy-2,28,hy+7),p['ink']);oval(d,(20,hy-2,27,hy+6),p['base'])
        poly(d,[(21,hy-1),(25,hy-2),(26,hy),(22,hy+1)],p['gold'])
        oval(d,(23,hy+3,29,hy+6),p['cream']);d.point(xy((29,hy+4)),fill=p['pink'])
        line(d,[(26,hy+6),(28,hy+6)],p['low'])
    else:
        poly(d,[(19,hy),(21,hy-3),(25,hy-3),(27,hy),(28,hy+2),(31,hy+3),
                (30,hy+5),(26,hy+6),(23,hy+8),(19,hy+5),(20,hy+3)],p['ink'])
        poly(d,[(20,hy),(22,hy-2),(25,hy-2),(26,hy),(27,hy+3),(30,hy+3),
                (29,hy+4),(25,hy+5),(23,hy+7),(20,hy+4),(21,hy+3)],p['base'])
        poly(d,[(21,hy+3),(24,hy+4),(27,hy+2),(29,hy+3),(29,hy+4),
                (25,hy+5),(23,hy+7),(21,hy+5)],p['white'])
        line(d,[(22,hy-1),(24,hy-2),(25,hy-1)],p['gold'])
        d.point(xy((30,hy+3)),fill=p['ink'])
    blink=gait=='idle' and int(phase/math.tau*12)==9
    line(d,[(25,hy+1),(26,hy+1)],p['ink'])
    if not blink:
        line(d,[(26,hy),(26,hy+2)],p['ink']);d.point(xy((26,hy)),fill=p['white'])
    # Moving whiskers/fur clusters are tiny changes, never a whole-body idle bob.
    d.point(xy((22,y+round(c))),fill=p['light'])
    return im


def vertical(species,gait,phase,back):
    p=FOX if species=='fox' else RABBIT;rabbit=species=='rabbit'
    im=Image.new('RGBA',(32,32));d=ImageDraw.Draw(im)
    moving=gait!='idle';bound=gait=='bound'
    y=19-(max(0,math.sin(phase*2))*(1.4 if bound else .5) if moving else 0)
    for x,a in [(11,phase),(20,phase+math.pi)]:
        step=math.sin(a)*2 if moving else 0
        oval(d,(x-2,y+3,x+2,28+step),p['ink'])
        line(d,[(x-1,27+step),(x+1,27+step)],p['gold'] if rabbit else p['low'])
    poly(d,[(9,y-5),(12,y-7),(19,y-7),(23,y-3),(24,y+3),(21,y+7),
            (10,y+7),(7,y+3),(8,y-2)],p['ink'])
    poly(d,[(10,y-5),(13,y-6),(19,y-6),(22,y-2),(23,y+3),(20,y+6),
            (11,y+6),(8,y+2),(9,y-2)],p['base'])
    poly(d,[(9,y),(14,y+2),(21,y),(22,y+4),(20,y+6),(11,y+6)],p['shadow'])
    oval(d,(10,y-5,19,y+1),p['gold']);line(d,[(12,y-5),(15,y-6),(18,y-5)],p['light'])
    if back:
        if rabbit:
            oval(d,(12,y+2,19,y+8),p['ink']);oval(d,(13,y+2,18,y+7),p['cream'])
            line(d,[(14,y+3),(16,y+3)],p['white'])
        else:
            wag=round(math.sin(phase)*2)
            poly(d,[(13,y),(18,y),(20+wag,y+5),(18+wag,30),(14+wag,30),(12+wag,y+6)],p['ink'])
            poly(d,[(14,y+1),(17,y+1),(19+wag,y+5),(17+wag,29),(15+wag,29),(13+wag,y+6)],p['base'])
            poly(d,[(14+wag,27),(18+wag,26),(17+wag,29),(15+wag,29)],p['white'])
    else:
        poly(d,[(11,y-2),(20,y-2),(21,y+2),(18,y+5),(15,y+6),(11,y+3)],p['cream'])
        line(d,[(13,y),(16,y+3),(18,y+2)],p['white'])
    hy=y-8
    for ex,sign in [(10,-1),(21,1)]:
        lean=round(math.sin(phase+sign)*1.1);length=8 if rabbit else 5
        poly(d,[(ex-2,hy+1),(ex-2+lean,hy-length),(ex+lean,hy-length-1),(ex+3,hy+1)],p['ink'])
        poly(d,[(ex-1,hy),(ex-1+lean,hy-length+1),(ex+lean,hy-length),(ex+2,hy)],p['gold'] if back else p['pink'])
    poly(d,[(9,hy-2),(13,hy-4),(18,hy-4),(22,hy-2),(24,hy+3),(21,hy+7),
            (16,hy+9),(10,hy+7),(7,hy+3)],p['ink'])
    poly(d,[(10,hy-2),(13,hy-3),(18,hy-3),(21,hy-2),(23,hy+3),(20,hy+6),
            (16,hy+8),(11,hy+6),(8,hy+3)],p['base'])
    poly(d,[(11,hy-1),(14,hy-3),(18,hy-2),(20,hy),(17,hy+1),(13,hy+1)],p['gold'])
    line(d,[(13,hy-2),(16,hy-3),(18,hy-2)],p['light'])
    if not back:
        poly(d,[(9,hy+3),(12,hy+3),(15,hy+5),(19,hy+3),(22,hy+3),(20,hy+6),
                (16,hy+8),(11,hy+6)],p['cream'])
        line(d,[(11,hy+4),(14,hy+6),(17,hy+6),(20,hy+4)],p['white'])
        for x in [11,20]:
            d.point(xy((x,hy+1)),fill=p['ink'])
            if not(gait=='idle' and int(phase/math.tau*12)==9):
                d.point(xy((x,hy)),fill=p['white'])
        line(d,[(15,hy+5),(16,hy+5)],p['pink'] if rabbit else p['ink'])
    # Deliberate alternating cluster along the crown, preserves all 12 idle poses.
    d.point((13+int(phase/math.tau*12)%5,round(hy-1)),fill=p['light'])
    line(d,[(10,hy+3),(11,hy+4)],p['grey'])
    d.point(xy((20,hy+4)),fill=p['low'])
    return im


def main():
    OUT.mkdir(exist_ok=True,parents=True)
    for species in ['fox','rabbit']:
        sheet=Image.new('RGBA',(384,384))
        for gait_index,gait in enumerate(['idle','walk','bound']):
            for direction in range(4):
                for frame in range(FRAMES):
                    phase=math.tau*frame/FRAMES
                    tile=side(species,gait,phase) if direction>=2 else vertical(species,gait,phase,direction==1)
                    if direction==2:tile=tile.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
                    sheet.alpha_composite(tile,(frame*32,(gait_index*4+direction)*32))
        sheet.save(OUT/f'{species}.png')
    (OUT/'wildlife.json').write_text(json.dumps({'cell_size':32,'frames':12,
        'directions':['down','up','left','right'],'gaits':['idle','walk','bound'],
        'license':'CC0-1.0','author':'Lantern Valley contributors','revision':'foundation-2',
        'source':'tools/build_lantern_wildlife.py'},indent=2)+'\n')


if __name__=='__main__':
    main()
