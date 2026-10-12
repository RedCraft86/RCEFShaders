"""Open a mapNN-walls.json dataset and build one merged triangle mesh."""
from pathlib import Path
import json
import bpy
import bmesh
from mathutils import Vector

# Set this to any output map's dataset. No observed/unobserved split is applied.
def workflow_directory():
    """Locate config beside the parent of this saved Blender script."""
    candidates = []
    space = bpy.context.space_data
    text = getattr(space, 'text', None)
    if text is not None and text.filepath:
        candidates.append(Path(bpy.path.abspath(text.filepath)).resolve())
    if globals().get('__file__'):
        candidates.append(Path(bpy.path.abspath(__file__)).resolve())
    for candidate in candidates:
        parent = candidate.parent.parent
        if (parent / 'config.json').is_file():
            return parent
    raise FileNotFoundError('Open the saved script from WallTools/blender in the Text Editor. Its parent folder must contain config.json.')

WORKFLOW = workflow_directory()
REGION = 'map01'  # map02 for Wuling; future mapNN regions use the same importer.
CONFIG = json.loads((WORKFLOW/'config.json').read_text())
OUTPUT = Path(CONFIG['output'])
if not OUTPUT.is_absolute(): OUTPUT = WORKFLOW/OUTPUT
DATASET = OUTPUT/(REGION+'-walls.json')
MERGE_DISTANCE = 0.0001
QUADS=((0,1,3,2),(4,6,7,5),(0,4,5,1),(2,3,7,6),(0,2,6,4),(1,5,7,3))
UVS=((0.,0.),(1.,0.),(0.,1.))
data=json.loads(DATASET.read_text(encoding='utf-8-sig'))
bm=bmesh.new()
try:
    uv=bm.loops.layers.uv.new('UVMap')
    provenance=bm.faces.layers.int.new('offline_box_index')
    vertices={}
    for index,box in enumerate(data['boxes']):
        points=[Vector((x,z,y)) for x,y,z in box['vertices']]
        x,y,z=box['center']; center=Vector((x,z,y))
        for q in QUADS:
            for triangle in ((q[0],q[1],q[2]),(q[0],q[2],q[3])):
                vv=[]
                for i in triangle:
                    key=tuple(round(v/MERGE_DISTANCE) for v in points[i])
                    if key not in vertices: vertices[key]=bm.verts.new(points[i])
                    vv.append(vertices[key])
                try: face=bm.faces.new(vv)
                except ValueError: continue
                face.normal_update()
                if face.normal.dot(face.calc_center_median()-center)<0: face.normal_flip()
                face[provenance]=index
                for loop,value in zip(face.loops,UVS): loop[uv].uv=value
    bm.normal_update()
    mesh=bpy.data.meshes.new('WallMesh_'+data['region'])
    bm.to_mesh(mesh); mesh.validate(); mesh.update()
finally: bm.free()
obj=bpy.data.objects.new(mesh.name,mesh)
collection=bpy.data.collections.new('InvisibleWalls_'+data['region'])
bpy.context.scene.collection.children.link(collection)
collection.objects.link(obj)
obj['dataset']=str(DATASET); obj['selectionLimitations']=data['boundary']
for selected in bpy.context.selected_objects: selected.select_set(False)
obj.select_set(True); bpy.context.view_layer.objects.active=obj
print('Imported',len(data['boxes']),'offline walls into',obj.name)
