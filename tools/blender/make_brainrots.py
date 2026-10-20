"""Builds every brainrot as a voxel model and exports it to assets/brainrots/<slug>.glb.

Run:  blender -b --factory-startup -P make_brainrots.py -- <project_dir> [only_slug ...]
The roster (names, shapes, colors) is parsed from brainrot_data.das so the game and the models never drift apart.
"""
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import voxel_lib as vl  # noqa: E402
from voxel_lib import Vox, shade  # noqa: E402
from identity_builders import named_builder, TARGET_HEIGHTS

WHITE = (1.0, 1.0, 1.0)
BLACK = (0.05, 0.05, 0.07)
SKIN = (0.98, 0.80, 0.30)
VS = 0.16


def slug(name):
    return re.sub(r"[^a-z0-9]+", "_", name.lower()).strip("_")


def parse_roster(project):
    text = open(os.path.join(project, "brainrot_data.das"), encoding="utf-8").read()
    pat = re.compile(
        r'def_of\("([^"]+)",\s*(\d+),\s*big\([^)]*\),\s*big\([^)]*\),\s*(\d+),\s*float4\(([^)]*)\),\s*float4\(([^)]*)\)\)'
    )
    roster = []
    for m in pat.finditer(text):
        a = tuple(float(x) for x in m.group(4).split(",")[:3])
        b = tuple(float(x) for x in m.group(5).split(",")[:3])
        roster.append({"name": m.group(1), "rarity": int(m.group(2)), "shape": int(m.group(3)), "a": a, "b": b})
    return roster


def hash_name(s):
    h = 7
    for ch in s:
        h = (h * 31 + ord(ch)) % 9973
    return h


# ---------------------------------------------------------------- archetypes

def noob(v, a, b, name):
    v.legs2(0.5, 2.0, 0.95, (0.35, 0.65, 0.3))
    v.box(0, 3.0, 0, 2.0, 2.0, 1.0, a)
    v.box(-1.5, 3.0, 0, 0.95, 2.0, 0.95, SKIN)
    v.box(1.5, 3.0, 0, 0.95, 2.0, 0.95, SKIN)
    v.box(0, 4.7, 0, 1.5, 1.4, 1.3, SKIN)
    v.box(-0.25, 4.8, 0.66, 0.16, 0.26, 0.1, BLACK)
    v.box(0.25, 4.8, 0.66, 0.16, 0.26, 0.1, BLACK)
    v.box(0, 4.4, 0.66, 0.5, 0.1, 0.1, BLACK)
    v.ball(0, 5.55, 0, 2.9, 0.3, 2.9, b)  # pizza
    v.ball(0, 5.72, 0, 2.4, 0.15, 2.4, (1.0, 0.88, 0.3))
    for px, pz in ((-0.6, 0.5), (0.6, -0.3), (-0.2, -0.8), (0.7, 0.7)):
        v.ball(px, 5.86, pz, 0.55, 0.2, 0.55, (0.85, 0.15, 0.15))


def elephant_cactus(v, a, b, name):
    v.legs4(0.8, 0.7, 1.0, shade(a, 0.8), 0.9)
    v.ball(0, 2.2, 0, 2.6, 2.6, 2.4, a)
    v.ball(0, 3.7, 1.2, 2.0, 2.0, 1.8, a)
    v.box(-1.35, 3.8, 1.0, 0.3, 2.2, 1.8, shade(a, 1.15))
    v.box(1.35, 3.8, 1.0, 0.3, 2.2, 1.8, shade(a, 1.15))
    v.box(0, 2.9, 2.2, 0.8, 1.9, 0.8, a)
    v.box(0, 1.9, 2.5, 0.9, 0.7, 0.9, shade(a, 0.85))
    v.box(0.85, 1.0, 0.7, 0.9, 0.35, 0.9, b)  # wristwatch
    for i in range(7):
        v.box(-1.0 + i * 0.33, 3.6, -0.5 + (i % 2) * 0.5, 0.16, 0.5, 0.16, (0.1, 0.3, 0.12))
    v.ball(0, 4.1, -0.2, 0.7, 0.4, 0.7, (1.0, 0.45, 0.65))
    v.eyes(3.95, 2.0, 0.45, 0.45)


def cheese(v, a, b, name):
    v.box(0, 1.6, 0, 2.8, 2.6, 2.2, a)
    v.box(0, 3.2, -0.3, 2.4, 0.7, 1.5, a)
    for hx, hy, hz, r in ((-1.0, 2.0, 1.12, 0.7), (1.1, 1.0, 1.12, 0.5), (0.1, 2.9, 1.12, 0.4)):
        v.ball(hx, hy, hz, r, r, 0.3, b)
    v.ball(-1.0, 3.7, -0.3, 0.9, 0.9, 0.3, (0.75, 0.75, 0.8))
    v.ball(1.0, 3.7, -0.3, 0.9, 0.9, 0.3, (0.75, 0.75, 0.8))
    v.legs2(0.8, 0.5, 0.6, BLACK)
    v.eyes(2.4, 1.1, 0.5, 0.5)
    v.box(0, 1.75, 1.15, 0.35, 0.3, 0.2, (0.9, 0.4, 0.5))


def pig_bomb(v, a, b, name):
    v.legs4(0.8, 0.8, 0.9, shade(a, 0.85))
    v.ball(0, 1.9, 0, 2.4, 2.0, 3.2, a)
    v.ball(0, 2.7, 1.8, 2.0, 1.8, 1.6, a)
    v.box(0, 2.45, 2.7, 1.0, 0.8, 0.45, shade(a, 1.1))
    v.box(-0.7, 3.65, 1.7, 0.5, 0.6, 0.3, shade(a, 0.9))
    v.box(0.7, 3.65, 1.7, 0.5, 0.6, 0.3, shade(a, 0.9))
    v.eyes(2.95, 2.55, 0.5, 0.4)
    v.ball(0, 3.5, -0.5, 1.7, 1.7, 1.7, b)
    v.box(0, 4.5, -0.5, 0.2, 0.5, 0.2, (0.6, 0.45, 0.25))
    v.ball(0, 4.85, -0.5, 0.4, 0.4, 0.4, (1.0, 0.6, 0.1))


def kiwi(v, a, b, name):
    v.ball(0, 2.0, 0, 3.0, 2.8, 2.8, a)
    v.ball(0, 2.6, -0.4, 2.2, 1.8, 2.0, shade(a, 1.2))
    v.box(0, 2.0, 1.9, 0.35, 0.35, 2.0, (0.95, 0.75, 0.3))
    v.box(-0.6, 0.4, 0.2, 0.25, 0.8, 0.25, (0.95, 0.7, 0.3))
    v.box(0.6, 0.4, 0.2, 0.25, 0.8, 0.25, (0.95, 0.7, 0.3))
    v.ball(0, 1.4, 1.0, 1.1, 0.9, 0.3, b)
    v.eyes(2.7, 1.1, 0.55, 0.5)


def shrimp_cat(v, a, b, name):
    v.ball(0, 1.4, 0.2, 1.8, 1.6, 2.2, b)
    v.ball(0, 1.8, -1.4, 1.6, 1.6, 1.4, shade(b, 0.92))
    v.ball(0, 2.2, -2.5, 1.3, 1.3, 1.0, shade(b, 0.85))
    v.box(0, 2.9, -3.2, 1.8, 0.5, 0.8, a)
    v.legs4(0.7, 0.8, 0.7, shade(b, 0.7), 0.4)
    v.box(0, 3.1, 1.2, 2.2, 1.9, 1.8, a)
    v.box(-0.8, 4.2, 1.1, 0.55, 0.7, 0.3, a)
    v.box(0.8, 4.2, 1.1, 0.55, 0.7, 0.3, a)
    v.box(-1.5, 3.0, 2.1, 1.0, 0.08, 0.08, WHITE)
    v.box(1.5, 3.0, 2.1, 1.0, 0.08, 0.08, WHITE)
    v.eyes(3.4, 2.05, 0.55, 0.5)
    v.box(0, 3.0, 2.12, 0.3, 0.25, 0.1, (0.9, 0.4, 0.5))


def beaver(v, a, b, name):
    v.legs2(0.7, 1.0, 0.8, shade(a, 0.8))
    v.box(0, 2.4, 0, 2.2, 2.4, 1.8, a)
    v.box(0, 2.2, 0.6, 1.5, 1.6, 0.8, (0.95, 0.85, 0.65))
    v.box(0, 4.0, 0.2, 2.0, 1.6, 1.7, a)
    v.box(0, 3.55, 1.1, 0.5, 0.5, 0.15, WHITE)
    v.box(0, 1.4, -1.9, 1.6, 0.3, 2.0, shade(a, 0.6))
    v.box(0, 4.1, 1.06, 1.9, 0.45, 0.1, BLACK)
    v.ball(-0.45, 4.1, 1.12, 0.3, 0.3, 0.2, WHITE)
    v.ball(0.45, 4.1, 1.12, 0.3, 0.3, 0.2, WHITE)
    v.box(0, 4.95, 0.2, 3.6, 0.2, 3.6, b)
    v.box(0, 5.45, 0.2, 1.5, 0.9, 1.5, b)
    v.box(0, 5.12, 0.2, 1.6, 0.18, 1.6, (1.0, 0.85, 0.2))


def tire_frog(v, a, b, name):
    v.ball(0, 2.0, 0, 3.0, 3.0, 1.5, a)
    v.ball(0, 2.0, 0.35, 1.5, 1.5, 1.2, (0.55, 0.57, 0.62))
    v.ball(0, 3.9, 0.3, 1.9, 1.3, 1.6, b)
    v.ball(-0.6, 4.55, 0.7, 0.8, 0.8, 0.8, b)
    v.ball(0.6, 4.55, 0.7, 0.8, 0.8, 0.8, b)
    v.eyes(4.6, 1.05, 0.6, 0.5)
    v.box(-0.9, 0.4, 0.7, 0.5, 0.8, 1.4, b)
    v.box(0.9, 0.4, 0.7, 0.5, 0.8, 1.4, b)
    v.box(-1.8, 2.4, 0.2, 0.5, 1.4, 0.5, b)
    v.box(1.8, 2.4, 0.2, 0.5, 1.4, 0.5, b)


def log(v, a, b, name):
    v.box(0, 3.0, 0, 2.0, 4.6, 2.0, a)
    v.box(0, 5.35, 0, 1.5, 0.1, 1.5, b)
    v.box(0, 0.75, 0, 2.1, 0.5, 2.1, shade(a, 0.75))
    for yy in (1.6, 2.4):
        v.box(0.4, yy, 1.02, 0.9, 0.1, 0.05, shade(a, 0.7))
    v.box(-0.5, 4.5, 1.02, 0.55, 0.12, 0.1, b)
    v.box(0.5, 4.5, 1.02, 0.55, 0.12, 0.1, b)
    v.eyes(4.1, 1.05, 0.5, 0.55)
    v.box(0, 3.2, 1.02, 0.9, 0.35, 0.1, BLACK)
    v.box(-1.5, 2.8, 0.4, 0.5, 2.2, 0.5, shade(a, 1.1))
    v.box(1.5, 3.0, 0.9, 0.5, 0.5, 1.8, shade(a, 1.1))
    v.box(1.5, 3.9, 1.7, 0.4, 2.8, 0.4, shade(a, 0.9))
    v.box(1.5, 5.2, 1.7, 0.8, 1.6, 0.8, shade(a, 0.8))
    v.legs2(0.6, 0.8, 0.7, shade(a, 0.7))


def coffee_ninja(v, a, b, name):
    v.box(0, 1.6, 0, 1.8, 2.0, 1.8, a)
    v.box(0, 3.1, 0, 2.3, 1.2, 2.3, a)
    v.box(0, 3.85, 0, 2.1, 0.4, 2.1, (0.97, 0.92, 0.82))
    v.box(1.5, 2.6, 0, 0.35, 1.3, 0.5, shade(a, 0.8))
    v.box(0, 2.9, 1.0, 2.35, 0.9, 0.2, b)
    v.ball(-0.45, 2.95, 1.12, 0.42, 0.42, 0.2, WHITE)
    v.ball(0.45, 2.95, 1.12, 0.42, 0.42, 0.2, WHITE)
    v.ball(-0.45, 2.95, 1.25, 0.2, 0.2, 0.1, BLACK)
    v.ball(0.45, 2.95, 1.25, 0.2, 0.2, 0.1, BLACK)
    v.box(-1.7, 2.6, 0.8, 0.18, 0.18, 2.6, (0.85, 0.88, 0.95))
    v.box(1.9, 3.0, 0.5, 0.18, 2.6, 0.18, (0.85, 0.88, 0.95))
    v.box(-1.3, 2.0, 0.3, 0.6, 0.6, 0.6, b)
    v.legs2(0.5, 0.7, 0.6, b)


def tree_monkey(v, a, b, name):
    v.box(0, 3.3, 0, 1.8, 3.4, 1.8, a)
    v.box(0.5, 3.0, 0.95, 0.2, 2.0, 0.1, shade(a, 0.7))
    v.box(-0.4, 3.4, 0.95, 0.2, 1.6, 0.1, shade(a, 0.7))
    v.box(0, 5.3, 0, 2.8, 1.0, 2.8, b)
    v.box(0, 5.9, 0, 1.8, 0.8, 1.8, shade(b, 1.15))
    v.box(0, 4.1, 0.92, 1.4, 1.1, 0.2, (0.95, 0.78, 0.55))
    v.eyes(4.3, 1.05, 0.35, 0.35)
    v.box(0, 3.85, 1.2, 0.5, 0.9, 0.5, (0.9, 0.7, 0.5))  # long nose
    v.box(0, 3.6, 1.03, 0.6, 0.1, 0.1, BLACK)
    v.mirror_box(0.5, 0.9, 0, 0.45, 1.8, 0.45, shade(a, 0.9))
    v.mirror_box(0.5, 0.15, 0.45, 0.8, 0.3, 1.4, shade(a, 0.6))
    v.mirror_box(1.2, 3.6, 0.2, 0.4, 1.8, 0.4, shade(a, 1.1))


def fish_legs(v, a, b, name):
    v.legs2(0.5, 2.2, 0.55, b)
    v.mirror_box(0.5, 0.2, 0.3, 0.8, 0.4, 1.3, WHITE)
    v.ball(0, 3.7, 0, 2.3, 2.5, 1.7, a)
    v.ball(0, 3.5, 0.6, 1.6, 1.6, 0.6, shade(a, 1.4))
    v.box(0, 5.3, -0.3, 0.3, 1.0, 1.2, shade(a, 0.8))
    v.box(0, 3.9, -1.2, 0.3, 1.8, 1.0, shade(a, 0.8))
    v.eyes(4.4, 0.7, 0.6, 0.6)
    v.box(0, 3.9, 0.9, 1.2, 0.3, 0.2, BLACK)
    v.mirror_box(1.5, 3.4, 0.2, 0.5, 1.8, 0.5, b)


def dolphin_banana(v, a, b, name):
    v.box(0, 1.4, 0, 1.6, 2.2, 1.6, a)
    v.box(0, 3.3, 0.4, 1.6, 2.0, 1.6, a)
    v.box(0, 4.5, 0.9, 1.0, 0.6, 1.0, shade(a, 0.7))
    v.box(0, 3.4, 1.6, 0.8, 0.7, 1.4, b)
    v.mirror_box(1.2, 2.6, 0.2, 0.6, 0.3, 1.2, b)
    v.box(0, 0.4, -1.1, 1.8, 0.3, 0.9, b)
    v.eyes(3.8, 1.0, 0.5, 0.45)


def chimp_banana(v, a, b, name):
    v.box(0, 2.4, -0.4, 2.4, 4.0, 0.5, a)
    v.mirror_box(1.5, 2.0, 0.2, 0.5, 3.0, 1.4, shade(a, 0.9))
    v.mirror_box(1.8, 0.6, 0.6, 0.5, 1.4, 1.2, shade(a, 0.8))
    v.box(0, 1.8, 0.2, 1.9, 2.4, 1.2, b)
    v.box(0, 3.9, 0.2, 1.9, 1.7, 1.6, b)
    v.box(0, 3.7, 1.0, 1.4, 1.1, 0.2, (0.95, 0.78, 0.55))
    v.ball(-1.1, 4.1, 0.2, 0.7, 0.7, 0.3, (0.95, 0.78, 0.55))
    v.ball(1.1, 4.1, 0.2, 0.7, 0.7, 0.3, (0.95, 0.78, 0.55))
    v.eyes(4.0, 1.05, 0.4, 0.4)
    v.box(0, 3.4, 1.05, 0.7, 0.1, 0.1, BLACK)
    v.box(0, 4.8, -0.3, 0.5, 0.8, 0.5, shade(a, 0.5))


def ballerina(v, a, b, name):
    leg = (0.98, 0.82, 0.7)
    v.mirror_box(0.4, 1.1, 0, 0.45, 2.2, 0.45, leg)
    v.mirror_box(0.4, 0.15, 0.3, 0.55, 0.3, 0.9, (1.0, 0.8, 0.85))
    v.ball(0, 2.3, 0, 3.4, 0.4, 3.4, a)
    v.ball(0, 2.55, 0, 2.6, 0.35, 2.6, shade(a, 1.1))
    v.box(0, 3.3, 0, 1.4, 1.4, 0.9, a)
    v.mirror_box(1.0, 4.0, 0, 0.35, 1.8, 0.35, leg)
    v.box(0, 4.7, 0, 1.8, 1.3, 1.8, (0.98, 0.95, 0.88))
    v.box(0, 5.4, 0, 1.6, 0.2, 1.6, b)
    v.box(0, 5.58, 0, 0.8, 0.1, 0.8, (0.98, 0.95, 0.88))
    v.box(1.1, 4.7, 0, 0.3, 0.8, 0.3, (0.98, 0.95, 0.88))
    v.eyes(4.8, 0.95, 0.4, 0.4)


def croc_plane(v, a, b, name):
    v.legs4(0.7, 0.9, 0.7, shade(a, 0.8), 0.6)
    v.box(0, 1.8, 0, 1.8, 1.6, 4.2, a)
    v.box(0, 1.3, 0.2, 1.4, 0.6, 3.6, (0.85, 0.9, 0.55))
    v.box(0, 1.9, 2.9, 1.4, 0.9, 1.8, a)
    v.box(0, 1.3, 2.8, 1.3, 0.35, 1.6, shade(a, 0.8))
    for i in range(4):
        v.box(-0.5 + (i % 2), 1.5, 3.2 + (i // 2) * 0.5, 0.12, 0.3, 0.12, WHITE)
    v.mirror_box(2.3, 2.5, 0.2, 3.0, 0.2, 1.8, b)
    v.box(0, 2.8, -2.2, 0.2, 1.4, 1.0, b)
    v.box(0, 2.2, -2.2, 2.4, 0.15, 0.9, b)
    v.mirror_box(1.7, 1.9, 0.2, 0.7, 0.7, 1.1, (0.2, 0.2, 0.22))
    v.box(0, 2.0, 3.9, 2.4, 0.2, 0.15, (0.9, 0.9, 0.9))
    v.eyes(2.6, 2.2, 0.55, 0.5)


def shark_sneaker(v, a, b, name):
    for i, x in enumerate((-0.8, 0.0, 0.8)):
        v.box(x, 1.2, 0.2, 0.4, 1.6, 0.4, shade(a, 0.9))
        v.box(x, 0.25, 0.5, 0.75, 0.5, 1.4, (0.12, 0.42, 0.93))
        v.box(x, 0.12, 0.5, 0.8, 0.18, 1.45, WHITE)
        v.box(x, 0.52, 0.6, 0.30, 0.08, 0.72, WHITE)
    v.ball(0, 3.2, 0, 1.9, 2.6, 1.8, a)
    v.ball(0, 4.7, 0.3, 1.7, 1.5, 2.0, a)
    v.ball(0, 3.0, 0.7, 1.5, 2.0, 0.5, b)
    v.box(0, 5.2, -0.5, 0.25, 1.4, 1.0, shade(a, 0.8))
    v.box(0, 2.7, -1.4, 0.25, 1.6, 1.0, shade(a, 0.8))
    v.mirror_box(1.2, 3.4, 0.2, 0.7, 0.25, 1.0, shade(a, 0.85))
    v.box(0, 4.35, 1.28, 1.3, 0.3, 0.12, BLACK)
    for i in range(4):
        v.box(-0.45 + i * 0.3, 4.5, 1.3, 0.15, 0.2, 0.1, WHITE)
    v.eyes(5.0, 1.0, 0.5, 0.5)


def cow_saturn(v, a, b, name):
    v.ball(0, 2.4, 0, 3.8, 3.8, 3.8, a)
    v.ball(0, 3.4, 0, 3.5, 0.8, 3.5, b)
    v.ball(0, 1.4, 0, 3.5, 0.8, 3.5, b)
    v.ball(0, 2.4, 0, 6.2, 0.25, 6.2, shade(b, 0.85))
    v.erase_ball(0, 2.4, 0, 4.0, 0.5, 4.0)
    v.ball(0, 2.4, 0, 3.8, 3.8, 3.8, a)
    v.ball(0, 3.4, 0, 3.5, 0.8, 3.5, b)
    v.ball(0, 1.4, 0, 3.5, 0.8, 3.5, b)
    v.box(0, 4.6, 1.0, 1.9, 1.6, 1.6, (0.98, 0.98, 0.98))
    v.box(0.5, 4.8, 1.82, 0.7, 0.6, 0.1, BLACK)
    v.box(0, 4.25, 1.85, 1.1, 0.6, 0.4, (0.95, 0.7, 0.75))
    v.mirror_box(0.8, 5.6, 1.0, 0.25, 0.6, 0.25, (0.95, 0.9, 0.7))
    v.eyes(4.95, 1.75, 0.5, 0.4)
    v.legs2(0.9, 0.5, 0.7, BLACK)


def elephant(v, a, b, name):
    v.legs4(1.0, 1.1, 1.4, shade(a, 0.85), 1.1)
    v.box(0, 3.0, 0, 3.2, 3.0, 3.8, a)
    v.box(0, 4.3, 2.4, 2.4, 2.4, 2.0, a)
    v.mirror_box(1.9, 4.6, 2.2, 0.3, 2.6, 2.2, shade(a, 1.1))
    v.box(0, 3.4, 3.7, 0.9, 2.4, 0.9, a)
    v.box(0, 2.2, 4.0, 0.9, 0.9, 1.4, a)
    v.mirror_box(0.8, 3.2, 3.6, 0.25, 0.25, 1.2, WHITE)
    v.box(0, 5.0, -0.5, 0.4, 0.6, 0.4, b)
    v.box(-0.8, 4.95, -0.5, 1.4, 0.2, 0.8, b)
    v.box(0.8, 4.95, -0.5, 1.4, 0.2, 0.8, b)
    for i in range(9):
        v.box(-1.2 + (i % 4) * 0.8, 3.7 + (i % 3) * 0.4, -1.2 - (i // 4) * 0.4, 0.22, 0.32, 0.12, (1.0, 0.9, 0.3))
    v.eyes(5.0, 3.4, 0.6, 0.5)


def animal(v, a, b, name):
    h = hash_name(name)
    tall = (h % 3) * 0.5
    v.legs4(0.8, 1.0, 1.2 + tall * 0.5, shade(a, 0.8))
    v.ball(0, 2.2 + tall * 0.5, 0, 2.3, 2.1, 3.3, a)
    v.box(0, 1.6 + tall * 0.5, 0, 1.8, 0.5, 2.6, b)
    v.box(0, 3.2 + tall * 0.6, 1.4, 1.2, 1.4 + tall, 1.2, a)
    v.box(0, 4.0 + tall * 1.1, 1.9, 1.8, 1.6, 1.7, a)
    v.box(0, 3.8 + tall * 1.1, 2.8, 1.1, 0.8, 0.8, b)
    v.box(0, 4.0 + tall * 1.1, 3.22, 0.4, 0.3, 0.1, BLACK)
    v.mirror_box(0.75, 5.05 + tall * 1.1, 1.8, 0.45, 0.8, 0.3, shade(a, 0.9))
    v.box(0, 2.8 + tall * 0.5, -1.9, 0.4, 0.4, 1.2, shade(a, 0.85))
    if h % 2 == 0:
        v.box(0.6, 3.0 + tall * 0.5, 0.3, 0.9, 0.2, 0.9, b)
        v.box(-0.7, 2.9 + tall * 0.5, -0.8, 0.8, 0.2, 0.8, b)
    if h % 5 == 1:
        v.mirror_box(0.4, 5.55 + tall * 1.1, 1.8, 0.2, 0.7, 0.2, WHITE)
    v.eyes(4.4 + tall * 1.1, 2.7, 0.55, 0.45)


def fruit(v, a, b, name):
    v.ball(0, 2.7, 0, 3.0, 3.2, 3.0, a)
    v.box(0, 4.5, 0, 0.4, 0.7, 0.4, shade(b, 0.7))
    v.box(-0.7, 4.7, 0, 1.2, 0.2, 0.7, b)
    v.box(0.7, 4.8, 0, 1.2, 0.2, 0.7, b)
    v.legs2(0.7, 1.2, 0.5, shade(a, 0.7))
    v.mirror_box(0.7, 0.15, 0.3, 0.8, 0.3, 1.1, shade(b, 0.7))
    v.mirror_box(1.7, 2.6, 0.2, 0.45, 1.4, 0.45, shade(a, 0.8))
    v.box(0, 2.1, 1.48, 0.8, 0.2, 0.1, BLACK)
    v.eyes(3.0, 1.35, 0.6, 0.6)


def robot(v, a, b, name):
    v.legs2(0.7, 1.8, 0.8, shade(a, 0.7))
    v.mirror_box(0.7, 0.2, 0.3, 1.0, 0.4, 1.4, shade(a, 0.6))
    v.box(0, 3.4, 0, 2.8, 2.6, 2.0, a)
    v.box(0, 3.5, 1.02, 1.4, 1.0, 0.1, b)
    v.box(0, 5.3, 0, 2.0, 1.5, 1.8, shade(a, 1.1))
    v.box(0, 5.35, 0.92, 1.6, 0.6, 0.1, b)
    v.box(0, 6.3, 0, 0.15, 0.7, 0.15, shade(a, 0.6))
    v.ball(0, 6.75, 0, 0.4, 0.4, 0.4, b)
    v.mirror_box(1.9, 3.5, 0, 0.8, 2.4, 0.8, shade(a, 0.85))


def octopus(v, a, b, name):
    v.ball(0, 3.8, 0, 3.0, 2.8, 2.8, a)
    v.ball(0, 4.9, -0.2, 1.6, 1.2, 1.6, shade(a, 1.15))
    import math as m
    for i in range(8):
        ang = i * m.pi * 2 / 8
        v.box(m.cos(ang) * 1.2, 1.0, m.sin(ang) * 1.2, 0.5, 2.0, 0.5, a)
        v.box(m.cos(ang) * 1.3, 0.2, m.sin(ang) * 1.3, 0.6, 0.4, 0.6, b)
    v.eyes(3.9, 1.3, 0.65, 0.7)
    v.box(0, 3.0, 1.35, 0.8, 0.15, 0.1, BLACK)


def bird(v, a, b, name):
    v.ball(0, 2.4, 0, 2.6, 3.0, 2.4, a)
    v.ball(0, 2.2, 0.8, 1.6, 1.8, 0.6, shade(a, 1.3))
    v.box(0, 3.1, 1.5, 0.8, 0.45, 0.9, (1.0, 0.65, 0.15))
    v.mirror_box(1.5, 2.4, 0, 0.3, 1.8, 1.4, shade(a, 0.8))
    v.mirror_box(0.5, 0.45, 0.2, 0.3, 0.9, 0.3, (1.0, 0.65, 0.15))
    v.box(0, 0.1, 0.5, 1.6, 0.2, 1.0, (1.0, 0.65, 0.15))
    v.ball(0, 4.0, -0.2, 1.2, 1.2, 1.2, b)
    v.eyes(3.4, 1.0, 0.55, 0.5)


def panda(v, a, b, name):
    v.legs2(0.8, 1.0, 0.9, b)
    v.ball(0, 2.4, 0, 2.8, 2.8, 2.4, a)
    v.ball(0, 4.3, 0.3, 2.4, 2.0, 2.0, a)
    v.mirror_box(1.0, 5.2, 0.2, 0.8, 0.8, 0.4, b)
    v.ball(-0.55, 4.45, 1.12, 0.7, 0.8, 0.25, b)
    v.ball(0.55, 4.45, 1.12, 0.7, 0.8, 0.25, b)
    v.ball(-0.55, 4.45, 1.28, 0.22, 0.22, 0.1, WHITE)
    v.ball(0.55, 4.45, 1.28, 0.22, 0.22, 0.1, WHITE)
    v.box(0, 4.0, 1.25, 0.4, 0.3, 0.15, b)
    v.box(-1.6, 2.6, 0.3, 0.7, 1.6, 0.7, b)
    v.box(1.6, 2.6, 0.5, 0.7, 1.4, 0.7, b)
    v.box(1.9, 3.5, 0.8, 0.4, 1.6, 0.4, (1.0, 0.88, 0.25))


def human(v, a, b, name):
    skin = (0.98, 0.8, 0.65)
    v.legs2(0.5, 2.2, 0.9, shade(a, 0.8))
    v.box(0, 3.4, 0, 2.0, 2.2, 1.0, a)
    v.box(0, 3.4, 0.52, 0.3, 1.6, 0.05, b)
    v.mirror_box(1.5, 3.4, 0, 0.9, 2.2, 0.9, a)
    v.box(0, 5.1, 0, 1.6, 1.5, 1.4, skin)
    v.box(0, 5.95, -0.05, 1.7, 0.5, 1.5, b)
    v.box(0, 5.15, 0.72, 1.5, 0.35, 0.1, BLACK)
    v.box(0, 4.55, 0.72, 0.5, 0.08, 0.05, BLACK)


def toilet(v, a, b, name):
    v.box(0, 1.0, 0, 2.2, 1.8, 2.8, a)
    v.ball(0, 2.2, 0.3, 2.8, 1.0, 3.2, a)
    v.box(0, 3.4, -1.3, 2.6, 2.4, 0.9, shade(a, 0.95))
    v.box(0, 2.8, 0.3, 2.5, 0.2, 2.9, shade(a, 0.9))
    v.box(0.9, 4.7, -1.3, 0.5, 0.3, 0.3, (0.75, 0.78, 0.85))
    v.box(0, 3.9, 0.5, 1.6, 1.5, 1.4, b)
    v.box(0, 4.8, 0.4, 1.7, 0.4, 1.5, (0.2, 0.15, 0.1))
    v.eyes(4.0, 1.2, 0.4, 0.45)
    v.box(0, 3.4, 1.22, 0.7, 0.2, 0.1, BLACK)


BUILDERS = {
    0: noob, 1: elephant_cactus, 2: cheese, 3: pig_bomb, 4: kiwi, 5: shrimp_cat, 6: beaver, 7: tire_frog, 8: log,
    9: coffee_ninja, 10: tree_monkey, 11: fish_legs, 12: dolphin_banana, 13: chimp_banana, 14: ballerina,
    15: croc_plane, 16: shark_sneaker, 17: cow_saturn, 18: elephant, 19: animal, 20: fruit, 21: robot,
    22: octopus, 23: bird, 24: panda, 25: human, 26: toilet,
}


def main():
    argv = sys.argv
    args = argv[argv.index("--") + 1:] if "--" in argv else []
    project = args[0]
    only = set(args[1:])
    out = os.path.join(project, "assets", "brainrots")
    roster = parse_roster(project)
    print("roster entries:", len(roster))
    heights = []
    for r in roster:
        s = slug(r["name"])
        if only and s not in only:
            continue
        v = Vox(VS)
        builder = named_builder(r["name"], BUILDERS) or BUILDERS[r["shape"]]
        builder(v, r["a"], r["b"], r["name"])
        natural = (max(cell[1] for cell in v.cells)+1)*VS
        v.target_height = TARGET_HEIGHTS.get(r["name"], 5.0)
        heights.append(v.target_height)
        quads = vl.export_glb(v, os.path.join(out, s + ".glb"))
        print(f"  {s}: {len(v.cells)} voxels, {quads} faces, {len(v.palette)} colors")
    if not only:
        with open(os.path.join(project, "brainrot_bounds.das"), "w", encoding="utf-8") as f:
            f.write("// Generated from baked model bounds.\nlet public { BRAINROT_HEIGHTS = fixed_array(" + ", ".join(str(h) for h in heights) + ") }\n")
        names = ", ".join(f'"{slug(r["name"])}"' for r in roster)
        with open(os.path.join(project, "brainrot_files.das"), "w", encoding="utf-8") as f:
            f.write("// Generated by tools/blender/make_brainrots.py - model file slug of every roster entry.\n\nlet public {\n    BRAINROT_MODEL_FILES = fixed_array(" + names + ")\n}\n")

main()
