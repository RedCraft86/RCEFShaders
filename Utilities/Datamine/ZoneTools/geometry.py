"""Reconstruct authored box/polygon function-area volumes in Unity-world coordinates."""
import math

def multiply(a,b):
 x,y,z,w=a; X,Y,Z,W=b
 return (w*X+x*W+y*Z-z*Y,w*Y-x*Z+y*W+z*X,w*Z+x*Y-y*X+z*W,w*W-x*X-y*Y-z*Z)
def rotate(v,q):
 x,y,z,w=q; tx=2*(y*v[2]-z*v[1]); ty=2*(z*v[0]-x*v[2]); tz=2*(x*v[1]-y*v[0])
 return (v[0]+w*tx+y*tz-z*ty,v[1]+w*ty+z*tx-x*tz,v[2]+w*tz+x*ty-y*tx)
def euler_quaternion(euler):
 x,y,z=[math.radians(v)/2 for v in euler]
 # Unity Quaternion.Euler applies Z, then X, then Y.
 return multiply(multiply((0,math.sin(y),0,math.cos(y)),(math.sin(x),0,0,math.cos(x))),(0,0,math.sin(z),math.cos(z)))
def cross(a,b): return (a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0])
def subtract(a,b): return tuple(x-y for x,y in zip(a,b))
def bounds(points): return [[min(p[i] for p in points) for i in range(3)],[max(p[i] for p in points) for i in range(3)]]
def area_volume(vertices,triangles):
 area=volume=0.; origin=vertices[0]
 for a,b,c in triangles:
  p,q,r=[vertices[i] for i in (a,b,c)]; normal=cross(subtract(q,p),subtract(r,p))
  area+=math.sqrt(sum(x*x for x in normal))/2
  volume+=sum(x*y for x,y in zip(subtract(p,origin),cross(subtract(q,origin),subtract(r,origin))))/6
 return area,abs(volume)
def triangulate(points):
 # Ear clipping preserves concave outlines; a fan would fill outside the volume.
 def turn(a,b,c): return (b[0]-a[0])*(c[1]-a[1])-(b[1]-a[1])*(c[0]-a[0])
 signed=sum(a[0]*b[1]-b[0]*a[1] for a,b in zip(points,points[1:]+points[:1]))
 if abs(signed)<1e-8: raise ValueError('Degenerate polygon')
 order=list(range(len(points)))
 if signed<0: order.reverse()
 result=[]
 while len(order)>3:
  found=False
  for i,b in enumerate(order):
   a=order[i-1]; c=order[(i+1)%len(order)]
   if turn(points[a],points[b],points[c])<=1e-8: continue
   if any(all(turn(points[u],points[v],points[j])>=-1e-8 for u,v in ((a,b),(b,c),(c,a))) for j in order if j not in (a,b,c)): continue
   result.append((a,b,c)); order.pop(i); found=True; break
  if not found: raise ValueError('Non-simple polygon or unsupported degeneracy')
 result.append(tuple(order)); return result,signed

def reconstruct(base,range_row):
 shape=base['shapeType']; position=base['postion']; offset=base['offset']; q=euler_quaternion(base['euler'])
 if shape==1:
  size=base['size']
  if not all(v>0 for v in size): raise ValueError('Nonpositive box dimensions')
  local=[tuple(offset[i]+s[i]*size[i]/2 for i in range(3)) for s in [(x,y,z) for x in (-1,1) for y in (-1,1) for z in (-1,1)]]
  vertices=[tuple(position[i]+rotate(p,q)[i] for i in range(3)) for p in local]
  center=tuple(sum(p[i] for p in vertices)/8 for i in range(3)); triangles=[]
  for a,b,c,d in ((0,1,3,2),(4,6,7,5),(0,4,5,1),(2,3,7,6),(0,2,6,4),(1,5,7,3)):
   for tri in ((a,b,c),(a,c,d)):
    p,r,s=[vertices[j] for j in tri]; normal=cross(subtract(r,p),subtract(s,p))
    if sum(normal[i]*(sum(vertices[j][i] for j in tri)/3-center[i]) for i in range(3))<0: tri=tuple(reversed(tri))
    triangles.append(tri)
 elif shape==3:
  points=[tuple(p) for p in base['posList'] or []]
  if len(points)>1 and points[0]==points[-1]: points.pop()
  if len(points)<3 or len(set(points))!=len(points): raise ValueError('Invalid polygon points')
  # Improve: BeyondPolyLineShape stores one yaw angle; pitch/roll do not tilt its vertical extrusion.
  q=euler_quaternion((0,base['euler'][1],0))
  if range_row is None: raise ValueError('Polygon needs authored vertical range')
  low=range_row['center'][1]-range_row['size'][1]/2; high=range_row['center'][1]+range_row['size'][1]/2
  if high<=low: raise ValueError('Nonpositive polygon height')
  ring=[]
  for x,z in points:
   v=rotate((x+offset[0],0,z+offset[2]),q); ring.append((position[0]+v[0],position[2]+v[2]))
  caps,signed=triangulate(ring); n=len(ring)
  vertices=[(x,y,z) for y in (low,high) for x,z in ring]; triangles=[]
  for a,b,c in caps: triangles.extend(((a,b,c),(c+n,b+n,a+n)))
  for i in range(n):
   j=(i+1)%n; pair=((i,i+n,j+n),(i,j+n,j))
   triangles.extend(pair if signed>0 else tuple(tuple(reversed(t)) for t in pair))
 else: raise ValueError(f'Unsupported authored shape {shape}; no box approximation')
 if range_row:
  expected=[[range_row['center'][i]+s*range_row['size'][i]/2 for i in range(3)] for s in (-1,1)]
  actual=bounds(vertices)
  if max(abs(a-b) for p,r in zip(actual,expected) for a,b in zip(p,r))>.02: raise ValueError('Geometry disagrees with authored range')
 edges={}
 for triangle in triangles:
  for a,b in zip(triangle,triangle[1:]+triangle[:1]):
   key=tuple(sorted((a,b))); edges.setdefault(key,[]).append((a,b))
 if any(len(e)!=2 or e[0]!=tuple(reversed(e[1])) for e in edges.values()): raise ValueError('Volume is not a closed consistently wound mesh')
 area,volume=area_volume(vertices,triangles)
 if volume<=0: raise ValueError('Zero enclosed volume')
 return {'vertices':vertices,'triangles':triangles,'bounds':bounds(vertices),'surfaceArea':area,'enclosedVolume':volume}

