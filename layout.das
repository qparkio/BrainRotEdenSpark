require engine.core
require constants

// Pure map math shared by client and server. No scene side effects.
//
// Top view (x right, z up). The red conveyor carpet runs along z in the middle,
// four base halls stand on each side with their open front facing the carpet:
//
//   base0..3 (x<0)   |   carpet   |   base4..7 (x>0)
//
// A base is a three storey hall. Inside, a red aisle runs from the gate (front) to the back wall,
// pedestals stand on both sides of the aisle with a green collect pad in front of each.
// Floor 1 holds slots 0..9, floor 2 slots 10..17 (rebirth 2), floor 3 slots 18..21 (rebirth 10).


let public {
    SLOT_SIDE_OFFSET = 14.0 // pedestal distance from the aisle
    PAD_SIDE_OFFSET = 8.6 // collect pad distance from the aisle
    FLOOR_COUNT = 3
    FLOOR_SLAB_T = 1.2
}

// slot index -> floor (0..2)
def public slot_floor(slot : int) : int {
    return slot < 10 ? 0 : (slot < 18 ? 1 : 2)
}

def public floor_y(floor : int) : float {
    return float(floor) * FLOOR_H
}

// +1: the +z side of the aisle, -1: the -z side
def public slot_side(slot : int) : float {
    var side = 1.0
    if (slot < 10) {
        side = slot < 5 ? 1.0 : -1.0
    } elif (slot < 18) {
        side = (slot - 10) < 4 ? 1.0 : -1.0
    } else {
        side = (slot - 18) < 2 ? 1.0 : -1.0
    }
    return side
}

// distance of the slot from the gate along the aisle
def public slot_depth(slot : int) : float {
    var depth = 0.0
    if (slot < 10) {
        depth = 8.0 + float(slot % 5) * 7.5
    } elif (slot < 18) {
        depth = 9.0 + float((slot - 10) % 4) * 8.0
    } else {
        depth = 14.0 + float((slot - 18) % 2) * 12.0
    }
    return depth
}

// direction pointing from the base toward the carpet (+1 for left bases)
def public base_dir(baseIndex : int) : float {
    return baseIndex < 4 ? 1.0 : -1.0
}

def public base_center(baseIndex : int) : float3 {
    let side = baseIndex < 4 ? -1.0 : 1.0
    let row = baseIndex % 4
    let z = (float(row) - 1.5) * BASE_Z_STEP
    return float3(side * BASE_CENTER_X, 0.0, z)
}

// point on the base's central axis, `depth` studs behind the gate (0 = at the gate)
def public base_axis_pos(baseIndex : int; depth : float) : float3 {
    let c = base_center(baseIndex)
    return float3(c.x + base_dir(baseIndex) * (BASE_HALF_X - depth), 0.0, c.z)
}

def public gate_pos(baseIndex : int) : float3 {
    return base_axis_pos(baseIndex, 0.0)
}

def public spawn_pos(baseIndex : int) : float3 {
    var p = base_axis_pos(baseIndex, 9.0)
    p.y = 3.0
    return p
}

def public slot_pos(baseIndex : int; slot : int) : float3 {
    var p = base_axis_pos(baseIndex, slot_depth(slot))
    p.z += slot_side(slot) * SLOT_SIDE_OFFSET
    p.y = floor_y(slot_floor(slot))
    return p
}

def public pad_pos(baseIndex : int; slot : int) : float3 {
    var p = base_axis_pos(baseIndex, slot_depth(slot))
    p.z += slot_side(slot) * PAD_SIDE_OFFSET
    p.y = floor_y(slot_floor(slot))
    return p
}

// yaw that makes a creature on `slot` face the aisle
def public slot_yaw(slot : int) : float {
    return slot_side(slot) > 0.0 ? PI : 0.0
}

def public in_base(baseIndex : int; p : float3; margin : float = 0.0) : bool {
    let c = base_center(baseIndex)
    return abs(p.x - c.x) <= BASE_HALF_X + margin && abs(p.z - c.z) <= BASE_HALF_Z + margin
}

def public conveyor_start : float3 {
    return float3(0.0, 0.0, -CONVEYOR_HALF_LENGTH)
}

def public conveyor_end : float3 {
    return float3(0.0, 0.0, CONVEYOR_HALF_LENGTH)
}

def public flat_distance(a, b : float3) : float {
    return length(float3(a.x - b.x, 0.0, a.z - b.z))
}

// rebirths needed before floor 2 / 3 become available
def public floor_required_rebirths(floor : int) : int {
    return floor == 0 ? 0 : (floor == 1 ? 2 : 10)
}


// ---------------- plaza stations along the carpet ----------------

let public {
    STATION_SHOP = 0
    STATION_FUSE = 1
    STATION_COUNT = 2
    STATION_RANGE = 9.0
    STATION_NAMES = fixed_array("Shop", "Fuse Machine")
}

// the shop stands left of the carpet, the fuse machine right of it
def public station_pos(i : int) : float3 {
    return float3(i == 0 ? -15.0 : 15.0, 0.0, -6.0)
}

// +1 when the customer side faces +x
def public station_facing(i : int) : float {
    return i == 0 ? 1.0 : -1.0
}

// ---------------- base pads and the outside staircase ----------------

let public {
    EXT_STAIR_LAT = -23.8 // the staircase climbs along the outside of the -z wall
    DOOR_DEPTH = 34.0 // where the upper-floor door sits in the side wall
    PAD_DEPTH = 13.0
}

def public lock_pad_pos(baseIndex : int) : float3 {
    var p = base_axis_pos(baseIndex, PAD_DEPTH)
    p.z += -3.4
    return p
}

def public upgrade_pad_pos(baseIndex : int) : float3 {
    var p = base_axis_pos(baseIndex, PAD_DEPTH)
    p.z += 3.4
    return p
}