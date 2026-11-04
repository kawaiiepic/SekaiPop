"""Build the original SKP-01 mesh. No DCC tool or runtime generation needed.
Coordinates match the 1100 x 670 interactive face, +Y up, +Z toward camera.
"""
from pathlib import Path
import math

folder = Path(__file__).resolve().parent
vertices = []
faces = []

def prism(name, polygon, back, front, material):
    offset = len(vertices)
    count = len(polygon)
    vertices.extend((x-550, 335-y, z) for z in [back, front] for x,y in polygon)
    # Pixel-to-world Y inversion is accounted for when writing the face winding.
    faces.append((name, material, [offset+i+1 for i in reversed(range(count))]))
    faces.append((name, material, [offset+count+i+1 for i in range(count)]))
    for i in range(count):
        j=(i+1)%count
        faces.append((name, material, [offset+i+1,offset+j+1,offset+count+j+1,offset+count+i+1]))

def box(name,x,y,w,h,back,front,material,cut=0):
    if cut:
        points=[(x+cut,y),(x+w-cut,y),(x+w,y+cut),(x+w,y+h-cut),(x+w-cut,y+h),(x+cut,y+h),(x,y+h-cut),(x,y+cut)]
    else: points=[(x,y),(x+w,y),(x+w,y+h),(x,y+h)]
    prism(name,points,back,front,material)

# Rear shell, a chamfered metal cap, layered rim, recessed screen bed.
box('rear_shell',-8,-8,1116,686,-62,-10,'shell',24)
box('front_chassis',0,0,1100,670,-12,2,'metal',20)
box('keyboard_well',24,495,1052,160,2,6,'rubber',8)
box('display_bed',25,42,1050,433,2,13,'rubber',9)
# Raised rails frame the actual display rather than painting a false border.
for name,x,y,w,h in [('top',24,40,1052,9),('bottom',24,467,1052,9),('left',24,49,9,418),('right',1067,49,9,418)]:
    box('screen_rail_'+name,x,y,w,h,3,23,'rim',2)
for row,length in enumerate([11,10,8]):
    for column in range(length):
        box(f'key_{row}_{column}',32+75*column,544+35*row,70,30,6,18,'keycap',3)
for row in range(4):
    box(f'action_key_{row}',922,501+40*row,143,33,6,18,'keycap',4)
box('search_recess',32,501,858,32,3,12,'rubber',4)
# Real vent slats on each edge; ports on the right wall.
for side in [4,1086]:
    for row in range(8):box(f'vent_{side}_{row}',side,158+18*row,10,8,2,5,'rubber',2)
for row in range(2):box(f'port_{row}',1096,374+58*row,10,38,-34,-14,'rubber',3)
# Screws with geometric inset slots; two low-key emissive status indicators.
for x,y in [(13,13),(1075,13),(13,645),(1075,645)]:
    points=[(x+6+6*math.cos(i*math.tau/16),y+6+6*math.sin(i*math.tau/16)) for i in range(16)]
    prism('screw',points,3,9,'steel')
    box('screw_slot',x+2,y+5,8,2,9,9.3,'rubber')
box('pink_led',9,414,5,8,3,6,'pink',2)
box('blue_led',1086,414,5,8,3,6,'blue',2)

lines=['# SKP-01 original cyberdeck mesh; rebuild with build-model.py','mtllib cyberdeck.mtl']
lines += [f'v {x:g} {y:g} {z:g}' for x,y,z in vertices]
last=None
for name,mat,indices in faces:
    if (name,mat)!=last:lines += ['o '+name,'usemtl '+mat,'s off'];last=(name,mat)
    lines.append('f '+' '.join(map(str,reversed(indices))))
folder.joinpath('cyberdeck.obj').write_text('\n'.join(lines)+'\n')
materials={
'shell':('.055 .065 .085',.1),'metal':('.13 .15 .19',.25),
'rubber':('.015 .02 .03',0),'rim':('.24 .28 .35',.35),
'keycap':('.075 .085 .11',.1),'steel':('.32 .36 .43',.6),
'pink':('.6 .25 .43',.2),'blue':('.27 .45 .65',.2)}
mtl=[]
for name,(rgb,spec) in materials.items():
    mtl += ['newmtl '+name,'Kd '+rgb,f'Ks {spec} {spec} {spec}','Ns 40','illum 2']
    if name in ['pink','blue']:mtl += ['Ke '+rgb]
folder.joinpath('cyberdeck.mtl').write_text('\n'.join(mtl)+'\n')
print(f'{len(vertices)} vertices; {len(faces)} polygon faces')
