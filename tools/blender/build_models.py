"""Procedural modern-navy models for Modern Ships.

Run:  blender -b --factory-startup --python tools/blender/build_models.py -- game/assets/models

Conventions (Blender space): bow toward +Y, beam along X, up is +Z, waterline at Z=0.
The glTF exporter (+Y up) turns this into Godot's bow toward -Z, up +Y.
Look: low-poly stealth facets with bevelled edges -- no raw primitives.
"""
import math
import os
import random
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector, noise

OUT = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else "game/assets/models"

MATERIALS = {
    # name: (base sRGB hex, emission hex or None, emission strength, roughness, metallic)
    "HullDark": ("#36404c", None, 0.0, 0.62, 0.25),
    "Deck": ("#232a32", None, 0.0, 0.85, 0.1),
    "Superstructure": ("#4b5766", None, 0.0, 0.55, 0.25),
    "Accent": ("#141a21", None, 0.0, 0.45, 0.4),
    "Rail": ("#4a5562", None, 0.0, 0.3, 0.85),
    "Marking": ("#7d8a97", None, 0.0, 0.7, 0.0),
    "Window": ("#2a2418", "#ffd27a", 4.0, 0.2, 0.0),
    "NavRed": ("#300808", "#ff2a2a", 6.0, 0.3, 0.0),
    "NavGreen": ("#083008", "#2aff6a", 6.0, 0.3, 0.0),
    "EnemyAccent": ("#3a0c0c", "#ff3b3b", 5.0, 0.3, 0.0),
    "Energy": ("#0a2a30", "#4de8ff", 1.0, 0.2, 0.0),
    "PlayerAccent": ("#0a2a30", "#4de8ff", 3.0, 0.3, 0.0),
    "EnemyHull": ("#2e333a", None, 0.0, 0.65, 0.25),
    "EnemyDeck": ("#16191d", None, 0.0, 0.85, 0.1),
    "Rock": ("#2a2f36", None, 0.0, 0.95, 0.0),
    "Vegetation": ("#1c2a25", None, 0.0, 1.0, 0.0),
    "Sand": ("#3d3a36", None, 0.0, 1.0, 0.0),
}


def srgb(hexs):
    h = hexs.lstrip("#")
    c = [int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)]
    return [x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c]


def make_materials():
    for name, (base, emi, strength, rough, metal) in MATERIALS.items():
        m = bpy.data.materials.new(name)
        m.use_nodes = True
        b = m.node_tree.nodes["Principled BSDF"]
        b.inputs["Base Color"].default_value = (*srgb(base), 1.0)
        b.inputs["Roughness"].default_value = rough
        b.inputs["Metallic"].default_value = metal
        if emi:
            b.inputs["Emission Color"].default_value = (*srgb(emi), 1.0)
            b.inputs["Emission Strength"].default_value = strength


class Part:
    """Accumulates faceted geometry with per-face material names, then becomes one object."""

    def __init__(self):
        self.verts = []
        self.faces = []
        self.mats = []

    def add_faces(self, verts, faces, mats):
        base = len(self.verts)
        self.verts += [tuple(v) for v in verts]
        for f, m in zip(faces, mats):
            self.faces.append([base + i for i in f])
            self.mats.append(m)

    def tapered(self, center, bottom, top, height, mat, top_shift=(0.0, 0.0), rot=None):
        """Frustum box: center = bottom-center (x, y, z); bottom/top = half sizes (x, y)."""
        cx, cy, cz = center
        bx, by = bottom
        tx, ty = top
        sx, sy = top_shift
        v = [(-bx, -by, 0), (bx, -by, 0), (bx, by, 0), (-bx, by, 0),
             (-tx + sx, -ty + sy, height), (tx + sx, -ty + sy, height), (tx + sx, ty + sy, height), (-tx + sx, ty + sy, height)]
        m = rot if rot is not None else Matrix.Identity(3)
        v = [m @ Vector(p) + Vector((cx, cy, cz)) for p in v]
        f = [(0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)]
        self.add_faces(v, f, [mat] * 6)

    def box(self, center, half, mat, rot=None):
        """Centered box, optionally rotated about its own center."""
        hx, hy, hz = half
        m = rot if rot is not None else Matrix.Identity(3)
        c = Vector(center)
        v = [m @ Vector(p) + c for p in ((-hx, -hy, -hz), (hx, -hy, -hz), (hx, hy, -hz), (-hx, hy, -hz),
                                        (-hx, -hy, hz), (hx, -hy, hz), (hx, hy, hz), (-hx, hy, hz))]
        f = [(0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)]
        self.add_faces(v, f, [mat] * 6)

    def loft(self, rings, deck_mat, hull_mat, cap_start=True, cap_end=True):
        """Rings of equal length; the segment from the last point back to the first is the deck."""
        n = len(rings[0])
        verts = [p for r in rings for p in r]
        faces, mats = [], []
        for i in range(len(rings) - 1):
            for j in range(n):
                a, b = i * n + j, i * n + (j + 1) % n
                c, d = (i + 1) * n + (j + 1) % n, (i + 1) * n + j
                faces.append((a, b, c, d))
                mats.append(deck_mat if j == n - 1 else hull_mat)
        if cap_start:
            faces.append(tuple(range(n)))
            mats.append(hull_mat)
        if cap_end:
            k = (len(rings) - 1) * n
            faces.append(tuple(range(k, k + n)))
            mats.append(hull_mat)
        self.add_faces(verts, faces, mats)

    def build(self, name, parent=None, bevel=0.05, location=(0, 0, 0)):
        me = bpy.data.meshes.new(name)
        me.from_pydata(self.verts, [], self.faces)
        me.update()
        bm = bmesh.new()
        bm.from_mesh(me)
        bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.0005)
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        bm.to_mesh(me)
        bm.free()
        order = []
        for m in self.mats:
            if m not in order:
                order.append(m)
        for m in order:
            me.materials.append(bpy.data.materials[m])
        for poly, m in zip(me.polygons, self.mats):
            poly.material_index = order.index(m)
        ob = bpy.data.objects.new(name, me)
        bpy.context.collection.objects.link(ob)
        ob.location = location
        if parent is not None:
            ob.parent = parent
        if bevel > 0:
            mod = ob.modifiers.new("Bevel", "BEVEL")
            mod.width = bevel
            mod.segments = 1
            mod.limit_method = "ANGLE"
            mod.angle_limit = math.radians(30)
        return ob


def empty(name, location, parent=None):
    ob = bpy.data.objects.new(name, None)
    ob.empty_display_size = 0.3
    bpy.context.collection.objects.link(ob)
    ob.location = location
    if parent is not None:
        ob.parent = parent
    return ob


def rot(yaw_deg=0.0, pitch_deg=0.0, roll_deg=0.0):
    return (Matrix.Rotation(math.radians(yaw_deg), 3, "Z") @ Matrix.Rotation(math.radians(pitch_deg), 3, "X")
            @ Matrix.Rotation(math.radians(roll_deg), 3, "Y"))


# ---------------------------------------------------------------- hull

def ring(st):
    """Station (y_wl, y_deck, wl_half, deck_half, deck_h, keel) -> stealth cross-section (tumblehome + chine)."""
    y, yd, wl, dk, dh, keel = st
    ych = (y + yd) / 2
    return [(-dk, yd, dh), (-wl * 1.02, ych, dh * 0.42), (-wl, y, 0.0), (-wl * 0.72, y, -keel * 0.6), (0.0, y, -keel),
            (wl * 0.72, y, -keel * 0.6), (wl, y, 0.0), (wl * 1.02, ych, dh * 0.42), (dk, yd, dh)]


def lerp_station(a, b, t):
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(6))


def stations_between(stations, y0, y1):
    """Stations clipped to [y0, y1] along waterline y, with interpolated cut stations."""
    out = []
    for i in range(len(stations) - 1):
        a, b = stations[i], stations[i + 1]
        for y in (y0, y1):
            if a[0] < y < b[0]:
                out.append(lerp_station(a, b, (y - a[0]) / (b[0] - a[0])))
    out += [s for s in stations if y0 <= s[0] <= y1]
    out.sort(key=lambda s: s[0])
    return out


def scale_stations(stations, ls, ws, hs=1.0):
    return [(s[0] * ls, s[1] * ls, s[2] * ws, s[3] * ws, s[4] * hs, s[5] * hs) for s in stations]


DESTROYER_STATIONS = [
    (-12.0, -12.0, 1.85, 1.55, 1.15, 0.7),
    (-9.0, -9.0, 2.2, 1.8, 1.25, 1.0),
    (-3.0, -3.0, 2.3, 1.9, 1.3, 1.2),
    (4.0, 4.0, 2.2, 1.8, 1.3, 1.2),
    (8.0, 7.8, 1.55, 1.15, 1.3, 1.0),
    (10.6, 10.0, 0.7, 0.4, 1.28, 0.7),
    (12.2, 10.9, 0.03, 0.03, 1.25, 0.3),
]


def vls_grid(part, y0, x_count, y_count, z):
    for ix in range(x_count):
        for iy in range(y_count):
            x = (ix - (x_count - 1) / 2) * 0.46
            part.box((x, y0 + iy * 0.46, z + 0.035), (0.19, 0.19, 0.035), "Accent")


def build_destroyer():
    hull = Part()
    hull.loft([ring(s) for s in DESTROYER_STATIONS], "Deck", "HullDark")
    root = None
    hull.build("Hull", root, bevel=0.06)

    D = 1.3
    s = Part()
    # deckhouse with sloped faces, second tier, integrated pyramid mast
    s.tapered((0, -2.2, D), (1.75, 3.6), (1.35, 3.0), 1.9, "Superstructure", top_shift=(0, -0.3))
    s.tapered((0, -2.4, D + 1.9), (1.35, 2.4), (1.05, 1.8), 1.3, "Superstructure", top_shift=(0, -0.2))
    s.tapered((0, -2.6, D + 3.2), (0.95, 0.95), (0.3, 0.3), 3.4, "Superstructure")
    s.tapered((0, -2.6, D + 6.6), (0.12, 0.12), (0.04, 0.04), 1.2, "Accent")
    # flat radar arrays on the four diagonal mast faces
    for yaw in (45, -45, 135, -135):
        r = rot(yaw, -14)
        off = rot(yaw) @ Vector((0, 0.72, 0))
        s.box((off.x, -2.6 + off.y, D + 4.2), (0.55, 0.05, 0.55), "Accent", rot=r)
    # bridge window band on the sloped front face of tier 2
    s.box((0, -2.4 + 2.33, D + 2.55), (1.12, 0.03, 0.12), "Window", rot=rot(0, 24))
    # hangar + helicopter deck with markings
    s.tapered((0, -7.6, D), (1.7, 1.9), (1.4, 1.7), 1.5, "Superstructure", top_shift=(0, 0.1))
    s.box((0, -10.8, D + 0.02), (1.45, 1.15, 0.02), "Accent")
    for (cx, cy, hx, hy) in ((0, -9.75, 0.9, 0.04), (0, -11.85, 0.9, 0.04), (-0.86, -10.8, 0.04, 1.05), (0.86, -10.8, 0.04, 1.05)):
        s.box((cx, cy, D + 0.045), (hx, hy, 0.01), "Marking")
    # vertical launch cells
    vls_grid(s, 2.5, 4, 2, D)
    vls_grid(s, 8.2, 3, 2, D)
    # cyan identity stripes (player = cyan) along the deckhouse and hangar
    for x in (-1.0, 1.0):
        s.box((x * 1.66, -2.4, D + 0.55), (0.02, 3.3, 0.045), "PlayerAccent")
        s.box((x * 1.62, -7.6, D + 0.55), (0.02, 1.8, 0.045), "PlayerAccent")
    # navigation lights
    s.box((-1.58, -1.2, D + 1.55), (0.06, 0.12, 0.06), "NavRed")
    s.box((1.58, -1.2, D + 1.55), (0.06, 0.12, 0.06), "NavGreen")
    s.box((0, -2.6, D + 7.85), (0.06, 0.06, 0.06), "NavRed")
    s.build("Superstructure", root, bevel=0.04)
    empty("Bridge", (0, -2.4, D + 3.2), root)

    # railgun turret on the foredeck
    pivot = empty("TurretPivot", (0, 5.4, D), root)
    g = Part()
    g.tapered((0, 0.1, 0), (1.25, 1.5), (0.95, 1.15), 0.6, "Superstructure")
    g.tapered((0, 0.7, 0.6), (0.75, 1.1), (0.55, 0.8), 0.45, "Superstructure", top_shift=(0, 0.2))
    zr = 0.8
    for x in (-0.27, 0.27):
        g.box((x, 4.9, zr), (0.07, 3.7, 0.12), "Rail")
    g.box((0, 4.9, zr), (0.16, 3.6, 0.025), "Energy")
    for y in (2.0, 3.4, 4.8, 6.2, 7.6):
        g.box((0, y, zr + 0.3), (0.48, 0.09, 0.05), "Accent")
        g.box((0, y, zr - 0.3), (0.48, 0.09, 0.05), "Accent")
        g.box((-0.43, y, zr), (0.05, 0.09, 0.3), "Accent")
        g.box((0.43, y, zr), (0.05, 0.09, 0.3), "Accent")
    g.box((0, 8.7, zr), (0.4, 0.12, 0.2), "Accent")
    railgun = g.build("Railgun", pivot, bevel=0.025)
    empty("Muzzle", (0, 8.95, zr), railgun)

    # aft point-defence mount
    flak_pivot = empty("FlakPivot", (0, -8.0, D + 1.5), root)
    f = Part()
    f.tapered((0, 0, 0), (0.45, 0.45), (0.35, 0.35), 0.45, "Superstructure")
    for x in (-0.12, 0.12):
        f.box((x, 0.6, 0.3), (0.04, 0.55, 0.04), "Accent")
    f.build("FlakGun", flak_pivot, bevel=0.02)
    return root


# ---------------------------------------------------------------- enemies

def split_hull(stations, split_y, deck_mat, hull_mat, bow, stern, bevel):
    st = Part()
    st.loft([ring(s) for s in stations_between(stations, -999, split_y)], deck_mat, hull_mat)
    st.build("SternHull", stern, bevel=bevel)
    bw = Part()
    bw.loft([ring(s) for s in stations_between(stations, split_y, 999)], deck_mat, hull_mat)
    bw.build("BowHull", bow, bevel=bevel)


def small_turret(part, center, barrel_len, mat="EnemyHull"):
    x, y, z = center
    part.tapered((x, y, z), (0.42, 0.5), (0.3, 0.36), 0.32, mat, top_shift=(0, -0.08))
    part.box((x, y + 0.35 + barrel_len / 2, z + 0.2), (0.05, barrel_len / 2, 0.05), "Accent")


def build_frigate():
    stations = scale_stations(DESTROYER_STATIONS, 16 / 24.4, 3.2 / 4.6, 0.9)
    root = None
    bow = empty("Bow", (0, 0, 0), root)
    stern = empty("Stern", (0, 0, 0), root)
    split_hull(stations, 0.0, "EnemyDeck", "EnemyHull", bow, stern, 0.05)
    D = 1.17
    s = Part()
    s.tapered((0, -2.0, D), (1.2, 2.3), (0.9, 1.8), 1.5, "EnemyHull", top_shift=(0, -0.25))
    s.tapered((0, -2.2, D + 1.5), (0.6, 0.6), (0.2, 0.2), 2.4, "EnemyHull")
    for x in (-1.0, 1.0):
        s.box((x * 1.06, -2.0, D + 0.8), (0.02, 1.9, 0.05), "EnemyAccent")
    s.box((0, -2.2, D + 3.95), (0.07, 0.07, 0.07), "EnemyAccent")
    s.box((0, -0.25, D + 1.15), (0.8, 0.03, 0.1), "Window", rot=rot(0, 26))
    small_turret(s, (-1.05, -4.6, D), 1.2)
    small_turret(s, (1.05, -4.6, D), 1.2)
    s.build("SternTop", stern, bevel=0.035)
    empty("Gun_1", (-1.05, -4.6 + 1.6, D + 0.2), stern)
    empty("Gun_2", (1.05, -4.6 + 1.6, D + 0.2), stern)
    b = Part()
    small_turret(b, (0, 3.2, D), 1.6)
    vls_grid(b, 1.0, 2, 2, D)
    b.build("BowTop", bow, bevel=0.03)
    empty("Gun_0", (0, 3.2 + 2.0, D + 0.2), bow)
    return root


def build_speedboat():
    stations = [
        (-3.0, -3.0, 0.85, 0.82, 0.55, 0.3),
        (-0.5, -0.5, 0.92, 0.9, 0.62, 0.42),
        (1.6, 1.5, 0.66, 0.6, 0.62, 0.34),
        (3.1, 2.6, 0.03, 0.03, 0.55, 0.1),
    ]
    root = None
    bow = empty("Bow", (0, 0, 0), root)
    stern = empty("Stern", (0, 0, 0), root)
    split_hull(stations, 0.2, "EnemyDeck", "EnemyHull", bow, stern, 0.03)
    s = Part()
    s.tapered((0, -0.9, 0.62), (0.62, 0.95), (0.45, 0.55), 0.55, "EnemyHull", top_shift=(0, -0.25))
    s.box((0, -0.12, 0.98), (0.5, 0.03, 0.12), "Accent", rot=rot(0, 40))
    for x in (-0.64, 0.64):
        s.box((x, -1.0, 0.75), (0.015, 0.9, 0.04), "EnemyAccent")
    for x in (-0.35, 0.35):
        s.tapered((x, -3.25, 0.1), (0.14, 0.16), (0.12, 0.13), 0.55, "Accent")
    s.build("SternTop", stern, bevel=0.02)
    b = Part()
    b.tapered((0, 1.2, 0.62), (0.2, 0.2), (0.14, 0.14), 0.28, "Accent")
    b.box((0, 1.75, 0.95), (0.035, 0.5, 0.035), "Accent")
    b.build("BowTop", bow, bevel=0.015)
    empty("Gun", (0, 2.3, 0.95), bow)
    return root


def build_submarine():
    def r_at(y):
        t = (y + 7.0) / 14.0
        if t < 0.25:
            return 0.95 * max(0.0, math.sin(t / 0.25 * math.pi / 2)) ** 0.6
        if t > 0.85:
            return 0.95 * max(0.0, math.cos(min(1.0, (t - 0.85) / 0.15) * math.pi / 2)) ** 0.7 + 0.04
        return 0.95

    zc = -0.55

    def rings(y0, y1, steps):
        out = []
        for i in range(steps + 1):
            y = y0 + (y1 - y0) * i / steps
            r = max(0.04, r_at(y))
            out.append([(math.sin(a) * r, y, zc + math.cos(a) * r * 0.92) for a in
                        [math.pi * 2 * k / 10 for k in range(10)]])
        return out

    root = None
    bow = empty("Bow", (0, 0, 0), root)
    stern = empty("Stern", (0, 0, 0), root)
    st = Part()
    st.loft(rings(-7.0, 0.0, 7), "EnemyHull", "EnemyHull")
    st.tapered((0, -6.4, zc), (0.03, 0.3), (0.03, 0.15), 1.3, "Accent", rot=None)
    for roll in (45, -45, 135, -135):
        st.box((0, -6.3, zc), (0.04, 0.35, 0.75), "Accent", rot=rot(0, 0, roll))
    st.build("SternHull", stern, bevel=0.02)
    bw = Part()
    bw.loft(rings(0.0, 7.0, 7), "EnemyHull", "EnemyHull")
    bw.tapered((0, 2.0, 0.25), (0.3, 1.25), (0.24, 0.85), 1.55, "EnemyHull", top_shift=(0, -0.2))
    bw.box((0, 2.1, 1.25), (0.95, 0.28, 0.03), "EnemyHull")
    bw.box((0, 1.5, 1.86), (0.06, 0.06, 0.06), "EnemyAccent")
    bw.box((0, 2.0, 1.95), (0.03, 0.03, 0.3), "Accent")
    bw.build("BowHull", bow, bevel=0.02)
    empty("Tube", (0, 7.2, zc), bow)
    return root


# ---------------------------------------------------------------- islands

def build_island(name, radius, seed):
    random.seed(seed)
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=3, radius=1.0)
    off = Vector((seed * 3.1, seed * 1.7, seed * 0.9))
    for v in bm.verts:
        d = v.co.normalized()
        n = noise.fractal(d * 1.8 + off, 0.6, 2.0, 4)
        r = radius * (0.8 + 0.35 * n)
        p = d * r
        p.z = p.z * 0.42 + radius * 0.06
        if p.z < -2.0:
            p.z = -2.0
        v.co = p
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    for m in ("Rock", "Vegetation", "Sand"):
        me.materials.append(bpy.data.materials[m])
    for poly in me.polygons:
        c = poly.center
        if c.z < 0.6:
            poly.material_index = 2
        elif poly.normal.z > 0.72 and c.z > radius * 0.12:
            poly.material_index = 1
        else:
            poly.material_index = 0
    ob = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(ob)
    return ob


# ---------------------------------------------------------------- export

def export(name, builder, *args):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    make_materials()
    builder(*args)
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, name + ".glb")
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", export_apply=True, export_yup=True)
    print("exported", path)


export("destroyer", build_destroyer)
export("frigate", build_frigate)
export("speedboat", build_speedboat)
export("submarine", build_submarine)
export("island_a", build_island, "IslandA", 18.0, 1)
export("island_b", build_island, "IslandB", 12.0, 2)
export("island_c", build_island, "IslandC", 8.0, 3)
