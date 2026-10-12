"""Export active mesh with the original 20-byte VB and uint32 IB format."""
from pathlib import Path
import struct
import json
import bpy

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

WORKFLOW = workflow_directory()
CONFIG = json.loads((WORKFLOW/'config.json').read_text(encoding='utf-8-sig'))
DEST_DIR = Path(CONFIG['blender_export_dir'])
if not DEST_DIR.is_absolute(): DEST_DIR = WORKFLOW/DEST_DIR
NAME = globals().get('NAME', 'Zones')  # Set a unique output name per region/type.
BARY_UVS = ((0.0,0.0),(1.0,0.0),(0.0,1.0))

def export():
    obj = bpy.context.active_object
    if obj is None or obj.type != 'MESH': raise RuntimeError('Select an active zone mesh')
    if obj.mode == 'EDIT': obj.update_from_editmode()
    if not NAME or Path(NAME).name != NAME: raise ValueError('NAME must be a plain filename')
    mesh = obj.data
    mesh.calc_loop_triangles()
    count = len(mesh.loop_triangles)*3
    if not count: raise RuntimeError('The selected mesh contains no triangles')
    output = DEST_DIR/NAME
    output.mkdir(parents=True,exist_ok=True)
    vb = output/(NAME+'_VB.buf'); ib = output/(NAME+'_IB.buf')
    with vb.open('wb') as vertices, ib.open('wb') as indices:
        index = 0
        for triangle in mesh.loop_triangles:
            for loop_index, uv in zip(triangle.loops,BARY_UVS):
                point = obj.matrix_world @ mesh.vertices[mesh.loops[loop_index].vertex_index].co
                vertices.write(struct.pack('<5f',*point,*uv))
                indices.write(struct.pack('<I',index))
                index += 1
    if vb.stat().st_size != count*20 or ib.stat().st_size != count*4: raise RuntimeError('Buffer size validation failed')
    (output/(NAME+'_DrawFunc.ini')).write_text(f'drawindexed = {count}, 0, 0',encoding='utf-8')
    print(f'Exported {count//3} triangles to {output}')

export()
