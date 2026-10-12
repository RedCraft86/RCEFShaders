"""Import one merged triangle mesh per configured nonempty region/zone type."""
import json
from pathlib import Path
import bpy

REGIONS = globals().get('REGIONS')  # None uses config.json; set a tuple to select regions.
KINDS = globals().get('KINDS')      # None uses config.json; set a tuple to select types.
ALLOW_PARTIAL = False
UVS = ((0.0,0.0),(1.0,0.0),(0.0,1.0))

def workflow_directory():
    """Locate shared configuration from this saved Blender script."""
    candidates=[]
    text=getattr(bpy.context.space_data,'text',None)
    if text is not None and text.filepath:
        candidates.append(Path(bpy.path.abspath(text.filepath)).resolve())
    if globals().get('__file__'):
        candidates.append(Path(bpy.path.abspath(__file__)).resolve())
    for candidate in candidates:
        root=candidate.parent.parent
        if (root/'config.json').is_file() and (root/'zones.py').is_file():
            return root
    raise FileNotFoundError('Open the saved script from ZoneTools/blender; reopen it after moving or editing it.')

ROOT=workflow_directory()
CONFIG=json.loads((ROOT/'config.json').read_text(encoding='utf-8-sig'))
REGIONS=CONFIG['regions'] if REGIONS is None else REGIONS
KINDS=CONFIG['kinds'] if KINDS is None else KINDS
DATA_DIR=Path(CONFIG['output'])
if not DATA_DIR.is_absolute(): DATA_DIR=ROOT/DATA_DIR
if not REGIONS:
    REGIONS=sorted({p.name.split('-',1)[0] for p in DATA_DIR.glob('map*-*-zones.json')})

def import_dataset(region,kind):
    path=DATA_DIR/(region+'-'+kind+'-zones.json')
    data=json.loads(path.read_text(encoding='utf-8-sig'))
    if data.get('format')!='endfield-offline-zone-meshes' or data.get('version')!=1 or data.get('coordinateSpace')!='unity-world': raise ValueError('Unsupported zone dataset: '+str(path))
    if data['region']!=region or data['kind']!=kind: raise ValueError('Dataset identity disagrees with filename')
    if data['status']=='unresolved':
        print('Skipped unresolved',region,kind,':',data['boundary']); return None
    if data['status']!='decoded' and not ALLOW_PARTIAL: raise ValueError('Partial dataset requires review: '+str(path))
    if not data['zones']:
        print('No authored',kind,'zones in',region); return None
    vertices=[]; triangles=[]; provenance=[]
    for index,zone in enumerate(data['zones']):
        start=len(vertices)
        vertices.extend((x,z,y) for x,y,z in zone['vertices'])
        # Improve: the X/Z/Y swap reverses handedness; reverse winding to retain outward normals.
        triangles.extend(tuple(start+i for i in reversed(triangle)) for triangle in zone['triangles'])
        provenance.extend([index]*len(zone['triangles']))
    mesh=bpy.data.meshes.new('OfflineZones_'+region+'_'+kind)
    mesh.from_pydata(vertices,[],triangles)
    if mesh.validate():
        bpy.data.meshes.remove(mesh); raise ValueError('Blender repaired invalid zone geometry; import refused')
    uv=mesh.uv_layers.new(name='UVMap')
    for polygon in mesh.polygons:
        for loop,value in zip(polygon.loop_indices,UVS): uv.data[loop].uv=value
    attribute=mesh.attributes.new(name='offline_zone_index',type='INT',domain='FACE')
    attribute.data.foreach_set('value',provenance)
    mesh.update()
    collection=bpy.data.collections.get('OfflineZones_'+region)
    if collection is None:
        collection=bpy.data.collections.new('OfflineZones_'+region); bpy.context.scene.collection.children.link(collection)
    obj=bpy.data.objects.new(mesh.name,mesh); collection.objects.link(obj)
    obj['dataset']=str(path.resolve()); obj['region']=region; obj['kind']=kind; obj['zone_count']=len(data['zones']); obj['boundary']=data['boundary']
    print('Imported',region,kind,len(data['zones']),'zones',len(triangles),'triangles')
    return obj

def main():
    created=[]
    for region in REGIONS:
        for kind in KINDS:
            obj=import_dataset(region,kind)
            if obj is not None: created.append(obj)
    if created:
        for obj in bpy.context.selected_objects: obj.select_set(False)
        for obj in created: obj.select_set(True)
        bpy.context.view_layer.objects.active=created[-1]
    return created

CREATED_OBJECTS=main()
