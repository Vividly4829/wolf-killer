"""Original adult grip mesh; rounded continuous skin rather than separate finger rods."""
import bpy, math
from mathutils import Vector
from pathlib import Path
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
parts=[]
def xyz(p): return Vector((p[0],-p[2],p[1]))
def ellipsoid(p,r):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=20,ring_count=12,location=xyz(p))
    obj=bpy.context.object; obj.scale=(r[0],r[2],r[1]); parts.append(obj)
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    return obj
def bone(a,b,r1,r2):
    av,bv=xyz(a),xyz(b)
    bpy.ops.mesh.primitive_cone_add(vertices=16,radius1=r1,radius2=r2,depth=(bv-av).length,location=(av+bv)*.5)
    obj=bpy.context.object; obj.rotation_mode='QUATERNION'; obj.rotation_quaternion=(bv-av).to_track_quat('Z','Y'); parts.append(obj)
    ellipsoid(a,(r1,r1,r1)); ellipsoid(b,(r2,r2,r2))
# Adult metacarpal mass and wrist, about 90 mm across the four knuckles.
ellipsoid((.037,-.043,.038),(.023,.046,.047))
ellipsoid((.034,-.070,.079),(.021,.028,.035))
ellipsoid((.032,-.082,.107),(.024,.022,.034))
tips=[]
for i,length in enumerate([.053,.060,.057,.044]):
    y=-.010-i*.021
    a=(.035,y,.012); b=(.014,y,-length*.52)
    c=(-.018,y-.002,-length*.62); d=(-.032,y-.003,-.004)
    radius=.0105-i*.0005
    for n,(p,q) in enumerate(zip([a,b,c],[b,c,d])): bone(p,q,radius-n*.001,radius-(n+1)*.001)
    tips.append(d)
# Opposing thumb: fleshy thenar pad and two tapered phalanges.
ellipsoid((.046,-.007,.047),(.020,.023,.027))
bone((.046,-.007,.047),(.042,.018,.010),.014,.011)
bone((.042,.018,.010),(.010,.014,-.023),.011,.009)
bpy.ops.object.select_all(action='DESELECT')
for obj in parts: obj.select_set(True)
bpy.context.view_layer.objects.active=parts[0]
bpy.ops.object.join(); hand=bpy.context.object; hand.name='Adult_gripping_hand'
remesh=hand.modifiers.new('Continuous skin','REMESH'); remesh.mode='VOXEL'; remesh.voxel_size=.0017
bpy.ops.object.modifier_apply(modifier=remesh.name)
smooth=hand.modifiers.new('Soft tissue','SMOOTH'); smooth.factor=.5; smooth.iterations=5
bpy.ops.object.modifier_apply(modifier=smooth.name)
decimate=hand.modifiers.new('Game topology','DECIMATE'); decimate.ratio=.30
bpy.ops.object.modifier_apply(modifier=decimate.name)
for polygon in hand.data.polygons: polygon.use_smooth=True
skin=bpy.data.materials.new('Weathered adult skin'); skin.diffuse_color=(.43,.265,.18,1); skin.use_nodes=True
shader=skin.node_tree.nodes.get('Principled BSDF'); shader.inputs['Base Color'].default_value=skin.diffuse_color; shader.inputs['Roughness'].default_value=.82
hand.data.materials.append(skin)
# Keep the asset origin at the grip reference, regardless of the joined primitive origin.
bpy.context.scene.cursor.location=(0,0,0); bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
out=Path(__file__).resolve().parents[1]/'assets'/'adult_hand.glb'
bpy.ops.export_scene.gltf(filepath=str(out),export_format='GLB',use_selection=True,export_animations=False)
print('ADULT_HAND',out,'faces',len(hand.data.polygons))
