import bpy
import bmesh
import json
import glob
import os
import mathutils

SOURCE_DIR = r"C:\Users\RedCraft86\Desktop\Exports"
FILE_PATTERN = "air-wall-export*.json"

# Basic object properties
OBJECT_NAME = "WallMesh"
COLLECTION_NAME = "InvisibleWalls"

# For overlapping walls, vertices within this tolerance will be merged
MERGE_DISTANCE = 0.0001

# Barycentric corner values, one per loop of a triangle
BARY_UVS = ((0.0, 0.0), (1.0, 0.0), (0.0, 1.0))

def convertPoint(p):
	x, y, z = p
	return mathutils.Vector((x, z, y))

def convertNormal(n):
	x, y, z = n
	return mathutils.Vector((x, z, y)).normalized()

def getOrAddCollection(name):
	if name in bpy.data.collections:
		return bpy.data.collections[name]
	else:
		coll = bpy.data.collections.new(name)
		bpy.context.scene.collection.children.link(coll)
		return coll

# Begin processing files
pattern = os.path.join(SOURCE_DIR, FILE_PATTERN)
files = sorted(glob.glob(pattern))
if files:
	bm = bmesh.new()
	uvLayer = bm.loops.layers.uv.new("UVMap")

	vertLookup = {}
	def getVert(pos):
		key = tuple(round(c / MERGE_DISTANCE) for c in pos)
		v = vertLookup.get(key)
		if v is None:
			v = bm.verts.new(pos)
			vertLookup[key] = v
		return v

	built = 0
	totalTris = 0
	dupeOrDegenTris = 0

	for filePath in files:
		with open(filePath, "r") as f:
			data = json.load(f)

		triangles = data.get("triangles", [])
		totalTris += len(triangles)

		for tri in triangles:
			pts = [convertPoint(p) for p in tri["points"]]
			verts = [getVert(p) for p in pts]

			try:
				face = bm.faces.new(verts)
			except ValueError:
				# Degenerate triangle, or an identical face already built
				# (i.e. a duplicate wall from a different file)
				dupeOrDegenTris += 1
				continue

			face.normal_update()
			if face.normal.dot(convertNormal(tri["normal"])) < 0:
				face.normal_flip()

			for loop, uv in zip(face.loops, BARY_UVS):
				loop[uvLayer].uv = uv

			built += 1

	bm.normal_update()

	mesh = bpy.data.meshes.new(OBJECT_NAME)
	bm.to_mesh(mesh)
	bm.free()
	mesh.validate()

	obj = bpy.data.objects.new(OBJECT_NAME, mesh)
	collection = getOrAddCollection(COLLECTION_NAME)
	collection.objects.link(obj)