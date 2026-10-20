require engine.core
require constants
require brainrot_data
require brainrot_files
require brainrot_bounds

// Procedural Roblox-style block models. Every builder returns the root NodeId.


def public mk_box(parent : NodeId; name : string; pos, size : float3; color : float4; solid : bool = false) : NodeId {
    let node = create_node(NodeData(name = name, parent = parent, position = pos, scale = size))
    add_component(node, new Mesh(meshId = CUBE_MESH_ID, color = color))
    if (solid) {
        add_component(node, new Collider(shape = box_shape()))
    }
    return node
}

def public mk_ball(parent : NodeId; name : string; pos, size : float3; color : float4) : NodeId {
    let node = create_node(NodeData(name = name, parent = parent, position = pos, scale = size))
    add_component(node, new Mesh(meshId = SPHERE_MESH_ID, color = color))
    return node
}

def public mk_pivot(parent : NodeId; name : string; pos : float3) : NodeId {
    return create_node(NodeData(name = name, parent = parent, position = pos))
}


////////////////////////////////////////////////////////////////////////////////
// Roblox-style character: head, torso, two arms, two legs on pivots.
////////////////////////////////////////////////////////////////////////////////

struct public CharacterParts {
    root : NodeId
    armL : NodeId
    armR : NodeId
    legL : NodeId
    legR : NodeId
    head : NodeId
    torso : NodeId
}

def public build_character(parent : NodeId; shirt : float4) : CharacterParts {
    var parts : CharacterParts
    // the root origin is at the feet; legs are 2 tall, torso 2, head 1.2
    parts.root = create_node(NodeData(name = "avatar", parent = parent))
    let legColor = float4(0.20, 0.30, 0.65, 1.0)
    parts.torso = mk_box(parts.root, "torso", float3(0, 3.0, 0), float3(2.0, 2.0, 1.0), shirt)
    parts.head = mk_box(parts.root, "head", float3(0, 4.6, 0), float3(1.4, 1.2, 1.2), COL_SKIN)
    mk_box(parts.head, "eyeL", float3(-0.2, 0.1, 0.51), float3(0.12, 0.18, 0.05), COL_BLACK)
    mk_box(parts.head, "eyeR", float3(0.2, 0.1, 0.51), float3(0.12, 0.18, 0.05), COL_BLACK)
    mk_box(parts.head, "mouth", float3(0, -0.2, 0.51), float3(0.35, 0.07, 0.05), COL_BLACK)
    parts.armL = mk_pivot(parts.root, "armL", float3(-1.5, 3.9, 0))
    mk_box(parts.armL, "mesh", float3(0, -0.9, 0), float3(1.0, 2.0, 1.0), COL_SKIN)
    parts.armR = mk_pivot(parts.root, "armR", float3(1.5, 3.9, 0))
    mk_box(parts.armR, "mesh", float3(0, -0.9, 0), float3(1.0, 2.0, 1.0), COL_SKIN)
    parts.legL = mk_pivot(parts.root, "legL", float3(-0.5, 2.0, 0))
    mk_box(parts.legL, "mesh", float3(0, -1.0, 0), float3(1.0, 2.0, 1.0), legColor)
    parts.legR = mk_pivot(parts.root, "legR", float3(0.5, 2.0, 0))
    mk_box(parts.legR, "mesh", float3(0, -1.0, 0), float3(1.0, 2.0, 1.0), legColor)
    return parts
}


////////////////////////////////////////////////////////////////////////////////
// Brainrot creatures. Origin at the feet, facing +z, 4-6.5 units tall.
////////////////////////////////////////////////////////////////////////////////

def private eyes(p : NodeId; y, z, spread, size : float) {
    mk_ball(p, "eyeL", float3(-spread, y, z), float3(size), COL_WHITE)
    mk_ball(p, "eyeR", float3(spread, y, z), float3(size), COL_WHITE)
    mk_ball(p, "pupilL", float3(-spread, y, z + size * 0.32), float3(size * 0.5), COL_BLACK)
    mk_ball(p, "pupilR", float3(spread, y, z + size * 0.32), float3(size * 0.5), COL_BLACK)
}

def private legs4(p : NodeId; y, x, z, h : float; col : float4) {
    mk_box(p, "legFL", float3(-x, h * 0.5, z), float3(0.7, h, 0.7), col)
    mk_box(p, "legFR", float3(x, h * 0.5, z), float3(0.7, h, 0.7), col)
    mk_box(p, "legBL", float3(-x, h * 0.5, -z), float3(0.7, h, 0.7), col)
    mk_box(p, "legBR", float3(x, h * 0.5, -z), float3(0.7, h, 0.7), col)
}

def private legs2(p : NodeId; x, h, w : float; col : float4) {
    mk_box(p, "legL", float3(-x, h * 0.5, 0), float3(w, h, w), col)
    mk_box(p, "legR", float3(x, h * 0.5, 0), float3(w, h, w), col)
}

def private shade(c : float4; k : float) : float4 {
    return float4(c.x * k, c.y * k, c.z * k, c.w)
}

def private hash_name(s : string) : int {
    var h = 7
    for (i in range(length(s))) {
        h = (h * 31 + character_at(s, i)) % 9973
    }
    return h
}

def private build_noob(r : NodeId; a, b : float4) {
    let skin = float4(0.98, 0.82, 0.25, 1)
    legs2(r, 0.5, 2.0, 0.95, float4(0.35, 0.65, 0.3, 1))
    mk_box(r, "torso", float3(0, 3.0, 0), float3(2.0, 2.0, 1.0), a)
    mk_box(r, "armL", float3(-1.5, 3.0, 0), float3(0.95, 2.0, 0.95), skin)
    mk_box(r, "armR", float3(1.5, 3.0, 0), float3(0.95, 2.0, 0.95), skin)
    let head = mk_box(r, "head", float3(0, 4.7, 0), float3(1.5, 1.4, 1.3), skin)
    mk_box(head, "eyeL", float3(-0.2, 0.1, 0.51), float3(0.14, 0.2, 0.05), COL_BLACK)
    mk_box(head, "eyeR", float3(0.2, 0.1, 0.51), float3(0.14, 0.2, 0.05), COL_BLACK)
    mk_box(head, "smile", float3(0, -0.25, 0.51), float3(0.4, 0.07, 0.05), COL_BLACK)
    // the pizza on the head
    mk_box(r, "pizzaBase", float3(0, 5.55, 0), float3(2.8, 0.3, 2.8), b)
    mk_box(r, "pizzaCheese", float3(0, 5.72, 0), float3(2.3, 0.1, 2.3), float4(1.0, 0.88, 0.3, 1))
    mk_ball(r, "pep1", float3(-0.6, 5.85, 0.5), float3(0.55, 0.2, 0.55), float4(0.85, 0.15, 0.15, 1))
    mk_ball(r, "pep2", float3(0.6, 5.85, -0.3), float3(0.55, 0.2, 0.55), float4(0.85, 0.15, 0.15, 1))
    mk_ball(r, "pep3", float3(-0.2, 5.85, -0.7), float3(0.5, 0.2, 0.5), float4(0.85, 0.15, 0.15, 1))
}

def private build_elephant_cactus(r : NodeId; a, b : float4) {
    legs4(r, 0.0, 0.8, 0.7, 1.0, shade(a, 0.8))
    mk_box(r, "body", float3(0, 2.2, 0), float3(2.4, 2.4, 2.2), a)
    mk_box(r, "head", float3(0, 3.7, 1.2), float3(1.9, 1.9, 1.7), a)
    mk_box(r, "earL", float3(-1.35, 3.8, 1.0), float3(0.3, 2.2, 1.8), shade(a, 1.15))
    mk_box(r, "earR", float3(1.35, 3.8, 1.0), float3(0.3, 2.2, 1.8), shade(a, 1.15))
    mk_box(r, "trunk", float3(0, 2.9, 2.2), float3(0.7, 1.9, 0.7), a)
    mk_box(r, "trunkTip", float3(0, 1.9, 2.5), float3(0.8, 0.7, 0.8), shade(a, 0.85))
    mk_box(r, "watch", float3(0.85, 1.0, 0.7), float3(0.8, 0.35, 0.8), b)
    for (i in range(5)) {
        mk_box(r, "spine{i}", float3(-0.9 + float(i) * 0.45, 3.5, -0.4 + float(i % 2) * 0.5), float3(0.18, 0.5, 0.18), float4(0.1, 0.3, 0.12, 1))
    }
    mk_box(r, "flower", float3(0, 3.95, -0.2), float3(0.6, 0.35, 0.6), float4(1.0, 0.45, 0.65, 1))
    eyes(r, 3.95, 2.0, 0.45, 0.45)
}

def private build_cheese(r : NodeId; a, b : float4) {
    mk_box(r, "block", float3(0, 1.6, 0), float3(2.8, 2.6, 2.2), a)
    mk_box(r, "top", float3(0, 3.2, -0.3), float3(2.4, 0.7, 1.5), a)
    mk_ball(r, "hole1", float3(-1.0, 2.0, 1.12), float3(0.7, 0.7, 0.2), b)
    mk_ball(r, "hole2", float3(1.1, 1.0, 1.12), float3(0.5, 0.5, 0.2), b)
    mk_ball(r, "hole3", float3(1.42, 2.2, 0.2), float3(0.2, 0.6, 0.6), b)
    mk_ball(r, "earL", float3(-1.0, 3.7, -0.3), float3(0.9, 0.9, 0.3), float4(0.75, 0.75, 0.8, 1))
    mk_ball(r, "earR", float3(1.0, 3.7, -0.3), float3(0.9, 0.9, 0.3), float4(0.75, 0.75, 0.8, 1))
    legs2(r, 0.8, 0.5, 0.6, COL_BLACK)
    eyes(r, 2.4, 1.1, 0.5, 0.5)
    mk_box(r, "nose", float3(0, 1.75, 1.15), float3(0.35, 0.3, 0.2), float4(0.9, 0.4, 0.5, 1))
}

def private build_pig_bomb(r : NodeId; a, b : float4) {
    legs4(r, 0.0, 0.8, 0.8, 0.9, shade(a, 0.85))
    mk_box(r, "body", float3(0, 1.9, 0), float3(2.3, 2.0, 3.0), a)
    mk_box(r, "head", float3(0, 2.6, 1.8), float3(1.9, 1.8, 1.5), a)
    mk_box(r, "snout", float3(0, 2.4, 2.65), float3(1.0, 0.8, 0.4), shade(a, 1.1))
    mk_box(r, "earL", float3(-0.7, 3.65, 1.7), float3(0.5, 0.6, 0.3), shade(a, 0.9))
    mk_box(r, "earR", float3(0.7, 3.65, 1.7), float3(0.5, 0.6, 0.3), shade(a, 0.9))
    eyes(r, 2.95, 2.5, 0.5, 0.4)
    mk_ball(r, "bomb", float3(0, 3.5, -0.5), float3(1.6), b)
    mk_box(r, "fuse", float3(0, 4.45, -0.5), float3(0.2, 0.5, 0.2), float4(0.6, 0.45, 0.25, 1))
    mk_ball(r, "spark", float3(0, 4.8, -0.5), float3(0.4), float4(1.0, 0.6, 0.1, 1))
}

def private build_kiwi(r : NodeId; a, b : float4) {
    mk_ball(r, "body", float3(0, 2.0, 0), float3(3.0, 2.8, 2.8), a)
    mk_ball(r, "fuzz", float3(0, 2.6, -0.4), float3(2.2, 1.8, 2.0), shade(a, 1.2))
    mk_box(r, "beak", float3(0, 2.0, 1.9), float3(0.35, 0.35, 2.0), float4(0.95, 0.75, 0.3, 1))
    mk_box(r, "legL", float3(-0.6, 0.4, 0.2), float3(0.25, 0.8, 0.25), float4(0.95, 0.7, 0.3, 1))
    mk_box(r, "legR", float3(0.6, 0.4, 0.2), float3(0.25, 0.8, 0.25), float4(0.95, 0.7, 0.3, 1))
    mk_ball(r, "slice", float3(0, 1.4, 1.0), float3(1.1, 0.9, 0.2), b)
    eyes(r, 2.7, 1.1, 0.55, 0.5)
}

def private build_shrimp_cat(r : NodeId; a, b : float4) {
    mk_box(r, "seg1", float3(0, 1.4, 0.2), float3(1.8, 1.6, 2.2), b)
    mk_box(r, "seg2", float3(0, 1.8, -1.4), float3(1.6, 1.6, 1.4), shade(b, 0.92))
    mk_box(r, "seg3", float3(0, 2.2, -2.5), float3(1.3, 1.3, 1.0), shade(b, 0.85))
    mk_box(r, "tail", float3(0, 2.9, -3.2), float3(1.8, 0.5, 0.8), a)
    legs4(r, 0.0, 0.7, 0.8, 0.7, shade(b, 0.7))
    mk_box(r, "head", float3(0, 3.1, 1.2), float3(2.2, 1.9, 1.8), a)
    mk_box(r, "earL", float3(-0.8, 4.2, 1.1), float3(0.55, 0.7, 0.3), a)
    mk_box(r, "earR", float3(0.8, 4.2, 1.1), float3(0.55, 0.7, 0.3), a)
    mk_box(r, "whiskerL", float3(-1.5, 3.0, 2.1), float3(1.0, 0.08, 0.08), COL_WHITE)
    mk_box(r, "whiskerR", float3(1.5, 3.0, 2.1), float3(1.0, 0.08, 0.08), COL_WHITE)
    eyes(r, 3.4, 2.05, 0.55, 0.5)
    mk_box(r, "nose", float3(0, 3.0, 2.12), float3(0.3, 0.25, 0.1), float4(0.9, 0.4, 0.5, 1))
}

def private build_beaver(r : NodeId; a, b : float4) {
    legs2(r, 0.7, 1.0, 0.8, shade(a, 0.8))
    mk_box(r, "body", float3(0, 2.4, 0), float3(2.2, 2.4, 1.8), a)
    mk_box(r, "belly", float3(0, 2.2, 0.6), float3(1.5, 1.6, 0.8), float4(0.95, 0.85, 0.65, 1))
    mk_box(r, "head", float3(0, 4.0, 0.2), float3(2.0, 1.6, 1.7), a)
    mk_box(r, "teeth", float3(0, 3.55, 1.1), float3(0.5, 0.5, 0.15), COL_WHITE)
    mk_box(r, "tail", float3(0, 1.4, -1.9), float3(1.6, 0.3, 2.0), shade(a, 0.6))
    mk_box(r, "mask", float3(0, 4.1, 1.06), float3(1.9, 0.45, 0.1), COL_BLACK)
    mk_ball(r, "eyeL", float3(-0.45, 4.1, 1.12), float3(0.3), COL_WHITE)
    mk_ball(r, "eyeR", float3(0.45, 4.1, 1.12), float3(0.3), COL_WHITE)
    mk_box(r, "hatBrim", float3(0, 4.95, 0.2), float3(3.6, 0.2, 3.6), b)
    mk_box(r, "hatTop", float3(0, 5.45, 0.2), float3(1.5, 0.9, 1.5), b)
    mk_box(r, "hatBand", float3(0, 5.12, 0.2), float3(1.6, 0.18, 1.6), float4(1.0, 0.85, 0.2, 1))
}

def private build_tire_frog(r : NodeId; a, b : float4) {
    mk_ball(r, "tire", float3(0, 2.0, 0), float3(3.0, 3.0, 1.5), a)
    mk_ball(r, "rim", float3(0, 2.0, 0.35), float3(1.5, 1.5, 1.2), float4(0.55, 0.57, 0.62, 1))
    mk_ball(r, "headBase", float3(0, 3.9, 0.3), float3(1.9, 1.3, 1.6), b)
    mk_ball(r, "eyeBumpL", float3(-0.6, 4.55, 0.7), float3(0.8), b)
    mk_ball(r, "eyeBumpR", float3(0.6, 4.55, 0.7), float3(0.8), b)
    mk_ball(r, "eyeL", float3(-0.6, 4.6, 1.05), float3(0.5), COL_WHITE)
    mk_ball(r, "eyeR", float3(0.6, 4.6, 1.05), float3(0.5), COL_WHITE)
    mk_ball(r, "pupilL", float3(-0.6, 4.6, 1.3), float3(0.22), COL_BLACK)
    mk_ball(r, "pupilR", float3(0.6, 4.6, 1.3), float3(0.22), COL_BLACK)
    mk_box(r, "legL", float3(-0.9, 0.4, 0.7), float3(0.5, 0.8, 1.4), b)
    mk_box(r, "legR", float3(0.9, 0.4, 0.7), float3(0.5, 0.8, 1.4), b)
    mk_box(r, "armL", float3(-1.8, 2.4, 0.2), float3(0.5, 1.4, 0.5), b)
    mk_box(r, "armR", float3(1.8, 2.4, 0.2), float3(0.5, 1.4, 0.5), b)
}

def private build_log(r : NodeId; a, b : float4) {
    mk_box(r, "log", float3(0, 3.0, 0), float3(2.0, 4.6, 2.0), a)
    mk_box(r, "ringTop", float3(0, 5.35, 0), float3(1.5, 0.1, 1.5), b)
    mk_box(r, "ringBot", float3(0, 0.75, 0), float3(2.1, 0.5, 2.1), shade(a, 0.75))
    mk_box(r, "browL", float3(-0.5, 4.5, 1.02), float3(0.55, 0.12, 0.1), b)
    mk_box(r, "browR", float3(0.5, 4.5, 1.02), float3(0.55, 0.12, 0.1), b)
    mk_ball(r, "eyeL", float3(-0.5, 4.1, 1.05), float3(0.55), COL_WHITE)
    mk_ball(r, "eyeR", float3(0.5, 4.1, 1.05), float3(0.55), COL_WHITE)
    mk_ball(r, "pupilL", float3(-0.5, 4.1, 1.3), float3(0.25), COL_BLACK)
    mk_ball(r, "pupilR", float3(0.5, 4.1, 1.3), float3(0.25), COL_BLACK)
    mk_box(r, "mouth", float3(0, 3.2, 1.02), float3(0.9, 0.35, 0.1), COL_BLACK)
    mk_box(r, "armL", float3(-1.5, 2.8, 0.4), float3(0.5, 2.2, 0.5), shade(a, 1.1))
    mk_box(r, "armR", float3(1.5, 3.0, 0.9), float3(0.5, 0.5, 1.8), shade(a, 1.1))
    mk_box(r, "batHandle", float3(1.5, 3.9, 1.7), float3(0.4, 2.8, 0.4), shade(a, 0.9))
    mk_box(r, "batHead", float3(1.5, 5.2, 1.7), float3(0.8, 1.6, 0.8), shade(a, 0.8))
    legs2(r, 0.6, 0.8, 0.7, shade(a, 0.7))
}

def private build_coffee_ninja(r : NodeId; a, b : float4) {
    mk_box(r, "cupLow", float3(0, 1.6, 0), float3(1.8, 2.0, 1.8), a)
    mk_box(r, "cupHigh", float3(0, 3.1, 0), float3(2.3, 1.2, 2.3), a)
    mk_box(r, "foam", float3(0, 3.85, 0), float3(2.1, 0.4, 2.1), float4(0.97, 0.92, 0.82, 1))
    mk_box(r, "handle", float3(1.5, 2.6, 0), float3(0.35, 1.3, 0.5), shade(a, 0.8))
    mk_box(r, "band", float3(0, 2.9, 1.0), float3(2.35, 0.9, 0.2), b)
    mk_ball(r, "eyeL", float3(-0.45, 2.95, 1.12), float3(0.42), COL_WHITE)
    mk_ball(r, "eyeR", float3(0.45, 2.95, 1.12), float3(0.42), COL_WHITE)
    mk_ball(r, "pupilL", float3(-0.45, 2.95, 1.3), float3(0.2), COL_BLACK)
    mk_ball(r, "pupilR", float3(0.45, 2.95, 1.3), float3(0.2), COL_BLACK)
    mk_box(r, "katanaL", float3(-1.7, 2.6, 0.8), float3(0.18, 0.18, 2.6), float4(0.85, 0.88, 0.95, 1))
    mk_box(r, "katanaR", float3(1.9, 3.0, 0.5), float3(0.18, 2.6, 0.18), float4(0.85, 0.88, 0.95, 1))
    mk_box(r, "armL", float3(-1.3, 2.0, 0.3), float3(0.6, 0.6, 0.6), b)
    legs2(r, 0.5, 0.7, 0.6, b)
}

def private build_tree_monkey(r : NodeId; a, b : float4) {
    mk_box(r, "trunk", float3(0, 3.3, 0), float3(1.8, 3.4, 1.8), a)
    mk_box(r, "bark1", float3(0.5, 3.0, 0.95), float3(0.2, 2.0, 0.1), shade(a, 0.7))
    mk_box(r, "bark2", float3(-0.4, 3.4, 0.95), float3(0.2, 1.6, 0.1), shade(a, 0.7))
    mk_box(r, "leaves", float3(0, 5.3, 0), float3(2.8, 1.0, 2.8), b)
    mk_box(r, "leaves2", float3(0, 5.9, 0), float3(1.8, 0.8, 1.8), shade(b, 1.15))
    mk_box(r, "face", float3(0, 4.1, 0.92), float3(1.4, 1.1, 0.2), float4(0.95, 0.78, 0.55, 1))
    mk_ball(r, "eyeL", float3(-0.35, 4.3, 1.05), float3(0.35), COL_WHITE)
    mk_ball(r, "eyeR", float3(0.35, 4.3, 1.05), float3(0.35), COL_WHITE)
    mk_box(r, "mouth", float3(0, 3.7, 1.03), float3(0.6, 0.1, 0.1), COL_BLACK)
    mk_box(r, "legL", float3(-0.5, 0.9, 0), float3(0.45, 1.8, 0.45), shade(a, 0.9))
    mk_box(r, "legR", float3(0.5, 0.9, 0), float3(0.45, 1.8, 0.45), shade(a, 0.9))
    mk_box(r, "footL", float3(-0.5, 0.15, 0.4), float3(0.8, 0.3, 1.4), shade(a, 0.6))
    mk_box(r, "footR", float3(0.5, 0.15, 0.4), float3(0.8, 0.3, 1.4), shade(a, 0.6))
    mk_box(r, "armL", float3(-1.2, 3.6, 0.2), float3(0.4, 1.8, 0.4), shade(a, 1.1))
    mk_box(r, "armR", float3(1.2, 3.6, 0.2), float3(0.4, 1.8, 0.4), shade(a, 1.1))
}

def private build_fish_legs(r : NodeId; a, b : float4) {
    legs2(r, 0.5, 2.2, 0.55, b)
    mk_box(r, "shoeL", float3(-0.5, 0.2, 0.3), float3(0.8, 0.4, 1.3), COL_WHITE)
    mk_box(r, "shoeR", float3(0.5, 0.2, 0.3), float3(0.8, 0.4, 1.3), COL_WHITE)
    mk_box(r, "body", float3(0, 3.7, 0), float3(2.2, 2.4, 1.6), a)
    mk_box(r, "belly", float3(0, 3.5, 0.6), float3(1.6, 1.6, 0.6), shade(a, 1.4))
    mk_box(r, "fin", float3(0, 5.3, -0.3), float3(0.3, 1.0, 1.2), shade(a, 0.8))
    mk_box(r, "tail", float3(0, 3.9, -1.2), float3(0.3, 1.8, 1.0), shade(a, 0.8))
    mk_ball(r, "eyeL", float3(-1.0, 4.4, 0.5), float3(0.6), COL_WHITE)
    mk_ball(r, "eyeR", float3(1.0, 4.4, 0.5), float3(0.6), COL_WHITE)
    mk_ball(r, "pupilL", float3(-1.2, 4.4, 0.65), float3(0.25), COL_BLACK)
    mk_ball(r, "pupilR", float3(1.2, 4.4, 0.65), float3(0.25), COL_BLACK)
    mk_box(r, "mouth", float3(0, 3.9, 0.85), float3(1.2, 0.3, 0.2), COL_BLACK)
    mk_box(r, "armL", float3(-1.5, 3.4, 0.2), float3(0.5, 1.8, 0.5), b)
    mk_box(r, "armR", float3(1.5, 3.4, 0.2), float3(0.5, 1.8, 0.5), b)
}

def private build_dolphin_banana(r : NodeId; a, b : float4) {
    mk_box(r, "banana1", float3(0, 1.4, 0), float3(1.6, 2.2, 1.6), a)
    mk_box(r, "banana2", float3(0, 3.3, 0.4), float3(1.6, 2.0, 1.6), a)
    mk_box(r, "tip", float3(0, 4.5, 0.9), float3(1.0, 0.6, 1.0), shade(a, 0.7))
    mk_box(r, "snout", float3(0, 3.4, 1.6), float3(0.8, 0.7, 1.4), b)
    mk_box(r, "flipperL", float3(-1.2, 2.6, 0.2), float3(0.6, 0.3, 1.2), b)
    mk_box(r, "flipperR", float3(1.2, 2.6, 0.2), float3(0.6, 0.3, 1.2), b)
    mk_box(r, "tailFin", float3(0, 0.4, -1.1), float3(1.8, 0.3, 0.9), b)
    eyes(r, 3.8, 1.0, 0.5, 0.45)
}

def private build_chimp_banana(r : NodeId; a, b : float4) {
    mk_box(r, "peelBack", float3(0, 2.4, -0.4), float3(2.4, 4.0, 0.5), a)
    mk_box(r, "peelL", float3(-1.5, 2.0, 0.2), float3(0.5, 3.0, 1.4), shade(a, 0.9))
    mk_box(r, "peelR", float3(1.5, 2.0, 0.2), float3(0.5, 3.0, 1.4), shade(a, 0.9))
    mk_box(r, "peelFlapL", float3(-1.8, 0.6, 0.6), float3(0.5, 1.4, 1.2), shade(a, 0.8))
    mk_box(r, "peelFlapR", float3(1.8, 0.6, 0.6), float3(0.5, 1.4, 1.2), shade(a, 0.8))
    mk_box(r, "body", float3(0, 1.8, 0.2), float3(1.9, 2.4, 1.2), b)
    mk_box(r, "head", float3(0, 3.9, 0.2), float3(1.9, 1.7, 1.6), b)
    mk_box(r, "face", float3(0, 3.7, 1.0), float3(1.4, 1.1, 0.2), float4(0.95, 0.78, 0.55, 1))
    mk_ball(r, "earL", float3(-1.1, 4.1, 0.2), float3(0.7, 0.7, 0.3), float4(0.95, 0.78, 0.55, 1))
    mk_ball(r, "earR", float3(1.1, 4.1, 0.2), float3(0.7, 0.7, 0.3), float4(0.95, 0.78, 0.55, 1))
    eyes(r, 4.0, 1.0, 0.4, 0.4)
    mk_box(r, "stem", float3(0, 4.8, -0.3), float3(0.5, 0.8, 0.5), shade(a, 0.5))
}

def private build_ballerina(r : NodeId; a, b : float4) {
    mk_box(r, "legL", float3(-0.4, 1.1, 0), float3(0.45, 2.2, 0.45), float4(0.98, 0.82, 0.7, 1))
    mk_box(r, "legR", float3(0.4, 1.1, 0), float3(0.45, 2.2, 0.45), float4(0.98, 0.82, 0.7, 1))
    mk_box(r, "shoeL", float3(-0.4, 0.15, 0.3), float3(0.55, 0.3, 0.9), float4(1.0, 0.8, 0.85, 1))
    mk_box(r, "shoeR", float3(0.4, 0.15, 0.3), float3(0.55, 0.3, 0.9), float4(1.0, 0.8, 0.85, 1))
    mk_box(r, "tutu", float3(0, 2.3, 0), float3(3.2, 0.3, 3.2), a)
    mk_box(r, "tutu2", float3(0, 2.55, 0), float3(2.5, 0.3, 2.5), shade(a, 1.1))
    mk_box(r, "torso", float3(0, 3.3, 0), float3(1.4, 1.4, 0.9), a)
    mk_box(r, "armL", float3(-1.0, 4.0, 0), float3(0.35, 1.8, 0.35), float4(0.98, 0.82, 0.7, 1))
    mk_box(r, "armR", float3(1.0, 4.0, 0), float3(0.35, 1.8, 0.35), float4(0.98, 0.82, 0.7, 1))
    // the head is a cappuccino cup
    mk_box(r, "cup", float3(0, 4.7, 0), float3(1.8, 1.3, 1.8), float4(0.98, 0.95, 0.88, 1))
    mk_box(r, "coffee", float3(0, 5.4, 0), float3(1.6, 0.2, 1.6), b)
    mk_box(r, "saucer", float3(0, 5.58, 0), float3(0.8, 0.1, 0.8), float4(0.98, 0.95, 0.88, 1))
    mk_box(r, "handle", float3(1.1, 4.7, 0), float3(0.3, 0.8, 0.3), float4(0.98, 0.95, 0.88, 1))
    eyes(r, 4.8, 0.95, 0.4, 0.4)
}

def private build_croc_plane(r : NodeId; a, b : float4) {
    legs4(r, 0.0, 0.7, 0.9, 0.7, shade(a, 0.8))
    mk_box(r, "body", float3(0, 1.8, 0), float3(1.8, 1.6, 4.2), a)
    mk_box(r, "belly", float3(0, 1.3, 0.2), float3(1.4, 0.6, 3.6), float4(0.85, 0.9, 0.55, 1))
    mk_box(r, "snout", float3(0, 1.9, 2.9), float3(1.4, 0.9, 1.8), a)
    mk_box(r, "jaw", float3(0, 1.3, 2.8), float3(1.3, 0.35, 1.6), shade(a, 0.8))
    for (i in range(4)) {
        mk_box(r, "tooth{i}", float3(-0.5 + float(i % 2) * 1.0, 1.5, 3.2 + float(i / 2) * 0.5), float3(0.12, 0.3, 0.12), COL_WHITE)
    }
    mk_box(r, "wingL", float3(-2.3, 2.5, 0.2), float3(3.0, 0.2, 1.8), b)
    mk_box(r, "wingR", float3(2.3, 2.5, 0.2), float3(3.0, 0.2, 1.8), b)
    mk_box(r, "tailFin", float3(0, 2.8, -2.2), float3(0.2, 1.4, 1.0), b)
    mk_box(r, "tailWing", float3(0, 2.2, -2.2), float3(2.4, 0.15, 0.9), b)
    mk_ball(r, "bomb1", float3(-1.7, 1.9, 0.2), float3(0.7, 0.7, 1.1), float4(0.2, 0.2, 0.22, 1))
    mk_ball(r, "bomb2", float3(1.7, 1.9, 0.2), float3(0.7, 0.7, 1.1), float4(0.2, 0.2, 0.22, 1))
    mk_box(r, "prop", float3(0, 2.0, 3.9), float3(2.4, 0.2, 0.15), float4(0.9, 0.9, 0.9, 1))
    eyes(r, 2.6, 2.2, 0.55, 0.5)
}

def private build_shark_sneaker(r : NodeId; a, b : float4) {
    for (i in range(3)) {
        let x = (float(i) - 1.0) * 0.8
        mk_box(r, "leg{i}", float3(x, 1.2, 0.2), float3(0.4, 1.6, 0.4), shade(a, 0.9))
        mk_box(r, "sneaker{i}", float3(x, 0.25, 0.5), float3(0.75, 0.5, 1.4), COL_WHITE)
        mk_box(r, "stripe{i}", float3(x, 0.3, 0.5), float3(0.8, 0.12, 1.45), float4(0.9, 0.25, 0.25, 1))
    }
    mk_box(r, "body", float3(0, 3.2, 0), float3(1.9, 2.6, 1.8), a)
    mk_box(r, "head", float3(0, 4.7, 0.3), float3(1.7, 1.5, 2.0), a)
    mk_box(r, "belly", float3(0, 3.0, 0.7), float3(1.5, 2.0, 0.5), b)
    mk_box(r, "fin", float3(0, 5.2, -0.5), float3(0.25, 1.4, 1.0), shade(a, 0.8))
    mk_box(r, "tail", float3(0, 2.7, -1.4), float3(0.25, 1.6, 1.0), shade(a, 0.8))
    mk_box(r, "finL", float3(-1.2, 3.4, 0.2), float3(0.7, 0.25, 1.0), shade(a, 0.85))
    mk_box(r, "finR", float3(1.2, 3.4, 0.2), float3(0.7, 0.25, 1.0), shade(a, 0.85))
    mk_box(r, "mouth", float3(0, 4.35, 1.28), float3(1.3, 0.3, 0.12), COL_BLACK)
    for (i in range(4)) {
        mk_box(r, "teeth{i}", float3(-0.45 + float(i) * 0.3, 4.5, 1.29), float3(0.15, 0.2, 0.1), COL_WHITE)
    }
    eyes(r, 5.0, 1.0, 0.5, 0.5)
}

def private build_cow_saturn(r : NodeId; a, b : float4) {
    mk_ball(r, "sphere1", float3(0, 2.4, 0), float3(3.8, 3.8, 3.8), a)
    mk_ball(r, "band1", float3(0, 3.4, 0), float3(3.5, 0.8, 3.5), b)
    mk_ball(r, "band2", float3(0, 1.4, 0), float3(3.5, 0.8, 3.5), b)
    mk_box(r, "ring", float3(0, 2.4, 0), float3(6.2, 0.25, 6.2), shade(b, 0.85))
    mk_box(r, "ringHole", float3(0, 2.4, 0), float3(4.2, 0.3, 4.2), shade(a, 0.7))
    mk_box(r, "head", float3(0, 4.6, 1.0), float3(1.9, 1.6, 1.6), float4(0.98, 0.98, 0.98, 1))
    mk_box(r, "spot", float3(0.5, 4.8, 1.82), float3(0.7, 0.6, 0.1), COL_BLACK)
    mk_box(r, "snout", float3(0, 4.25, 1.85), float3(1.1, 0.6, 0.4), float4(0.95, 0.7, 0.75, 1))
    mk_box(r, "hornL", float3(-0.8, 5.6, 1.0), float3(0.25, 0.6, 0.25), float4(0.95, 0.9, 0.7, 1))
    mk_box(r, "hornR", float3(0.8, 5.6, 1.0), float3(0.25, 0.6, 0.25), float4(0.95, 0.9, 0.7, 1))
    eyes(r, 4.95, 1.75, 0.5, 0.4)
    legs2(r, 0.9, 0.5, 0.7, COL_BLACK)
}

def private build_elephant(r : NodeId; a, b : float4) {
    legs4(r, 0.0, 1.0, 1.1, 1.4, shade(a, 0.85))
    mk_box(r, "body", float3(0, 3.0, 0), float3(3.2, 3.0, 3.8), a)
    mk_box(r, "head", float3(0, 4.3, 2.4), float3(2.4, 2.4, 2.0), a)
    mk_box(r, "earL", float3(-1.9, 4.6, 2.2), float3(0.3, 2.6, 2.2), shade(a, 1.1))
    mk_box(r, "earR", float3(1.9, 4.6, 2.2), float3(0.3, 2.6, 2.2), shade(a, 1.1))
    mk_box(r, "trunk1", float3(0, 3.4, 3.7), float3(0.9, 2.4, 0.9), a)
    mk_box(r, "trunk2", float3(0, 2.2, 4.0), float3(0.9, 0.9, 1.4), a)
    mk_box(r, "tuskL", float3(-0.8, 3.2, 3.6), float3(0.25, 0.25, 1.2), COL_WHITE)
    mk_box(r, "tuskR", float3(0.8, 3.2, 3.6), float3(0.25, 0.25, 1.2), COL_WHITE)
    mk_box(r, "stem", float3(0, 5.0, -0.5), float3(0.4, 0.6, 0.4), b)
    mk_box(r, "leaf1", float3(-0.8, 4.95, -0.5), float3(1.4, 0.2, 0.8), b)
    mk_box(r, "leaf2", float3(0.8, 4.95, -0.5), float3(1.4, 0.2, 0.8), b)
    for (i in range(7)) {
        mk_box(r, "seed{i}", float3(-1.2 + float(i % 4) * 0.8, 3.7 + float(i % 3) * 0.4, -1.2 - float(i / 4) * 0.4), float3(0.22, 0.32, 0.12), float4(1.0, 0.9, 0.3, 1))
    }
    eyes(r, 5.0, 3.35, 0.6, 0.5)
}

def private build_animal(r : NodeId; name : string; a, b : float4) {
    let h = hash_name(name)
    let tall = float(h % 3) * 0.5
    legs4(r, 0.0, 0.8, 1.0, 1.2 + tall * 0.5, shade(a, 0.8))
    mk_box(r, "body", float3(0, 2.2 + tall * 0.5, 0), float3(2.2, 2.0, 3.2), a)
    mk_box(r, "belly", float3(0, 1.6 + tall * 0.5, 0), float3(1.8, 0.5, 2.6), b)
    mk_box(r, "neck", float3(0, 3.2 + tall * 0.6, 1.4), float3(1.2, 1.4 + tall, 1.2), a)
    mk_box(r, "head", float3(0, 4.0 + tall * 1.1, 1.9), float3(1.8, 1.6, 1.7), a)
    mk_box(r, "snout", float3(0, 3.8 + tall * 1.1, 2.8), float3(1.1, 0.8, 0.8), b)
    mk_box(r, "nose", float3(0, 4.0 + tall * 1.1, 3.22), float3(0.4, 0.3, 0.1), COL_BLACK)
    mk_box(r, "earL", float3(-0.75, 5.05 + tall * 1.1, 1.8), float3(0.45, 0.8, 0.3), shade(a, 0.9))
    mk_box(r, "earR", float3(0.75, 5.05 + tall * 1.1, 1.8), float3(0.45, 0.8, 0.3), shade(a, 0.9))
    mk_box(r, "tail", float3(0, 2.8 + tall * 0.5, -1.9), float3(0.4, 0.4, 1.2), shade(a, 0.85))
    if (h % 2 == 0) {
        mk_box(r, "spot1", float3(0.6, 3.0 + tall * 0.5, 0.3), float3(0.9, 0.2, 0.9), b)
        mk_box(r, "spot2", float3(-0.7, 2.9 + tall * 0.5, -0.8), float3(0.8, 0.2, 0.8), b)
    }
    if (h % 5 == 1) {
        mk_box(r, "hornL", float3(-0.4, 5.55 + tall * 1.1, 1.8), float3(0.2, 0.7, 0.2), COL_WHITE)
        mk_box(r, "hornR", float3(0.4, 5.55 + tall * 1.1, 1.8), float3(0.2, 0.7, 0.2), COL_WHITE)
    }
    eyes(r, 4.4 + tall * 1.1, 2.7, 0.55, 0.45)
}

def private build_fruit(r : NodeId; a, b : float4) {
    mk_ball(r, "fruit", float3(0, 2.7, 0), float3(3.0, 3.2, 3.0), a)
    mk_box(r, "stem", float3(0, 4.5, 0), float3(0.4, 0.7, 0.4), shade(b, 0.7))
    mk_box(r, "leaf1", float3(-0.7, 4.7, 0), float3(1.2, 0.2, 0.7), b)
    mk_box(r, "leaf2", float3(0.7, 4.8, 0), float3(1.2, 0.2, 0.7), b)
    legs2(r, 0.7, 1.2, 0.5, shade(a, 0.7))
    mk_box(r, "footL", float3(-0.7, 0.15, 0.3), float3(0.8, 0.3, 1.1), shade(b, 0.7))
    mk_box(r, "footR", float3(0.7, 0.15, 0.3), float3(0.8, 0.3, 1.1), shade(b, 0.7))
    mk_box(r, "armL", float3(-1.7, 2.6, 0.2), float3(0.45, 1.4, 0.45), shade(a, 0.8))
    mk_box(r, "armR", float3(1.7, 2.6, 0.2), float3(0.45, 1.4, 0.45), shade(a, 0.8))
    mk_box(r, "mouth", float3(0, 2.1, 1.48), float3(0.8, 0.2, 0.1), COL_BLACK)
    eyes(r, 3.0, 1.35, 0.6, 0.6)
}

def private build_robot(r : NodeId; a, b : float4) {
    legs2(r, 0.7, 1.8, 0.8, shade(a, 0.7))
    mk_box(r, "footL", float3(-0.7, 0.2, 0.3), float3(1.0, 0.4, 1.4), shade(a, 0.6))
    mk_box(r, "footR", float3(0.7, 0.2, 0.3), float3(1.0, 0.4, 1.4), shade(a, 0.6))
    mk_box(r, "body", float3(0, 3.4, 0), float3(2.8, 2.6, 2.0), a)
    mk_box(r, "chest", float3(0, 3.5, 1.02), float3(1.4, 1.0, 0.1), b)
    mk_box(r, "head", float3(0, 5.3, 0), float3(2.0, 1.5, 1.8), shade(a, 1.1))
    mk_box(r, "visor", float3(0, 5.35, 0.92), float3(1.6, 0.6, 0.1), b)
    mk_box(r, "antenna", float3(0, 6.3, 0), float3(0.15, 0.7, 0.15), shade(a, 0.6))
    mk_ball(r, "antennaBall", float3(0, 6.75, 0), float3(0.4), b)
    mk_box(r, "armL", float3(-1.9, 3.5, 0), float3(0.8, 2.4, 0.8), shade(a, 0.85))
    mk_box(r, "armR", float3(1.9, 3.5, 0), float3(0.8, 2.4, 0.8), shade(a, 0.85))
}

def private build_octopus(r : NodeId; a, b : float4) {
    mk_ball(r, "head", float3(0, 3.8, 0), float3(3.0, 2.8, 2.8), a)
    mk_ball(r, "top", float3(0, 4.9, -0.2), float3(1.6, 1.2, 1.6), shade(a, 1.15))
    for (i in range(8)) {
        let ang = float(i) * PI * 2.0 / 8.0
        mk_box(r, "tent{i}", float3(cos(ang) * 1.2, 1.0, sin(ang) * 1.2), float3(0.5, 2.0, 0.5), a)
        mk_box(r, "tip{i}", float3(cos(ang) * 1.3, 0.2, sin(ang) * 1.3), float3(0.6, 0.4, 0.6), b)
    }
    eyes(r, 3.9, 1.25, 0.65, 0.7)
    mk_box(r, "mouth", float3(0, 3.0, 1.35), float3(0.8, 0.15, 0.1), COL_BLACK)
}

def private build_bird(r : NodeId; a, b : float4) {
    mk_ball(r, "body", float3(0, 2.4, 0), float3(2.6, 3.0, 2.4), a)
    mk_box(r, "belly", float3(0, 2.2, 0.8), float3(1.6, 1.8, 0.6), shade(a, 1.3))
    mk_box(r, "beak", float3(0, 3.1, 1.5), float3(0.8, 0.45, 0.9), float4(1.0, 0.65, 0.15, 1))
    mk_box(r, "wingL", float3(-1.5, 2.4, 0), float3(0.3, 1.8, 1.4), shade(a, 0.8))
    mk_box(r, "wingR", float3(1.5, 2.4, 0), float3(0.3, 1.8, 1.4), shade(a, 0.8))
    mk_box(r, "legL", float3(-0.5, 0.45, 0.2), float3(0.3, 0.9, 0.3), float4(1.0, 0.65, 0.15, 1))
    mk_box(r, "legR", float3(0.5, 0.45, 0.2), float3(0.3, 0.9, 0.3), float4(1.0, 0.65, 0.15, 1))
    mk_box(r, "feet", float3(0, 0.1, 0.5), float3(1.6, 0.2, 1.0), float4(1.0, 0.65, 0.15, 1))
    mk_ball(r, "extra", float3(0, 4.0, -0.2), float3(1.2), b)
    eyes(r, 3.4, 1.0, 0.55, 0.5)
}

def private build_panda(r : NodeId; a, b : float4) {
    legs2(r, 0.8, 1.0, 0.9, b)
    mk_ball(r, "body", float3(0, 2.4, 0), float3(2.8, 2.8, 2.4), a)
    mk_ball(r, "head", float3(0, 4.3, 0.3), float3(2.4, 2.0, 2.0), a)
    mk_ball(r, "earL", float3(-1.0, 5.2, 0.2), float3(0.8, 0.8, 0.4), b)
    mk_ball(r, "earR", float3(1.0, 5.2, 0.2), float3(0.8, 0.8, 0.4), b)
    mk_ball(r, "patchL", float3(-0.55, 4.45, 1.12), float3(0.7, 0.8, 0.25), b)
    mk_ball(r, "patchR", float3(0.55, 4.45, 1.12), float3(0.7, 0.8, 0.25), b)
    mk_ball(r, "pupilL", float3(-0.55, 4.45, 1.28), float3(0.22), COL_WHITE)
    mk_ball(r, "pupilR", float3(0.55, 4.45, 1.28), float3(0.22), COL_WHITE)
    mk_box(r, "nose", float3(0, 4.0, 1.25), float3(0.4, 0.3, 0.15), b)
    mk_box(r, "armL", float3(-1.6, 2.6, 0.3), float3(0.7, 1.6, 0.7), b)
    mk_box(r, "armR", float3(1.6, 2.6, 0.5), float3(0.7, 1.4, 0.7), b)
    mk_box(r, "banana", float3(1.9, 3.5, 0.8), float3(0.4, 1.6, 0.4), float4(1.0, 0.88, 0.25, 1))
}

def private build_human(r : NodeId; a, b : float4) {
    let skin = float4(0.98, 0.8, 0.65, 1)
    legs2(r, 0.5, 2.2, 0.9, shade(a, 0.8))
    mk_box(r, "torso", float3(0, 3.4, 0), float3(2.0, 2.2, 1.0), a)
    mk_box(r, "tie", float3(0, 3.4, 0.52), float3(0.3, 1.6, 0.05), b)
    mk_box(r, "armL", float3(-1.5, 3.4, 0), float3(0.9, 2.2, 0.9), a)
    mk_box(r, "armR", float3(1.5, 3.4, 0), float3(0.9, 2.2, 0.9), a)
    mk_box(r, "head", float3(0, 5.1, 0), float3(1.6, 1.5, 1.4), skin)
    mk_box(r, "hair", float3(0, 5.95, -0.05), float3(1.7, 0.5, 1.5), b)
    mk_box(r, "glasses", float3(0, 5.15, 0.72), float3(1.5, 0.35, 0.1), COL_BLACK)
    mk_box(r, "mouth", float3(0, 4.55, 0.72), float3(0.5, 0.08, 0.05), COL_BLACK)
}

def private build_toilet(r : NodeId; a, b : float4) {
    mk_box(r, "base", float3(0, 1.0, 0), float3(2.2, 1.8, 2.8), a)
    mk_box(r, "bowl", float3(0, 2.2, 0.3), float3(2.8, 1.0, 3.2), a)
    mk_box(r, "tank", float3(0, 3.4, -1.3), float3(2.6, 2.4, 0.9), shade(a, 0.95))
    mk_box(r, "lid", float3(0, 2.8, 0.3), float3(2.5, 0.2, 2.9), shade(a, 0.9))
    mk_box(r, "flush", float3(0.9, 4.7, -1.3), float3(0.5, 0.3, 0.3), float4(0.75, 0.78, 0.85, 1))
    mk_box(r, "head", float3(0, 3.9, 0.5), float3(1.6, 1.5, 1.4), b)
    mk_box(r, "hair", float3(0, 4.8, 0.4), float3(1.7, 0.4, 1.5), float4(0.2, 0.15, 0.1, 1))
    eyes(r, 4.0, 1.2, 0.4, 0.45)
    mk_box(r, "mouth", float3(0, 3.4, 1.22), float3(0.7, 0.2, 0.1), COL_BLACK)
}

def private mutation_color(a : float4; m : int; k : float) : float4 {
    if (m <= 0) {
        return a
    }
    let c = MUTATION_COLORS[m]
    return float4(a.x + (c.x - a.x) * k, a.y + (c.y - a.y) * k, a.z + (c.z - a.z) * k, 1.0)
}

var private brainrotPrefabs : array<PrefabId>

// request every baked voxel model (made by tools/blender/make_brainrots.py)
def public load_brainrot_prefabs() {
    brainrotPrefabs |> clear()
    for (f in BRAINROT_MODEL_FILES) {
        brainrotPrefabs |> push(request_prefab("assets/brainrots/{f}.glb"))
    }
}

// paint every mesh under `node` (mutations tint the baked palette textures)
def public tint_tree(node : NodeId; color : float4) {
    node?.Mesh.color = color
    var inscope kids = node.get_children()
    for (k in kids) {
        tint_tree(k, color)
    }
}

def public build_brainrot(parent : NodeId; defId : int; mutation : int = 0) : NodeId {
    if (defId >= 0 && defId < length(brainrotPrefabs) && brainrotPrefabs[defId] != PrefabId()) {
        let model = instantiate_prefab(brainrotPrefabs[defId], NodeData(name = "brainrot_{BRAINROTS[defId].name}", parent = parent))
        if (mutation > 0) {
            tint_tree(model, MUTATION_COLORS[mutation])
        }
        return model
    }
    return build_brainrot_blocks(parent, defId, mutation)
}

def private build_brainrot_blocks(parent : NodeId; defId : int; mutation : int = 0) : NodeId {
    let bd = BRAINROTS[defId]
    // mutations repaint the body fully and the accents partly
    let a = mutation_color(bd.colorA, mutation, 0.88)
    let b = mutation_color(bd.colorB, mutation, 0.45)
    let root = create_node(NodeData(name = "brainrot_{bd.name}", parent = parent))
    let s = bd.shape
    if (s == int(Shape.Noob)) {
        build_noob(root, a, b)
    } elif (s == int(Shape.ElephantCactus)) {
        build_elephant_cactus(root, a, b)
    } elif (s == int(Shape.Cheese)) {
        build_cheese(root, a, b)
    } elif (s == int(Shape.PigBomb)) {
        build_pig_bomb(root, a, b)
    } elif (s == int(Shape.Kiwi)) {
        build_kiwi(root, a, b)
    } elif (s == int(Shape.ShrimpCat)) {
        build_shrimp_cat(root, a, b)
    } elif (s == int(Shape.Beaver)) {
        build_beaver(root, a, b)
    } elif (s == int(Shape.TireFrog)) {
        build_tire_frog(root, a, b)
    } elif (s == int(Shape.Log)) {
        build_log(root, a, b)
    } elif (s == int(Shape.CoffeeNinja)) {
        build_coffee_ninja(root, a, b)
    } elif (s == int(Shape.TreeMonkey)) {
        build_tree_monkey(root, a, b)
    } elif (s == int(Shape.FishLegs)) {
        build_fish_legs(root, a, b)
    } elif (s == int(Shape.DolphinBanana)) {
        build_dolphin_banana(root, a, b)
    } elif (s == int(Shape.ChimpBanana)) {
        build_chimp_banana(root, a, b)
    } elif (s == int(Shape.Ballerina)) {
        build_ballerina(root, a, b)
    } elif (s == int(Shape.CrocPlane)) {
        build_croc_plane(root, a, b)
    } elif (s == int(Shape.SharkSneaker)) {
        build_shark_sneaker(root, a, b)
    } elif (s == int(Shape.CowSaturn)) {
        build_cow_saturn(root, a, b)
    } elif (s == int(Shape.Elephant)) {
        build_elephant(root, a, b)
    } elif (s == int(Shape.Fruit)) {
        build_fruit(root, a, b)
    } elif (s == int(Shape.Robot)) {
        build_robot(root, a, b)
    } elif (s == int(Shape.Octopus)) {
        build_octopus(root, a, b)
    } elif (s == int(Shape.Bird)) {
        build_bird(root, a, b)
    } elif (s == int(Shape.Panda)) {
        build_panda(root, a, b)
    } elif (s == int(Shape.Human)) {
        build_human(root, a, b)
    } elif (s == int(Shape.Toilet)) {
        build_toilet(root, a, b)
    } else {
        build_animal(root, bd.name, a, b)
    }
    return root
}

// height of the creature, for placing overhead labels
def public brainrot_height(defId : int) : float {
    return BRAINROT_HEIGHTS[clamp(defId,0,brainrot_count()-1)]
}


////////////////////////////////////////////////////////////////////////////////
// World props
////////////////////////////////////////////////////////////////////////////////

def public build_tree(parent : NodeId; pos : float3; scale : float = 1.0) : NodeId {
    let root = create_node(NodeData(name = "tree", parent = parent, position = pos, scale = float3(scale)))
    mk_box(root, "trunk", float3(0, 2.0, 0), float3(1.2, 4.0, 1.2), float4(0.50, 0.33, 0.17, 1.0), true)
    mk_box(root, "leaves1", float3(0, 5.0, 0), float3(4.6, 2.4, 4.6), float4(0.22, 0.60, 0.22, 1.0))
    mk_box(root, "leaves2", float3(0, 6.8, 0), float3(3.2, 2.0, 3.2), float4(0.26, 0.68, 0.26, 1.0))
    return root
}

def public build_cloud(parent : NodeId; pos : float3; scale : float = 1.0) : NodeId {
    let root = create_node(NodeData(name = "cloud", parent = parent, position = pos, scale = float3(scale)))
    let col = float4(1, 1, 1, 1)
    mk_box(root, "c1", float3(0, 0, 0), float3(14, 3, 6), col)
    mk_box(root, "c2", float3(-3, 1.8, 0), float3(7, 3, 5), col)
    mk_box(root, "c3", float3(4, 1.5, 0.5), float3(6, 2.5, 5), col)
    return root
}
