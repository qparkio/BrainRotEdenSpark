"""Tiny voxel sculpting DSL + Blender exporter.

Shapes are described in continuous units (feet at y=0, the creature faces +z, +x is its left in
EdenSpark's left-handed space) and rasterised at `vs` units per voxel. The result is exported as a GLB
with one palette texture, so every voxel face samples a single texel (nearest filtering = crisp colors).
"""
import math
import os

import bpy


def shade(c, k):
    return (min(1.0, c[0] * k), min(1.0, c[1] * k), min(1.0, c[2] * k))


class Vox:
    def __init__(self, vs=0.2):
        self.vs = vs
        self.cells = {}  # (i, j, k) -> palette index
        self.palette = []

    def col(self, rgb):
        rgb = (round(rgb[0], 3), round(rgb[1], 3), round(rgb[2], 3))
        if rgb not in self.palette:
            self.palette.append(rgb)
        return self.palette.index(rgb)

    def _rng(self, lo, hi):
        vs = self.vs
        return range(int(math.floor(lo / vs + 0.5)), int(math.floor(hi / vs + 0.5)))

    def box(self, cx, cy, cz, sx, sy, sz, color):
        c = self.col(color)
        for i in self._rng(cx - sx / 2, cx + sx / 2):
            for j in self._rng(cy - sy / 2, cy + sy / 2):
                for k in self._rng(cz - sz / 2, cz + sz / 2):
                    self.cells[(i, j, k)] = c

    def ball(self, cx, cy, cz, sx, sy, sz, color):
        """Ellipsoid with the given full extents."""
        c = self.col(color)
        rx, ry, rz = max(sx / 2, 1e-4), max(sy / 2, 1e-4), max(sz / 2, 1e-4)
        vs = self.vs
        for i in self._rng(cx - rx, cx + rx):
            for j in self._rng(cy - ry, cy + ry):
                for k in self._rng(cz - rz, cz + rz):
                    x, y, z = (i + 0.5) * vs, (j + 0.5) * vs, (k + 0.5) * vs
                    if ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 + ((z - cz) / rz) ** 2 <= 1.0:
                        self.cells[(i, j, k)] = c

    def erase_ball(self, cx, cy, cz, sx, sy, sz):
        rx, ry, rz = sx / 2, sy / 2, sz / 2
        vs = self.vs
        for i in self._rng(cx - rx, cx + rx):
            for j in self._rng(cy - ry, cy + ry):
                for k in self._rng(cz - rz, cz + rz):
                    x, y, z = (i + 0.5) * vs, (j + 0.5) * vs, (k + 0.5) * vs
                    if ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 + ((z - cz) / rz) ** 2 <= 1.0:
                        self.cells.pop((i, j, k), None)

    def eyes(self, y, z, spread, size, white=(1, 1, 1), pupil=(0.05, 0.05, 0.07)):
        for sx in (-1, 1):
            self.ball(sx * spread, y, z, size, size, size * 0.5, white)
            self.ball(sx * spread, y, z + size * 0.22, size * 0.5, size * 0.5, size * 0.3, pupil)

    def legs2(self, x, h, w, color):
        self.box(-x, h / 2, 0, w, h, w, color)
        self.box(x, h / 2, 0, w, h, w, color)

    def legs4(self, x, z, h, color, w=0.7):
        for sx in (-1, 1):
            for sz in (-1, 1):
                self.box(sx * x, h / 2, sz * z, w, h, w, color)

    def mirror_box(self, cx, cy, cz, sx, sy, sz, color):
        self.box(-cx, cy, cz, sx, sy, sz, color)
        self.box(cx, cy, cz, sx, sy, sz, color)


FACES = [
    ((1, 0, 0), [(1, 0, 0), (1, 1, 0), (1, 1, 1), (1, 0, 1)]),
    ((-1, 0, 0), [(0, 0, 1), (0, 1, 1), (0, 1, 0), (0, 0, 0)]),
    ((0, 1, 0), [(0, 1, 0), (0, 1, 1), (1, 1, 1), (1, 1, 0)]),
    ((0, -1, 0), [(0, 0, 1), (0, 0, 0), (1, 0, 0), (1, 0, 1)]),
    ((0, 0, 1), [(1, 0, 1), (1, 1, 1), (0, 1, 1), (0, 0, 1)]),
    ((0, 0, -1), [(0, 0, 0), (0, 1, 0), (1, 1, 0), (1, 0, 0)]),
]


def build_mesh(vox):
    """Visible voxel faces as (verts, quads, quad palette index) in EdenSpark axes."""
    verts, quads, qcol = [], [], []
    vs = vox.vs
    for (i, j, k), c in vox.cells.items():
        for normal, corners in FACES:
            if (i + normal[0], j + normal[1], k + normal[2]) in vox.cells:
                continue
            base = len(verts)
            for (dx, dy, dz) in corners:
                verts.append(((i + dx) * vs, (j + dy) * vs, (k + dz) * vs))
            quads.append((base, base + 1, base + 2, base + 3))
            qcol.append(c)
    return verts, quads, qcol


def export_glb(vox, path):
    verts, quads, qcol = build_mesh(vox)
    if hasattr(vox, "target_height"):
        low = min(v[1] for v in verts)
        high = max(v[1] for v in verts)
        factor = vox.target_height / (high - low)
        verts = [(x * factor, (y-low) * factor, z * factor) for x,y,z in verts]
    n = max(len(vox.palette), 1)
    # EdenSpark (x, y, z) -> Blender (x, -z, y) so the glTF exporter produces the same axes back.
    bverts = [(x, -z, y) for (x, y, z) in verts]
    # flipping the handedness is done by the axis swap above, so keep the winding as is
    mesh = bpy.data.meshes.new("brainrot")
    mesh.from_pydata(bverts, [], [q for q in quads])
    mesh.update()
    uv = mesh.uv_layers.new(name="UVMap")
    for poly in mesh.polygons:
        c = qcol[poly.index]
        u = (c + 0.5) / n
        for li in poly.loop_indices:
            uv.data[li].uv = (u, 0.5)
    obj = bpy.data.objects.new("brainrot", mesh)
    bpy.context.scene.collection.objects.link(obj)

    # palette image: one texel per color
    img = bpy.data.images.new("palette", width=n, height=1, alpha=False)
    pix = []
    for rgb in (vox.palette or [(1, 1, 1)]):
        pix += [rgb[0] ** 2.2, rgb[1] ** 2.2, rgb[2] ** 2.2, 1.0]
    img.pixels = pix
    img.pack()
    img.alpha_mode = "NONE"

    mat = bpy.data.materials.new("palette_mat")
    mat.use_nodes = True
    nt = mat.node_tree
    for node in list(nt.nodes):
        if node.type != "OUTPUT_MATERIAL":
            nt.nodes.remove(node)
    out = [n_ for n_ in nt.nodes if n_.type == "OUTPUT_MATERIAL"][0]
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    bsdf.inputs["Roughness"].default_value = 0.85
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = img
    tex.interpolation = "Closest"
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    obj.data.materials.append(mat)

    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_yup=True,
                              export_apply=True, export_image_format="AUTO")

    # clean up for the next model
    bpy.data.objects.remove(obj, do_unlink=True)
    bpy.data.meshes.remove(mesh)
    bpy.data.materials.remove(mat)
    bpy.data.images.remove(img)
    return len(quads)
