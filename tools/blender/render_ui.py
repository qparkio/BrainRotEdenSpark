"""Render the actual shipped models, plus blocky gear, to transparent UI thumbnails.
blender -b --factory-startup -P tools/blender/render_ui.py -- PROJECT
The atlas order is the same as brainrot_files.das and gear_data.das.
"""
import bpy
import math
import os
import re
import sys
from mathutils import Vector

PROJECT = sys.argv[sys.argv.index('--') + 1]
OUT = os.path.join(PROJECT, 'assets', 'ui', 'renders')
os.makedirs(OUT, exist_ok=True)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
scene = bpy.context.scene
scene.render.engine = 'CYCLES'
scene.cycles.samples = 12
scene.cycles.use_denoising = True
scene.render.resolution_x = scene.render.resolution_y = 256
scene.render.resolution_percentage = 100
scene.render.film_transparent = True
scene.render.image_settings.file_format = 'PNG'
scene.render.image_settings.color_mode = 'RGBA'
scene.world.color = (0.65, 0.65, 0.65)
scene.view_settings.view_transform = 'Standard'

def aim(obj, target):
    obj.rotation_euler = (Vector(target) - obj.location).to_track_quat('-Z', 'Y').to_euler()

def light(pos, energy, size):
    data = bpy.data.lights.new('softbox', 'AREA')
    data.energy, data.shape, data.size = energy, 'DISK', size
    ob = bpy.data.objects.new('softbox', data)
    scene.collection.objects.link(ob)
    ob.location = pos
    aim(ob, (0, 0, 3))
    return ob

light((5, -8, 12), 1700, 8)
light((-7, -3, 7), 1100, 7)
light((0, 6, 10), 1400, 6)
cam_data = bpy.data.cameras.new('thumbnail_camera')
cam = bpy.data.objects.new('thumbnail_camera', cam_data)
scene.collection.objects.link(cam)
scene.camera = cam
cam_data.type = 'ORTHO'

def render(objects, filename):
    scene.view_layers[0].update()
    points = [o.matrix_world @ Vector(p) for o in objects if o.type == 'MESH' for p in o.bound_box]
    lo = Vector(tuple(min(p[i] for p in points) for i in range(3)))
    hi = Vector(tuple(max(p[i] for p in points) for i in range(3)))
    center = (lo + hi) * .5
    cam.location = center + Vector((8, -18, 8))
    aim(cam, center)
    # Fit using projected corners, including long wings and weapons.
    inv = cam.rotation_euler.to_matrix().transposed()
    projected = [inv @ (p - center) for p in points]
    width = max(p.x for p in projected) - min(p.x for p in projected)
    height = max(p.y for p in projected) - min(p.y for p in projected)
    cam_data.ortho_scale = max(width, height) * 1.18
    scene.render.filepath = os.path.join(OUT, filename)
    bpy.ops.render.render(write_still=True)
    for obj in objects:
        if obj.name in bpy.data.objects:
            bpy.data.objects.remove(obj, do_unlink=True)

roster = re.findall(r'"([a-z0-9_]+)"', open(os.path.join(PROJECT, 'brainrot_files.das'), encoding='utf8').read())
for i, slug in enumerate(roster):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=os.path.join(PROJECT, 'assets', 'brainrots', slug + '.glb'))
    objs = list(set(bpy.data.objects) - before)
    render(objs, 'brainrot_%02d.png' % i)
    print('UI_RENDER brainrot', i, slug, flush=True)

def material(color):
    mat = bpy.data.materials.new('plastic')
    mat.diffuse_color = (*color, 1)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get('Principled BSDF')
    bsdf.inputs['Base Color'].default_value = (*color, 1)
    bsdf.inputs['Roughness'].default_value = .35
    return mat

def box(loc, size, color):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    obj = bpy.context.object
    obj.scale = size
    obj.data.materials.append(material(color))
    bevel = obj.modifiers.new('small soft edges', 'BEVEL')
    bevel.width, bevel.segments = .05, 2
    return obj

def coil(color):
    pts = [(1.15 * math.cos(t), 1.15 * math.sin(t), .2 + t * .16) for t in [i * math.pi / 12 for i in range(121)]]
    curve = bpy.data.curves.new('spring', 'CURVE')
    curve.dimensions, curve.bevel_depth, curve.bevel_resolution = '3D', .15, 3
    spline = curve.splines.new('POLY')
    spline.points.add(len(pts) - 1)
    for p, xyz in zip(spline.points, pts):
        p.co = (*xyz, 1)
    obj = bpy.data.objects.new('coil', curve)
    scene.collection.objects.link(obj)
    curve.materials.append(material(color))
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.convert(target='MESH')
    obj.select_set(False)
    box((0, 0, 2.65), (2.5, .35, .35), (.12, .12, .15))

colors = [(1,.45,.25),(.2,.5,1),(.55,.55,.6),(.75,.8,.88),(.3,1,.4),(1,.85,.2),(1,.8,.1),(.7,.2,1),(.3,.8,1),(.35,.3,.55),(1,.25,.7)]
for i in range(11):
    before = set(bpy.data.objects)
    col = colors[i]
    if i in (1,4,7):
        coil(col)
    elif i in (0,3,6):
        box((0,0,1.15), (.5,.45,2.3), (.35,.2,.12))
        box((0,0,3.25), (1.1,.7,2.0), col)
    elif i == 2:
        box((0,0,.2), (3,2.6,.3), col)
        for x in (-1,1):
            for y in (-.8,0,.8):
                obj = box((x,y,.8), (.25,.25,1.2), (.8,.83,.86))
                obj.rotation_euler.y = x * -.45
    elif i == 9:
        box((0,0,1.6), (2.8,.4,3.2), col)
        box((0,0,3.3), (1.6,.6,.4), (.7,.65,.9))
    elif i == 10:
        box((0,0,1.5), (2.1,2.1,2.1), col)
        for x in (-.7,0,.7):
            box((x,-1.06,1.5), (.28,.1,1.7), (1,.85,.35))
        box((0,0,2.75), (.4,.4,.5), (.15,.15,.2))
    else:
        box((0,0,1.2), (.6,.8,2.4), (.17,.17,.2))
        box((0,-.25,2.5), (1.2,2.6,.8), col)
        box((0,-1.65,2.5), (.8,.3,.5), (.13,.13,.17))
    render(list(set(bpy.data.objects) - before), 'gear_%02d.png' % i)
    print('UI_RENDER gear', i, flush=True)

