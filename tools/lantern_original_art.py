"""Redrawn original environment art; strict original footprints, no source atlas edits."""
from PIL import Image, ImageDraw
import math

WOOD=['#423d3c','#655047','#89644b','#af8459','#d8ae73','#f0ce91']


def dock():
    im=Image.new('RGBA',(32,48));d=ImageDraw.Draw(im)
    d.rectangle((0,0,31,47),fill=WOOD[0])
    for y in range(1,47,6):
        d.rectangle((2,y,29,y+4),fill=WOOD[3]);d.line((3,y,28,y),fill=WOOD[4])
        d.line((4,y+3,16,y+3),fill=WOOD[2]);d.line((20,y+2,27,y+2),fill=WOOD[2])
        for x in [4,27]:d.point((x,y+1),fill=WOOD[0]);d.point((x+1,y+2),fill=WOOD[4])
    for x in [0,29]:
        d.rectangle((x,0,x+2,47),fill=WOOD[1]);d.line((x,1,x,45),fill=WOOD[4])
    d.rectangle((0,0,31,1),fill=WOOD[4]);d.line((1,46,30,46),fill=WOOD[2])
    return im


def link():
    im=Image.new('RGBA',(8,20),WOOD[2]);d=ImageDraw.Draw(im)
    for y in range(0,20,5):
        d.rectangle((0,y,7,y+3),fill=WOOD[3]);d.line((0,y,7,y),fill=WOOD[4]);d.point((5,y+2),fill=WOOD[1])
    return im


def fence(horizontal):
    im=Image.new('RGBA',(16,16));d=ImageDraw.Draw(im)
    if horizontal:
        for y in [4,9]:
            d.rectangle((0,y,15,y+2),fill=WOOD[1]);d.line((0,y,15,y),fill=WOOD[4]);d.line((1,y+1,6,y+1),fill=WOOD[3]);d.point((12,y+1),fill=WOOD[0])
    else:
        for x in [5,10]:
            d.rectangle((x,0,x+2,15),fill=WOOD[1]);d.line((x,0,x,15),fill=WOOD[4]);d.line((x+1,2,x+1,8),fill=WOOD[3]);d.point((x+1,12),fill=WOOD[0])
    return im


def post():
    im=Image.new('RGBA',(8,20));d=ImageDraw.Draw(im)
    d.rectangle((1,3,6,19),fill=WOOD[0]);d.rectangle((2,5,5,18),fill=WOOD[2])
    d.line((2,5,2,17),fill=WOOD[4]);d.line((4,9,4,18),fill=WOOD[1])
    d.polygon([(0,2),(3,0),(6,0),(7,2),(7,4),(0,4)],fill=WOOD[1]);d.line((1,2,6,2),fill=WOOD[5])
    d.line((1,3,6,3),fill=WOOD[3]);d.point((5,15),fill=WOOD[4])
    return im


def crate():
    im=Image.new('RGBA',(16,16));d=ImageDraw.Draw(im)
    d.rectangle((1,2,14,15),fill=WOOD[0]);d.rectangle((2,3,13,14),fill=WOOD[2])
    for x in [3,7,11]:
        d.line((x,4,x,13),fill=WOOD[4]);d.line((x+2,5,x+2,13),fill=WOOD[1])
    d.polygon([(2,3),(12,3),(14,2),(4,2)],fill=WOOD[5])
    d.line((3,6,12,11),fill=WOOD[0],width=3);d.line((3,5,12,10),fill=WOOD[4],width=2)
    for y in [3,12]:
        d.rectangle((2,y,13,y+1),fill=WOOD[3]);d.line((3,y,12,y),fill=WOOD[5])
        for x in [3,12]:d.point((x,y+1),fill=WOOD[0])
    return im


def well(frame=0):
    im=Image.new('RGBA',(32,32));d=ImageDraw.Draw(im)
    # Cut-stone basin, individual masonry blocks, bevels and deep water.
    d.ellipse((1,11,30,31),fill='#374c50');d.rectangle((3,17,28,25),fill='#6d8179')
    d.ellipse((2,18,29,30),fill='#6d8179');d.arc((2,14,29,30),0,180,fill='#a5b29b',width=2)
    for x in [7,15,23]:d.line((x,23,x,28),fill='#475d5a');d.point((x+1,24),fill='#bfccb0')
    d.ellipse((1,6,30,24),fill='#415951');d.ellipse((2,6,29,22),fill='#cbd0a9')
    d.arc((2,7,29,22),0,170,fill='#8eac92',width=2);d.arc((3,6,28,21),185,325,fill='#e1ddb6')
    d.ellipse((5,9,26,19),fill='#276c83');d.ellipse((7,11,25,19),fill='#3d9caf')
    for i in range(3):
        x=8+i*5;yy=12+(i+frame)%3
        d.line((x,yy,x+3,yy),fill='#80d5ce' if i%2 else '#bae6d6')
    d.arc((6+frame%2,10,24,19),10+frame*30,120+frame*30,fill='#69c4c9')
    return im


def stall_details(im):
    d=ImageDraw.Draw(im);d.rectangle((5,34,42,45),fill=WOOD[0]);d.rectangle((6,35,41,44),fill=WOOD[2])
    for x in range(8,42,6):d.line((x,36,x,43),fill=WOOD[1]);d.point((x+1,40),fill=WOOD[3])
    d.rectangle((5,34,42,36),fill=WOOD[4]);d.line((6,34,41,34),fill=WOOD[5])
    for j,x in enumerate([10,18,26,34]):
        d.rectangle((x-1,30,x+5,34),fill=WOOD[1]);d.line((x,34,x+4,34),fill=WOOD[3])
        color='#b85e48' if j<2 else '#90a45a'
        d.ellipse((x,29,x+4,32),fill=color);d.point((x+1,29),fill='#efb16a' if j<2 else '#c5cf79')
        d.line((x+2,28,x+3,27),fill='#4c6848')
    return im


def lantern(frame=0,lit=False):
    im=Image.new('RGBA',(12,28));d=ImageDraw.Draw(im)
    d.rectangle((5,9,7,27),fill=WOOD[0]);d.line((5,12,5,26),fill=WOOD[3]);d.line((6,14,6,23),fill=WOOD[2])
    d.rectangle((2,3,10,11),fill='#303e45');d.rectangle((3,4,9,9),fill='#64746b')
    d.rectangle((4,4,8,8),fill='#d0a85f' if lit else '#889c8b')
    d.line((4,4,7,4),fill='#fff1b5' if lit else '#bdc4a0')
    d.polygon([(1,2),(5,0),(7,0),(11,2),(10,3),(2,3)],fill='#405857');d.line((3,1,8,1),fill='#98aa81')
    d.rectangle((2,10,10,11),fill='#35434a');d.line((3,10,9,10),fill='#a0a17b');d.line((6,4,6,9),fill='#515d4d')
    d.rectangle((4,25,8,27),fill='#514d43');d.point((4,25),fill=WOOD[4])
    if lit:
        x=5+(frame%2);d.line((x,8,x,6-frame%2),fill='#fff4bf');d.point((x+1,8),fill='#ed9d48')
    return im


def seedling(frame=0):
    im=Image.new('RGBA',(9,12));d=ImageDraw.Draw(im);s=[0,1,0,-1][frame]
    d.line((4,4,4,10),fill='#425744');d.line((5,5,5,9),fill='#90a952')
    d.polygon([(4,7),(1,6),(0,3+s),(3,3+s),(5,6)],fill='#3d7651')
    d.line((1,3+s,4,6),fill='#9fb963');d.point((2,4+s),fill='#c9d780')
    d.polygon([(4,6),(5,2-s),(8,1-s),(8,4-s),(6,6)],fill='#659653')
    d.line((5,5,7,2-s),fill='#c2d177');d.point((7,2-s),fill='#dfdf8c')
    d.line((3,10,6,10),fill='#86634b')
    return im


def soil(d,rect):
    x,y,xx,yy=rect
    d.rounded_rectangle(rect,radius=3,fill='#805744',outline='#b38b5a')
    d.line((x+3,y+1,xx-3,y+1),fill='#ceaa72')
    for sy in range(y+4,yy-1,4):
        d.line((x+3,sy,xx-3,sy),fill='#634b40');d.line((x+4,sy+1,xx-4,sy+1),fill='#99734d')
        for sx in range(x+7,xx-4,13):d.point((sx,sy+2),fill='#b18a60')


def animation_sheets(out):
    for name,size,count,draw in [('well-animated',(32,32),4,well),('seedling-animated',(9,12),4,seedling)]:
        sheet=Image.new('RGBA',(size[0]*count,size[1]))
        for i in range(count):sheet.alpha_composite(draw(i),(i*size[0],0))
        sheet.save(out/(name+'.png'))
    sheet=Image.new('RGBA',(48,56))
    for row in range(2):
        for i in range(4):sheet.alpha_composite(lantern(i,bool(row)),(i*12,row*28))
    sheet.save(out/'lantern-animated.png')
