"""Original layered pixel-art wildlife, CC0. No external sprites / AI-generated sheet.

32px cells; four directions, twelve articulated poses per idle/walk/bound cycle.
Body planes, fur clusters, joints, ears, toes, muzzle and tail are separate layers.
Run this independently of the world builder: it never rewrites the map/colliders.
"""
from pathlib import Path
import math
import json
from PIL import Image, ImageDraw

OUT = Path(__file__).resolve().parents[1] / 'lantern_game/assets/world'
SIZE, FRAMES = 32, 12
FOX = dict(out='#493531', dark='#754133', shade='#a65032', fur='#cb6c36', mid='#e18b45',
           light='#f3ad5a', cream='#f4dfb4', white='#fff0cc', paw='#4e3635', pink='#bb7971')
RABBIT = dict(out='#615a54', dark='#81766b', shade='#a99a83', fur='#c9b99a', mid='#e1d0ac',
              light='#f3e3c2', cream='#fff0d0', white='#fff7dc', paw='#938270', pink='#d79c91')


def point(p):
    return tuple(round(v) for v in p)


def polygon(d, points, color):
    d.polygon([point(p) for p in points], fill=color)


def ellipse(d, box, color):
    d.ellipse(tuple(round(v) for v in box), fill=color)


def line(d, points, color, width=1):
    d.line([point(p) for p in points], fill=color, width=width)


def limb(d, hip, knee, toe, p, near):
    # Bent knee, tapered ankle and highlighted toes, not translated rectangles.
    line(d, [hip, knee, toe], p['out'], 3 if near else 2)
    line(d, [hip, knee], p['fur'] if near else p['shade'], 2)
    line(d, [knee, toe], p['paw'], 2)
    line(d, [(toe[0]-1, toe[1]), (toe[0]+1, toe[1])], p['paw'], 1)
    if near:
        d.point(point((toe[0]+1, toe[1]-1)), fill=p['mid'])


def side(species, gait, phase):
    p = FOX if species == 'fox' else RABBIT
    image = Image.new('RGBA', (SIZE, SIZE)); d = ImageDraw.Draw(image)
    moving = gait != 'idle'; bound = gait == 'bound'
    wave = math.sin(phase); lift = max(0, math.sin(phase * 2))
    bob = (-1.4 * lift if bound else -0.45 * math.cos(phase * 2)) if moving else 0
    y = (21.5 if species == 'rabbit' else 19) + bob
    # Tail: rounded fox brush with a separate ivory tip; rabbit has a pompom.
    if species == 'fox':
        wag = math.sin(phase if moving else phase * 0.5) * (1.4 if moving else 0.7)
        polygon(d, [(12,y),(8,y-3),(4,y-4+wag),(1,y-2+wag),(2,y+2+wag),
                    (6,y+5),(10,y+4),(14,y+2)], p['out'])
        polygon(d, [(12,y),(8,y-2),(4,y-3+wag),(2,y-2+wag),(3,y+1+wag),
                    (7,y+4),(11,y+3)], p['fur'])
        line(d, [(4,y-2+wag),(7,y),(10,y+1)], p['light'])
        polygon(d, [(2,y-2+wag),(4,y-3+wag),(6,y-1),(4,y),(5,y+2),(3,y+1+wag)],p['cream'])
    else:
        ellipse(d, (5,y-1,10,y+4), p['out']); ellipse(d,(6,y-1,9,y+3),p['cream'])
        line(d, [(6,y-1),(8,y-1)],p['white'])
    # Far legs first. Walk is diagonally phased; bounding has paired hind/front legs.
    for near in [False, True]:
        if near:
            # Main silhouette, underside shade and lit dorsal fur clusters.
            ellipse(d,(8,y-5,25,y+5),p['out'])
            ellipse(d,(9,y-5,24,y+4),p['fur'])
            ellipse(d,(9,y,23,y+4),p['shade'])
            ellipse(d,(10,y-4,22,y+1),p['mid'])
            line(d,[(12,y-4),(17,y-4),(20,y-3)],p['light'])
            if species == 'rabbit':
                ellipse(d,(7,y-5,18,y+5),p['out']);ellipse(d,(8,y-5,17,y+4),p['fur'])
                ellipse(d,(9,y-4,15,y),p['mid']);line(d,[(10,y-3),(12,y-4)],p['light'])
            else:
                polygon(d,[(19,y-3),(24,y-3),(25,y+2),(22,y+4),(19,y+2),(20,y+1)],p['cream'])
            for x,dy in [(11,-1),(14,1),(17,-2),(18,2)]:
                d.point(point((x,y+dy)),fill=p['fur'])
        for front in [False, True]:
            offset = (0 if front else math.pi) if bound else ((0 if front else math.pi) + (0 if near else math.pi))
            a = phase + offset
            stride = (3.5 if bound else 2.0) if moving else 0
            hipx = 22 if front else 12
            hip = (hipx, y+2)
            toe = (hipx + math.sin(a) * stride, 28 - (max(0,math.cos(a))*2.0 if moving else 0))
            knee = (hipx + (-1 if front else 2) + math.sin(a)*stride*0.4, y+5)
            if species == 'rabbit' and not front:
                knee = (hipx+3,y+4); toe=(hipx+3+math.sin(a)*stride,27-max(0,math.cos(a))*2 if moving else 28)
            limb(d,hip,knee,toe,p,near)
            if species == 'rabbit' and not front and near:
                ellipse(d,(toe[0]-2,toe[1]-1,toe[0]+2,toe[1]),p['paw'])
                line(d,[(toe[0]-1,toe[1]-1),(toe[0]+1,toe[1]-1)],p['mid'])
    # Neck and triangular muzzle, cheek ruff, dark nose and glinting eye.
    hy = y-5 + (0.3*wave if moving else 0)
    polygon(d,[(20,hy+1),(21,hy-3),(27,hy-3),(28,hy),(31,hy+2),(30,hy+4),
               (26,hy+5),(23,hy+6),(20,hy+4)],p['out'])
    polygon(d,[(21,hy+1),(22,hy-2),(26,hy-2),(27,hy+1),(30,hy+2),(29,hy+3),
               (25,hy+4),(23,hy+5),(21,hy+3)],p['fur'])
    polygon(d,[(23,hy+2),(26,hy+1),(29,hy+2),(29,hy+3),(24,hy+4),(22,hy+3)],p['cream'])
    line(d,[(22,hy-1),(24,hy-2),(26,hy-1)],p['light'])
    # Ears flex independently; rabbit ears are long, pink-lined and not fox triangles.
    for x,lean,behind in [(22,-1,True),(26,1,False)]:
        length = 8 if species=='rabbit' else 4
        flex = (wave if behind else math.sin(phase+0.7)) * (1.3 if bound else 0.5)
        polygon(d,[(x-1,hy),(x-2+lean+flex,hy-length),(x+lean+flex,hy-length-1),(x+2,hy)],p['out'])
        polygon(d,[(x,hy-1),(x-1+lean+flex,hy-length+1),(x+lean+flex,hy-length),(x+1,hy-1)],p['fur'])
        line(d,[(x,hy-2),(x+lean+flex,hy-length+1)],p['pink'])
    eye_y=round(hy)
    blink = gait=='idle' and 9 <= round(phase / math.tau * FRAMES) <= 10
    ellipse(d,(25,eye_y-1,27,eye_y+1),p['out'])
    if not blink:
        d.point((26,eye_y-1),fill=p['white'])
    else:
        line(d,[(25,eye_y-1),(27,eye_y-1)],p['fur'])
    d.point(point((30,hy+2)),fill=p['out'])
    if species == 'rabbit':
        # Blunt, rounded rabbit cheeks: no copied pointed fox muzzle.
        d.rectangle((28,round(hy-1),31,round(hy+4)),fill=(0,0,0,0))
        ellipse(d,(21,hy-2,28,hy+5),p['out'])
        ellipse(d,(22,hy-2,28,hy+4),p['fur'])
        ellipse(d,(24,hy+1,29,hy+4),p['cream'])
        ellipse(d,(25,hy-1,27,hy+1),p['out'])
        if not blink:d.point(point((26,hy-1)),fill=p['white'])
        d.point(point((29,hy+2)),fill=p['pink'])
        line(d,[(26,hy+4),(28,hy+4)],p['shade'])
    return image


def vertical(species, gait, phase, back):
    p = FOX if species=='fox' else RABBIT
    image=Image.new('RGBA',(SIZE,SIZE));d=ImageDraw.Draw(image)
    moving=gait!='idle';bound=gait=='bound'
    bob=-max(0,math.sin(phase*2))*(1.5 if bound else 0.5) if moving else 0
    cy=20+bob
    # Paired far/near feet have independent extension and body occlusion.
    for x,a in [(11,phase),(20,phase+math.pi)]:
        step=math.sin(a)*(2.0 if bound else 1.0) if moving else 0
        ellipse(d,(x-2,cy+4+step,x+2,28+step),p['out'])
        line(d,[(x-1,27+step),(x+1,27+step)],p['paw'])
    ellipse(d,(8,cy-7,23,cy+7),p['out']);ellipse(d,(9,cy-7,22,cy+6),p['fur'])
    ellipse(d,(10,cy-6,19,cy+3),p['mid']);line(d,[(12,cy-5),(15,cy-6),(18,cy-5)],p['light'])
    ellipse(d,(10,cy+2,21,cy+5),p['shade'])
    line(d,[(21,cy),(21,cy+2)],p['dark'])
    if back:
        if species=='fox':
            wag=math.sin(phase)*2
            polygon(d,[(14,cy+1),(18,cy+1),(20+wag,cy+6),(18+wag,30),(14+wag,30),(13+wag,cy+5)],p['out'])
            polygon(d,[(15,cy+2),(17,cy+2),(19+wag,cy+6),(17+wag,29),(15+wag,29),(14+wag,cy+5)],p['fur'])
            polygon(d,[(14+wag,27),(18+wag,27),(17+wag,29),(15+wag,29)],p['cream'])
        else:
            ellipse(d,(13,cy+2,19,cy+8),p['out']);ellipse(d,(14,cy+2,18,cy+7),p['cream'])
    else:
        polygon(d,[(12,cy-4),(19,cy-4),(21,cy+1),(18,cy+5),(15,cy+6),(11,cy+1)],p['cream'])
    hy=cy-9 + (math.sin(phase+0.8)*0.65 if moving else 0)
    ellipse(d,(9,hy-3,22,hy+7),p['out']);ellipse(d,(10,hy-3,21,hy+6),p['fur'])
    line(d,[(12,hy-2),(15,hy-3),(18,hy-2)],p['light'])
    for x,sign in [(11,-1),(20,1)]:
        length=8 if species=='rabbit' else 4
        lean=math.sin(phase+sign)*(1.0 if moving else .3)
        polygon(d,[(x-2,hy),(x-2+sign+lean,hy-length),(x+sign+lean,hy-length-1),(x+2,hy)],p['out'])
        polygon(d,[(x-1,hy-1),(x-1+sign+lean,hy-length+1),(x+sign+lean,hy-length),(x+1,hy-1)],p['pink'] if not back else p['mid'])
    if not back:
        polygon(d,[(10,hy+3),(13,hy+3),(15,hy+6),(17,hy+3),(21,hy+3),(19,hy+6),(15,hy+8),(12,hy+6)],p['cream'])
        blink=gait=='idle' and 9 <= round(phase/math.tau*FRAMES) <=10
        for x in [12,19]:
            d.point((x,round(hy+1)),fill=p['out'])
            if not blink: d.point((x,round(hy)),fill=p['white'])
        line(d,[(15,hy+5),(16,hy+5)],p['out'])
    return image


def main():
    OUT.mkdir(exist_ok=True,parents=True)
    for species in ['fox','rabbit']:
        sheet=Image.new('RGBA',(SIZE*FRAMES,SIZE*12))
        for gait_index,gait in enumerate(['idle','walk','bound']):
            for direction in range(4):
                for frame in range(FRAMES):
                    phase=math.tau*frame/FRAMES
                    tile=side(species,gait,phase) if direction>=2 else vertical(species,gait,phase,direction==1)
                    if direction==2:tile=tile.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
                    sheet.alpha_composite(tile,(frame*SIZE,(gait_index*4+direction)*SIZE))
        sheet.save(OUT/f'{species}.png')
    (OUT/'wildlife.json').write_text(json.dumps({'cell_size':SIZE,'frames':FRAMES,
        'directions':['down','up','left','right'],'gaits':['idle','walk','bound'],
        'license':'CC0-1.0','author':'Lantern Valley contributors',
        'source':'tools/build_lantern_wildlife.py'},indent=2)+'\n')


if __name__=='__main__':
    main()
