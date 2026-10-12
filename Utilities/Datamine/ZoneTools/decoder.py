"""Strict ZoneTools MemoryPack decoding with current copied-build evidence."""
import math
import struct
import types
from workflow import configure_research_kit
from native import load_evidence

class ZoneCodec:
    def __init__(self, config, evidence=None):
        configure_research_kit(config)
        from scripts.game_data import leveldata_binary
        from scripts.game_data.codecs.leveldata import memorypack
        self.leveldata = leveldata_binary
        self.memorypack = memorypack
        evidence = load_evidence(config) if evidence is None else evidence
        self.schemas = evidence['wrappers']
        self.hashes = evidence['nativeInputs']
        self.unions = {}
        by_name = {s['wrapperName']: s for s in self.schemas.values()}
        for family, base in [('ConditionRuntimeBase', 'Beyond.Gameplay.ConditionRuntimeBase'), ('FunctionAreaSpecificData', 'Beyond.Gameplay.LevelFunctionAreaData+FunctionAreaSpecificData')]:
            self.unions[base] = {entry['tag']: by_name[entry['wrapperName']]['wrappedType'] for entry in evidence['families'][family]}

    def read(self,data,offset,type_name,member=None,depth=0):
        if depth>32: raise ValueError('Nested zone data exceeds depth limit')
        def checked(value):
            if value is None: raise ValueError(f'Truncated/invalid {type_name} at {offset}')
            return value
        primitive={'bool':self.memorypack.read_bool,'int':self.memorypack.read_i32,'uint':self.memorypack.read_u32,'ulong':self.memorypack.read_u64,'long':self.memorypack.read_i64,'float':self.memorypack.read_f32,'double':self.memorypack.read_f64,'string':lambda b,o:self.memorypack.read_string(b,o,max_length=65536)}
        if type_name in primitive: return checked(primitive[type_name](data,offset))
        if member and member.get('kind')=='enum':
            width=member.get('width')
            if width not in (1,2,4,8) or offset+width>len(data): raise ValueError('Enum bounds/width')
            return int.from_bytes(data[offset:offset+width],'little',signed=False),offset+width
        # Improve: typed integer grid coordinates close dynamic-occlusion prefixes.
        if type_name in ('UnityEngine.Vector2Int','UnityEngine.Vector3Int'):
            n=2 if type_name.endswith('Vector2Int') else 3
            if offset+4*n>len(data): raise ValueError('Integer vector bounds')
            return list(struct.unpack_from('<'+'i'*n,data,offset)),offset+4*n
        if type_name in ('UnityEngine.Vector2','UnityEngine.Vector3','UnityEngine.Vector4','UnityEngine.Quaternion'):
            n={'UnityEngine.Vector2':2,'UnityEngine.Vector3':3}.get(type_name,4)
            if offset+4*n>len(data): raise ValueError('Vector bounds')
            values=struct.unpack_from('<'+'f'*n,data,offset)
            if not all(math.isfinite(v) for v in values): raise ValueError('Nonfinite vector')
            return list(values),offset+4*n
        if type_name.startswith('System.Collections.Generic.List`1<') or type_name.endswith('[]'):
            child=type_name.split('<',1)[1][:-1] if '<' in type_name else type_name[:-2]
            count,cursor=checked(self.memorypack.read_count(data,offset,max_count=100000))
            if count==-1: return None,cursor
            rows=[]
            for _ in range(count):
                value,cursor=self.read(data,cursor,child,depth=depth+1); rows.append(value)
            return rows,cursor
        if offset>=len(data): raise ValueError('Truncated object')
        # Fix: raw unmanaged structs have no null marker, even when their first byte is 0xff.
        if data[offset]==255 and not self.schemas.get(type_name,{}).get('framesAsRawStruct',False): return None,offset+1
        if type_name in self.unions:
            tag=data[offset]; concrete=self.unions[type_name].get(tag)
            if concrete is None: raise ValueError(f'Unsupported union {type_name} tag {tag} at {offset}')
            row,end=self.read(data,offset+1,concrete,depth=depth+1)
            if row is None: raise ValueError('Null union body')
            row['unionTag']=tag
            return row,end
        schema=self.schemas.get(type_name)
        if schema is None: raise ValueError(f'Unsupported nested type {type_name} at {offset}')
        cursor=offset
        if not schema['framesAsRawStruct']:
            if data[cursor]!=schema['serializedMemberCount']: raise ValueError(f'Changed member count for {type_name} at {cursor}')
            cursor+=1
        row={'storedType':type_name,'startOffset':offset}
        for field in schema['members']:
            row[field['name']],cursor=self.read(data,cursor,field['declaredType'],field,depth+1)
        row['endOffset']=cursor
        return row,cursor

    def collection(self,data,offset,item_type):
        rows,end=self.read(data,offset,'System.Collections.Generic.List`1<'+item_type+'>')
        return {'startOffset':offset,'endOffset':end,'count':-1 if rows is None else len(rows),'rows':rows or []}

    def frame(self,data):
        def conditions(b,o):
            try: return self.collection(b,o,'Beyond.Gameplay.LevelFunctionAreaData+ConditionData')
            except ValueError as exc: raise self.leveldata.LevelFunctionAreaCodecError(str(exc)) from exc
        def specifics(b,o):
            try: return self.collection(b,o,'Beyond.Gameplay.LevelFunctionAreaData+FunctionAreaSpecificData')
            except ValueError as exc: raise self.leveldata.LevelFunctionAreaCodecError(str(exc)) from exc
        def condition(b,o,field,**kwargs):
            try: return self.read(b,o,'Beyond.Gameplay.ConditionRuntimeBase')
            except ValueError as exc: raise self.leveldata.LevelFunctionAreaCodecError(str(exc)) from exc
        # Improve: bind structural framing to independently derived current-build codecs.
        # No ResearchKit module or existing contract gate is modified.
        scope=dict(self.leveldata.frame_leveldata_named_prefix.__globals__)
        # Improve: close current dynamic-occlusion rows before the function-area field.
        def dynamic(b,o):
            try: return self.collection(b,o,'Beyond.Gameplay.LevelDynamicOccludeAreaData')
            except ValueError: return None
        scope.update(decode_function_area_condition_list=conditions,decode_function_area_specific_data_list=specifics,decode_condition_runtime=condition,decode_dynamic_occlude_area_list=dynamic)
        reader=types.FunctionType(self.leveldata.frame_leveldata_named_prefix.__code__,scope)
        return reader(data)

