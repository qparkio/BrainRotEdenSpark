"""Render base skin previews using the same palette as skin_data.das."""
import bpy
import os
import re
import sys
import math
from mathutils import Vector

project = sys.argv[sys.argv.index('--')+1]
output = os.path.join(project, 'assets', 'ui', 'renders')
os.makedirs(output, exist_ok=True)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
scene = bpy.context.scene
scene.render.engine = 'CYCLES'
scene.cycles.samples = 12
scene.cycles.use_denoising = True
scene.render.resolution_x, scene.render.resolution_y = 256, 128
scene.render.resolution_percentage = 100
scene.render.film_transparent = True
scene.render.image_settings.file_format = 'PNG'
scene.render.image_settings.color_mode = 'RGBA'
scene.view_settings.view_transform = 'Standard'
scene.world.color = (.65, .65, .65)


def aim(obj, point):
    obj.rotation_euler = (Vector(point)-obj.location).to_track_quat('-Z', 'Y').to_euler()


for location, power in [((8,-12,16),1800), ((-10,-4,10),1500), ((0,8,12),1200)]:
    light = bpy.data.lights.new('softbox', 'AREA')
    light.energy, light.size = power, 10
    obj = bpy.data.objects.new('softbox', light)
    scene.collection.objects.link(obj)
    obj.location = location
    aim(obj, (0,0,2))
camera = bpy.data.cameras.new('base_preview')
camera.type = 'ORTHO'
cam = bpy.data.objects.new('base_preview', camera)
scene.collection.objects.link(cam)
scene.camera = cam
materials = {}


def eden_surface():
    mat = bpy.data.materials.new('EdenSpark animated paint preview')
    mat.use_nodes = True
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    geometry = nodes.new('ShaderNodeNewGeometry')
    phase = nodes.new('ShaderNodeVectorMath')
    phase.operation = 'DOT_PRODUCT'
    phase.inputs[1].default_value = (.28, .12, .35)
    links.new(geometry.outputs['Position'], phase.inputs[0])
    wave = nodes.new('ShaderNodeMath')
    wave.operation = 'SINE'
    links.new(phase.outputs['Value'], wave.inputs[0])
    normal = nodes.new('ShaderNodeMath')
    normal.operation = 'MULTIPLY_ADD'
    normal.inputs[1].default_value = .5
    normal.inputs[2].default_value = .5
    links.new(wave.outputs[0], normal.inputs[0])
    palette = nodes.new('ShaderNodeValToRGB')
    palette.color_ramp.elements[0].color = (.01,.014,.02,1)
    palette.color_ramp.elements[1].color = (.07,.017,.027,1)
    palette.color_ramp.elements.new(.48).color = (.014,.05,.07,1)
    links.new(normal.outputs[0], palette.inputs[0])
    emission = nodes.new('ShaderNodeEmission')
    links.new(palette.outputs[0], emission.inputs['Color'])
    links.new(emission.outputs[0], nodes['Material Output'].inputs['Surface'])
    return mat


def eden_logo():
    mat = bpy.data.materials.new('EdenSpark official mark')
    mat.use_nodes = True
    tree = mat.node_tree
    tex = tree.nodes.new('ShaderNodeTexImage')
    tex.image = bpy.data.images.load(os.path.join(project,'assets/textures/eden_logo.png'))
    bsdf = tree.nodes['Principled BSDF']
    tree.links.new(tex.outputs['Color'], bsdf.inputs['Base Color'])
    tree.links.new(tex.outputs['Alpha'], bsdf.inputs['Alpha'])
    bpy.ops.mesh.primitive_plane_add(size=1, location=(0,4.72,2.6), rotation=(math.pi/2,0,0))
    obj = bpy.context.object
    obj.scale = (1.55,1.55,1)
    obj.data.materials.append(mat)


def box(position, size, color):
    key = tuple(color[:3]) + (color[3] if len(color) > 3 else 1,)
    if key not in materials:
        mat = bpy.data.materials.new('plastic')
        mat.use_nodes = True
        mat.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value = key
        mat.node_tree.nodes['Principled BSDF'].inputs['Alpha'].default_value = key[3]
        mat.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value = .15 if key[3] < 1 else .4
        materials[key] = mat
    bpy.ops.mesh.primitive_cube_add(size=1, location=position)
    obj = bpy.context.object
    obj.scale = size
    obj.data.materials.append(materials[key])
    return obj


lines = [line for line in open(os.path.join(project,'skin_data.das'), encoding='utf8') if line.strip().startswith('skin_of("')]
assert len(lines) == 12
for index, line in enumerate(lines):
    colors = [tuple(map(float, value.split(','))) for value in re.findall(r'float4\(([^)]+)\)', line)]
    wall, trim, floor, aisle, accent = colors
    if trim[3] == 0:
        trim = (.95,.3,.3,1)
    before = set(bpy.data.objects)
    box((0,0,-.1),(12,12,.2),(.36,.74,.28))
    box((0,0,.1),(10,10,.3),floor)
    box((0,0,.28),(2.5,10,.06),aisle)
    box((0,4.9,1.95),(10.6,.3,3.6),wall)
    for side in (-1,1):
        cursor = -5
        for y in (-2.5,.6,3.4):
            start, end = y-.9, y+.9
            box((side*5.1,(cursor+start)/2,1.95),(.3,start-cursor,3.6),wall)
            box((side*5.1,y,.8375),(.3,1.8,1.275),wall)
            box((side*5.1,y,3.1625),(.3,1.8,.875),wall)
            cursor = end
        box((side*5.1,(cursor+5)/2,1.95),(.3,5-cursor,3.6),wall)
        box((side*4.25,-4.9,1.95),(1.65,.7,3.6),wall)
        for y in (-2.5,.6,3.4):
            for direction in (-1,1):
                box((side*5.1,y+direction*.94,2.1),(.4,.08,1.41),(.98,.98,.98))
                box((side*5.1,y,2.1+direction*.665),(.4,1.8,.08),(.98,.98,.98))
            box((side*5.1,y,2.1),(.02,1.8,1.25),(.72,.92,1,.16))
            box((side*5.1,y,2.1),(.08,.06,1.25),(.98,.98,.98))
        for y in (-2.9,0,2.9):
            box((side*3.45,y,.4),(2.5,2,.35),accent)
            box((side*3.45,y,.59),(2.25,1.75,.05),(.73,.75,.8))
            box((side*2.15,y,.28),(1.4,1.7,.08),(.3,.9,.2))
    box((0,-4.9,3.48),(10.4,.7,.55),wall)
    box((0,0,3.9),(11,11,.4),wall)
    box((0,-5.58,3.87),(11.1,.15,.2),trim)
    box((0,-5.65,3.23),(5.8,.17,.65),trim)
    box((0,-5.75,3.23),(5.2,.12,.38),(.5,.32,.12))
    if index == 11:
        paint = eden_surface()
        for obj in set(bpy.data.objects)-before:
            if obj.type == 'MESH' and obj.data.materials and obj.data.materials[0] == materials[tuple(wall)]:
                obj.data.materials[0] = paint
        for side in (-1,1):
            color = (1,.3,.34,1) if side < 0 else (.42,.86,.96,1)
            box((side*4.87,0,3.25),(.06,9.4,.06),color)
        eden_logo()
    objects = list(set(bpy.data.objects)-before)
    scene.view_layers[0].update()
    points = [o.matrix_world@Vector(p) for o in objects for p in o.bound_box]
    center = Vector((0,0,1.6))
    cam.location = center+Vector((9,-17,11))
    aim(cam,center)
    inverse = cam.rotation_euler.to_matrix().transposed()
    projected = [inverse@(p-center) for p in points]
    width = max(p.x for p in projected)-min(p.x for p in projected)
    height = max(p.y for p in projected)-min(p.y for p in projected)
    camera.ortho_scale = max(width,height*2)*1.15
    scene.render.filepath = os.path.join(output,f'base_{index:02d}.png')
    bpy.ops.render.render(write_still=True)
    for obj in objects:
        bpy.data.objects.remove(obj,do_unlink=True)
    print('BASE_PREVIEW',index,flush=True)
