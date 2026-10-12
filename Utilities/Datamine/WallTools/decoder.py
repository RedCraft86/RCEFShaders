"""Extract bounded offline box payloads, retaining empirical wall candidates.

Selection uses a raw-word signature shared by five verified wall boxes.
It is empirical, not a native-authenticated collision-layer definition.
"""
import argparse
import hashlib
import json
import math
import re
import struct
import sys
from pathlib import Path


def decode(source, expected):
    """Decode the kit's inverted LZ4 format with overlapping slice copies."""
    output = bytearray()
    cursor = 0
    while cursor < len(source):
        token = source[cursor]; cursor += 1
        lit = token & 0x33; lit = (lit & 3) | (lit >> 2)
        match = (token & 0xcc) >> 2; match = (match & 3) | (match >> 2)
        if lit == 15:
            while True:
                value = source[cursor]; cursor += 1; lit += value
                if value != 255: break
        if cursor+lit > len(source) or len(output)+lit > expected: raise ValueError('literal bounds')
        output.extend(source[cursor:cursor+lit]); cursor += lit
        if cursor == len(source): break
        offset = (source[cursor]<<8) | source[cursor+1]; cursor += 2
        if not 0 < offset <= len(output): raise ValueError('match offset')
        if match == 15:
            while True:
                value = source[cursor]; cursor += 1; match += value
                if value != 255: break
        match += 4
        if len(output)+match > expected: raise ValueError('match bounds')
        while match:
            size = min(match, offset)
            start = len(output)-offset
            output.extend(output[start:start+size]); match -= size
    if cursor != len(source) or len(output) != expected: raise ValueError('size mismatch')
    return bytes(output)


def rotate(v, q):
    x,y,z,w=q
    tx=2*(y*v[2]-z*v[1]); ty=2*(z*v[0]-x*v[2]); tz=2*(x*v[1]-y*v[0])
    return (v[0]+w*tx+y*tz-z*ty,v[1]+w*ty+z*tx-x*tz,v[2]+w*tz+x*ty-y*tx)


def multiply(a,b):
    x,y,z,w=a; X,Y,Z,W=b
    return (w*X+x*W+y*Z-z*Y,w*Y-x*Z+y*W+z*X,w*Z+x*Y-y*X+z*W,w*W-x*X-y*Y-z*Z)


def _table_layout(data, table):
    if not 0<=table<=len(data)-4: raise ValueError('table bounds')
    back=struct.unpack_from('<i',data,table)[0]
    vt=table-back
    if not 0<=vt<=len(data)-4 or back==0: raise ValueError('vtable bounds')
    size,obj=struct.unpack_from('<HH',data,vt)
    if size<4 or size%2 or vt+size>len(data) or obj<4 or table+obj>len(data): raise ValueError('table size')
    fields=list(struct.unpack_from('<'+'H'*((size-4)//2),data,vt+4))
    if any(v and not 4<=v<obj for v in fields): raise ValueError('field bounds')
    return {'fields':fields}

def extract(scene, output, region, config):
    sys.path.insert(0, str(Path(config['research_kit'])))
    from scripts.game_data.streaming.framing import _table_layout
    root=output
    root.mkdir(parents=True, exist_ok=True)
    directory=scene/'Data/Streaming/PC'/region
    records={}; all_records={}; errors=[]; count=0; total_boxes=0; codec_checked=False
    for path in sorted(directory.rglob('*.bytes')):
        raw=path.read_bytes(); count+=1
        if 'ChunkInfo' in path.name: continue
        try:
            expected=struct.unpack_from('<I',raw)[0]
            if not 0<expected<config['maximum_decoded_bytes']: raise ValueError('invalid decoded size')
            data=decode(raw[4:],expected)
            if not codec_checked:
                assert data
                codec_checked=True
            pattern=b'|'.join(re.escape(struct.pack('<I',64+52*n)) for n in range(config['maximum_compound_boxes']+1))
            for match in re.finditer(pattern,data):
                prefix=match.start(); start=prefix+4; wrapper=prefix-8
                length=struct.unpack_from('<I',data,prefix)[0]
                if start+length>len(data) or wrapper<0: continue
                try: layout=_table_layout(data,wrapper)
                except ValueError: continue
                if layout['fields'] != [4] or wrapper+4+struct.unpack_from('<I',data,wrapper+4)[0] != prefix: continue
                actor=struct.unpack_from('<3f',data,start); actor_q=struct.unpack_from('<4f',data,start+12)
                kind,group,usage=struct.unpack_from('<3I',data,start+28)
                if length==64 and kind==1:
                    parts=[(actor,actor_q,struct.unpack_from('<3f',data,start+40),struct.unpack_from('<3I',data,start+52),0)]
                elif kind==5 and length==64+52*struct.unpack_from('<I',data,start+44)[0]:
                    parts=[]
                    for j in range((length-64)//52):
                        sub=start+64+52*j
                        local=struct.unpack_from('<3f',data,sub); local_q=struct.unpack_from('<4f',data,sub+12)
                        shifted=rotate(local,actor_q)
                        parts.append((tuple(actor[i]+shifted[i] for i in range(3)),multiply(actor_q,local_q),struct.unpack_from('<3f',data,sub+40),struct.unpack_from('<3I',data,sub+28),j))
                else: continue
                for center,quat,half,flags,part_index in parts:
                    if not all(math.isfinite(v) for v in (*center,*quat,*half)) or abs(sum(v*v for v in quat)-1)>.001 or not all(0<v<10000 for v in half): continue
                    total_boxes+=1
                    selected=(group==6 and usage==114 and flags[0] in (530440,595978) and flags[2]==1)
                    vertices=[]
                    for sx in (-1,1):
                        for sy in (-1,1):
                            for sz in (-1,1):
                                v=rotate((sx*half[0],sy*half[1],sz*half[2]),quat)
                                vertices.append([v[i]+center[i] for i in range(3)])
                    identity=str((data[start:start+length].hex(),part_index))
                    origin={'source':str(path.relative_to(scene)),'decodedOffset':start,'subShapeIndex':part_index,'payloadLength':length,'sourceSha256':hashlib.sha256(raw).hexdigest()}
                    if identity in all_records: all_records[identity]['origins'].append(origin); continue
                    words=[kind,group,usage,*flags]
                    row={'center':center,'quaternionXYZW':quat,'halfExtents':half,'vertices':vertices,'anonymousWords28to100':words,'selectionSignature':[group,usage,*flags],'origins':[origin]}
                    all_records[identity]=row
                    if selected: records[identity]=row
        except Exception as exc: errors.append({'source':str(path.relative_to(scene)),'error':str(exc)})
        if count%500==0: print('Scanned',count,'files;',len(records),'unique candidates',flush=True)
    report={'region':region,'selection':'empirical signature: words +28=5,+32=6,+36=114,+92=530440,+100=1','boundary':'Offline box candidates only. Signature semantics unverified; other shapes/payload sizes and dynamic barriers excluded. Not a complete invisible-wall extraction.','filesScanned':count,'boundedBoxOccurrences':total_boxes,'wallCandidateCount':len(records),'codecCheckedAgainstKit':codec_checked,'errors':errors,'boxes':list(records.values())}
    # Improve: retain excluded colliders for coverage analysis without overwriting validated output.
    report['boxes']=list(all_records.values())
    report['wallCandidateCount']=len(all_records)
    report['selection']='All bounded compact/compound box candidates, including ordinary colliders'
    (root/(region+'-all-box-candidates.json')).write_text(json.dumps(report,indent=2),encoding='utf-8')
    print({k:v for k,v in report.items() if k!='boxes'},flush=True)


    accepted=config['accepted_signatures']
    exclusions=config.get('excluded_source_suffixes',{}).get(region,[])
    kept=[]; excluded=[]
    for box in all_records.values():
        if list(box['selectionSignature']) not in accepted: continue
        origins=[o for o in box['origins'] if not any(o['source'].endswith('_'+suffix+'.bytes') for suffix in exclusions)]
        if not origins: excluded.append(box); continue
        box=dict(box); box['origins']=origins; kept.append(box)
    report['boxes']=kept
    report['wallCandidateCount']=len(kept)
    report['excludedBoxCount']=len(excluded)
    report['selection']='Configured empirical collider signatures and per-region source exclusions'
    report['configuration']=config
    root.mkdir(parents=True,exist_ok=True)
    destination=root/(region+'-walls.json')
    if destination.exists():
        import datetime, shutil
        backup=root/'backups'/datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%d-%H%M%S-%f')
        backup.mkdir(parents=True)
        shutil.copy2(destination,backup/destination.name)
    destination.write_text(json.dumps(report,indent=2),encoding='utf-8')
    (root/(region+'-excluded.json')).write_text(json.dumps({'boxes':excluded},indent=2),encoding='utf-8')
    print(region, 'published',len(kept),'excluded',len(excluded),flush=True)
    if errors: raise RuntimeError('Some files failed decoding; see errors in dataset')
