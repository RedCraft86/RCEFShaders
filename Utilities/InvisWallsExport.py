import bpy
import struct
import os

DEST_DIR = r"C:\Users\RedCraft86\Desktop\Exports"
NAME = "InvisibleWalls"

# Begin exporting mesh
obj = bpy.context.active_object

if obj is None:
	raise RuntimeError("No active object. Select the wall mesh first.")

if obj.type != "MESH":
	raise RuntimeError(f"Active object '{obj.name}' is not a mesh.")

mesh = obj.data
mesh.calc_loop_triangles()

vertices = []
indices = []

for tri in mesh.loop_triangles:
	for corner, loopIdx in enumerate(tri.loops):
		vertIdx = mesh.loops[loopIdx].vertex_index
		co = obj.matrix_world @ mesh.vertices[vertIdx].co

		# Per-triangle barycentric-style UVs
		if corner == 0:
			u, v = 0.0, 0.0
		elif corner == 1:
			u, v = 1.0, 0.0
		else:
			u, v = 0.0, 1.0

		vertices.append((float(co.x), float(co.y), float(co.z), float(u), float(v)))

		# Every triangle corner is exported as a unique vertex. Therefore
		# the number of indices is exactly the DrawIndexed IndexCount.
		indices.append(len(vertices) - 1)

vertexCount = len(vertices)
indexCount = len(indices)
triangleCount = indexCount // 3

if vertexCount == 0:
    raise RuntimeError("The selected mesh contains no triangles.")

if indexCount % 3 != 0:
    raise RuntimeError("Index count is not divisible by 3.")

outDir = os.path.join(DEST_DIR, NAME)
os.makedirs(outDir, exist_ok=True)

vertexBufferPath = os.path.join(outDir, NAME + "_VB.buf")
with open(vertexBufferPath, "wb") as f:
    for vertex in vertices:
        f.write(struct.pack("<5f", *vertex))

indexBufferPath = os.path.join(outDir, NAME + "_IB.buf")
with open(indexBufferPath, "wb") as f:
    for index in indices:
        f.write(struct.pack("<I", index))

drawFuncPath = os.path.join(outDir, NAME + "_DrawFunc.ini")
with open(drawFuncPath, "w", encoding="utf-8", newline="\n") as f:
    f.write(f"drawindexed = {indexCount}, 0, 0")

# Validate

expectedVBSize = vertexCount * 20
actualVBSize = os.path.getsize(vertexBufferPath)
if actualVBSize != expectedVBSize:
    raise RuntimeError("Vertex buffer size does not match the expected 20-byte vertex stride.")

expectedIBSize = indexCount * 4
actualIBSize = os.path.getsize(indexBufferPath)
if actualIBSize != expectedIBSize:
    raise RuntimeError("Index buffer size does not match the expected 4-byte index format.")