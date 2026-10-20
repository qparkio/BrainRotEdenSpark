require engine.core
require constants
require layout
require brainrot_data
require skin_data
require models
require game_state
require ui_assets


// Local portal presentation; the server owns creature spawning and movement.
class PortalSurface : Component {
    private t : float = 0.0

    def override on_update {
        t += get_delta_time()
        nodeId?.Mesh.uvRect = float4(0.0, t * 0.025, 1.0, 1.0)
        let brightness = 0.85 + sin(t * 1.6) * 0.15
        nodeId?.Mesh.color = float4(brightness, brightness, brightness, 1.0)
    }
}


// Gently bobs/rotates a node (index orb, lamps).
class Bobber : Component {
    baseY : float = 0.0
    amplitude : float = 0.3
    speed : float = 2.0
    spin : float = 0.0
    private t : float = 0.0

    def override on_initialize {
        baseY = nodeId.localPosition.y
        t = random_float() * 6.0
    }

    def override on_update {
        t += get_delta_time()
        var p = nodeId.localPosition
        p.y = baseY + sin(t * speed) * amplitude
        nodeId.localPosition = p
        if (spin != 0.0) {
            nodeId.localRotation = quat4(0.0, t * spin, 0.0)
        }
    }
}


////////////////////////////////////////////////////////////////////////////////
// labels: every world text is registered so it can be hidden behind walls
////////////////////////////////////////////////////////////////////////////////

var private {
    cullList : array<NodeId>
    cullHidden : array<bool>
    cullCursor : int = 0
}

def public clear_label_registry {
    cullList |> clear()
    cullHidden |> clear()
    cullCursor = 0
}

def public register_label(n : NodeId) {
    cullList |> push(n)
    cullHidden |> push(false)
}

def public label3d(parent : NodeId; text : string; pos : float3; size : float; color : float4; maxWidth : float = -1.0) : NodeId {
    let node = create_node(NodeData(name = "label", parent = parent, position = pos))
    add_component(node, new Text3D(text = text, color = color, fontId = game_font(), fontSize = size, effect = TextEffect.Outline, effectColor = COL_BLACK, effectThickness = 4.0))
    if (maxWidth > 0.0) {
        node?.Text3D.size = float2(maxWidth, size * 1.4)
        node?.Text3D.fontAutoSize = float2(14.0, size)
        node?.Text3D.wordWrapping = false
    }
    register_label(node)
    return node
}

// World-fixed text (a UI canvas lying in the scene): unlike Text3D it does not turn with the camera.
// Returns the UIText node, so callers update `.UIText.text` / `.UIText.color`.
def public label_flat(parent : NodeId; str : string; pos : float3; yaw : float; fontSize : float; color : float4; maxWidth : float = -1.0) : NodeId {
    // the canvas frame overwrites its own x/y position, so the placement lives on a holder node
    let holder = create_node(NodeData(name = "flatHolder", parent = parent, position = pos, rotation = quat4(0.0, yaw, 0.0)))
    let node = create_node(NodeData(name = "flat", parent = holder, scale = float3(FLAT_SCALE)))
    add_component(node, new UICanvas(renderMode = RenderMode.WorldSpace, screenMode = ScreenMode.Custom))
    node?.UIFrame.size = float2(2.0, 2.0) // tiny frame: the text is laid out from the frame corner, so keep it at the anchor point
    let tn = create_node(NodeData(name = "flatText", parent = node))
    add_component(tn, new UIText(text = str, color = color, fontId = game_font(), fontSize = fontSize, effect = TextEffect.Outline, effectColor = COL_BLACK, effectThickness = max(2.0, fontSize * 0.06), wordWrapping = false, autoResizeFrame = true))
    if (maxWidth > 0.0) {
        tn?.UIText.size = float2(maxWidth / FLAT_SCALE, fontSize * 1.5)
        tn?.UIText.fontAutoSize = float2(12.0, fontSize)
        tn?.UIText.autoResizeFrame = false
    }
    return tn
}

// yaw that makes a flat label face along the horizontal direction (dx, dz)
def public flat_yaw(dx, dz : float) : float {
    return atan2(dx, dz) + FLAT_YAW_FIX
}

def public cull_stats : string {
    var hidden = 0
    for (h in cullHidden) {
        if (h) {
            hidden++
        }
    }
    return "labels={length(cullList)} hidden={hidden} cursor={cullCursor}"
}

// Text3D is drawn over everything, so check line of sight to a few labels per frame and
// squash the ones that sit behind a wall.
def public update_label_culling(eye : float3) {
    let n = length(cullList)
    if (n == 0) {
        return
    }
    let budget = min(24, n)
    for (k in range(budget)) {
        if (length(cullList) == 0) {
            return
        }
        cullCursor = (cullCursor + 1) % length(cullList)
        let lbl = cullList[cullCursor]
        if (!lbl.isAlive) {
            cullList |> erase(cullCursor)
            cullHidden |> erase(cullCursor)
            if (length(cullList) == 0) {
                return
            }
            cullCursor = cullCursor % length(cullList)
            continue
        }
        let target = lbl.worldPosition
        let to = target - eye
        let dist = length(to)
        var blocked = dist > 120.0
        if (!blocked && dist > 3.0) {
            let dir = to / dist
            trace(RayCast(ray = Ray(origin = eye + dir * 1.0, direction = dir), maxDistance = dist - 1.6)) $(hit) {
                blocked = true
            }
        }
        if (blocked != cullHidden[cullCursor]) {
            cullHidden[cullCursor] = blocked
            lbl.localScale = blocked ? float3(0.0001) : float3(1.0)
        }
    }
}


////////////////////////////////////////////////////////////////////////////////
// materials: Roblox studs and paving (studs only on top surfaces)
////////////////////////////////////////////////////////////////////////////////

var private {
    studMat : MaterialId
    tileMat : MaterialId
    glassMat : MaterialId
    plasticMat : MaterialId
    glowMat : MaterialId
    portalMat : MaterialId
    edenLogoMat : MaterialId
}

def public load_world_materials {
    studMat = request_material("assets/materials/studs.material")
    tileMat = request_material("assets/materials/tiles.material")
    glassMat = request_material("assets/materials/glass.material")
    plasticMat = request_material("assets/materials/plastic.material")
    glowMat = request_material("assets/materials/glow.material")
    portalMat = request_material("assets/materials/portal.material")
    basePlasticMaterial = plasticMat
    baseStudMaterial = studMat
    edenSurfaceMaterial = request_material("assets/materials/eden_surface.material")
    edenLogoMat = request_material("assets/materials/eden_logo.material")
}

// A plain colored box whose top face is covered by a stud / paving decal (one repeat of the
// texture spans `tile` world units). The sides stay smooth like Roblox "smooth plastic".
def public mk_studs(parent : NodeId; name : string; pos, size : float3; color : float4; kind : int = 0; tile : float = 4.0; solid : bool = false) : NodeId {
    let node = mk_box(parent, name, pos, size, color, solid)
    let decal = create_node(NodeData(name = "studs", parent = node, position = float3(0.0, 0.5 + 0.03 / max(size.y, 0.05), 0.0)))
    add_component(decal, new Mesh(meshId = PLANE_MESH_ID, materialId = kind == 1 ? tileMat : studMat, color = color))
    decal?.Mesh.uvRect = float4(0.0, 0.0, size.x / tile, size.z / tile)
    return node
}


let private {
    FLAT_SCALE = 0.04
    FLAT_YAW_FIX = 3.14159265
    COL_CONCRETE = float4(0.60, 0.62, 0.67, 1.0)
    COL_CONCRETE_DARK = float4(0.40, 0.42, 0.47, 1.0)
    COL_NAVY = float4(0.09, 0.15, 0.27, 1.0)
    COL_TEAL = float4(0.07, 0.27, 0.24, 1.0)
    COL_WOOD = float4(0.80, 0.47, 0.22, 1.0)
    COL_WOOD_DARK = float4(0.50, 0.28, 0.12, 1.0)
    COL_WHITE_FRAME = float4(0.96, 0.97, 1.0, 1.0)
    COL_PAD = float4(0.20, 0.85, 0.30, 1.0)
    COL_LASER = float4(1.0, 0.20, 0.14, 1.0)
    BUILD_H = 30.0 // two storeys
    WALL_T = 1.2
    HALL_HALF = 20.0 // inner half width of the hall
}

////////////////////////////////////////////////////////////////////////////////
// the red carpet meets portals recessed into the arena's end walls
////////////////////////////////////////////////////////////////////////////////

def private build_portal(root : NodeId; endSide : float) {
    let z = endSide * CONVEYOR_HALF_LENGTH
    let portal = create_node(NodeData(name = endSide < 0.0 ? "spawnPortal" : "exitPortal", parent = root, position = float3(0.0, 0.0, z)))
    let width = CONVEYOR_HALF_WIDTH * 2.0
    let frame = PORTAL_FRAME_WIDTH
    let frameCol = endSide < 0.0 ? float4(0.72, 0.35, 0.62, 1.0) : float4(0.20, 0.23, 0.30, 1.0)
    let rimCol = endSide < 0.0 ? float4(1.0, 0.48, 0.80, 1.0) : float4(0.45, 0.72, 1.0, 1.0)
    for (side in range(2)) {
        let x = (side == 0 ? -1.0 : 1.0) * (CONVEYOR_HALF_WIDTH + frame * 0.5)
        mk_box(portal, "portalPillar", float3(x, PORTAL_HEIGHT * 0.5, endSide), float3(frame, PORTAL_HEIGHT, 4.0), frameCol, true)
        let rim = mk_box(portal, "portalRim", float3((side == 0 ? -1.0 : 1.0) * (CONVEYOR_HALF_WIDTH + 0.12), PORTAL_HEIGHT * 0.5, -endSide * 1.05), float3(0.24, PORTAL_HEIGHT, 0.18), rimCol)
        rim?.Mesh.materialId = glowMat
    }
    mk_box(portal, "portalLintel", float3(0.0, PORTAL_HEIGHT + frame * 0.5, endSide), float3(width + frame * 2.0, frame, 4.0), frameCol, true)
    let topRim = mk_box(portal, "portalRimTop", float3(0.0, PORTAL_HEIGHT - 0.12, -endSide * 1.05), float3(width, 0.24, 0.18), rimCol)
    topRim?.Mesh.materialId = glowMat
    // A dark recess continues through the wall, so no grass gap sits behind the entrance.
    mk_box(portal, "portalBack", float3(0.0, PORTAL_HEIGHT * 0.5, endSide * 5.8), float3(width, PORTAL_HEIGHT, 0.4), float4(0.015, 0.012, 0.03, 1.0), true)
    mk_box(portal, "portalCeiling", float3(0.0, PORTAL_HEIGHT, endSide * 3.0), float3(width, 0.2, 6.0), frameCol)
    let surface = create_node(NodeData(name = "portalSurface", parent = portal, position = float3(0.0, PORTAL_HEIGHT * 0.5, endSide * 0.45), rotation = quat4(endSide * PI * 0.5, 0.0, 0.0), scale = float3(width, 1.0, PORTAL_HEIGHT)))
    add_component(surface, new Mesh(meshId = PLANE_MESH_ID, materialId = portalMat, visibility = MeshVisibility.VisibleInAnyCamera))
    add_component(surface, new PortalSurface())
    let blocker = create_node(NodeData(name = "portalBlocker", parent = portal, position = float3(0.0, PORTAL_HEIGHT * 0.5, endSide * 0.45), scale = float3(width, PORTAL_HEIGHT, 1.0)))
    add_component(blocker, new Collider(shape = box_shape()))
    mk_box(portal, "portalFloor", float3(0.0, -0.5, endSide * 3.0), float3(width, 1.0, 6.0), frameCol, true)
}


def private build_exit_boards(root : NodeId; z : float) {
    // Large wall boards beside the exit. Rows show the current room's live players.
    for (side in range(2)) {
        let sx = side == 0 ? -1.0 : 1.0
        let bx = sx * (CONVEYOR_HALF_WIDTH + 6.0 + WALL_BOARD_WIDTH * 0.5)
        let boardZ = CONVEYOR_HALF_LENGTH - 0.7
        mk_box(root, "boardFrame", float3(bx, 12.0, boardZ), float3(WALL_BOARD_WIDTH, WALL_BOARD_HEIGHT, 0.5), float4(0.45, 0.25, 0.12, 1.0))
        mk_box(root, "wallBoard", float3(bx, 12.0, boardZ - 0.4), float3(WALL_BOARD_WIDTH - 1.0, WALL_BOARD_HEIGHT - 1.0, 0.35), float4(0.025, 0.035, 0.035, 1.0))
        let yaw = flat_yaw(0.0, -1.0)
        label_flat(root, side == 0 ? "TOP CASH" : "TOP STEALS", float3(bx, 19.0, boardZ - 0.7), yaw, 76.0, float4(1.0, 0.9, 0.4, 1.0), WALL_BOARD_WIDTH - 3.0)
        label_flat(root, "THIS ROOM", float3(bx, 17.4, boardZ - 0.7), yaw, 30.0, float4(0.6, 0.7, 0.7, 1.0), WALL_BOARD_WIDTH - 3.0)
        for (i in range(MAX_PLAYERS)) {
            let row = label_flat(root, "", float3(bx, 15.5 - float(i) * WALL_BOARD_ROW_GAP, boardZ - 0.7), yaw, WALL_BOARD_FONT_SIZE, COL_WHITE, WALL_BOARD_WIDTH - 3.0)
            if (side == 0) {
                cashBoardRows[i] = row
            } else {
                stealsBoardRows[i] = row
            }
        }
    }
}

def private build_conveyor(root : NodeId) {
    let len = CONVEYOR_HALF_LENGTH * 2.0
    mk_studs(root, "conveyor", float3(0, 0.15, 0), float3(CONVEYOR_HALF_WIDTH * 2.0, 0.3, len + 10.0), COL_CONVEYOR, 0, 4.0)
    mk_studs(root, "edgeL", float3(-CONVEYOR_HALF_WIDTH - 0.4, 0.2, 0), float3(0.8, 0.4, len), COL_CONCRETE_DARK, 0, 4.0, true)
    mk_studs(root, "edgeR", float3(CONVEYOR_HALF_WIDTH + 0.4, 0.2, 0), float3(0.8, 0.4, len), COL_CONCRETE_DARK, 0, 4.0, true)
    build_portal(root, -1.0)
    build_portal(root, 1.0)
    build_exit_boards(root, CONVEYOR_HALF_LENGTH - 6.0)
}


////////////////////////////////////////////////////////////////////////////////
// bases
////////////////////////////////////////////////////////////////////////////////

// box placed in a base's own frame: `depth` studs behind the gate, `lat` along the gate line.
// size.x runs along the depth axis, size.z along lat.
def private bbox(root : NodeId; bi : int; name : string; depth, lat, y : float; size : float3; color : float4; solid : bool = false) : NodeId {
    let c = base_center(bi)
    let d = base_dir(bi)
    let node = mk_box(root, name, float3(c.x + d * (BASE_HALF_X - depth), y, c.z + lat), size, color, solid)
    node?.Mesh.materialId = plasticMat
    return node
}

def private bstuds(root : NodeId; bi : int; name : string; depth, lat, y : float; size : float3; color : float4; kind : int; tile : float; solid : bool = false) : NodeId {
    let c = base_center(bi)
    let d = base_dir(bi)
    return mk_studs(root, name, float3(c.x + d * (BASE_HALF_X - depth), y, c.z + lat), size, color, kind, tile, solid)
}

// an inclined bar between two points given in the base frame (depth, y) on lateral position `lat`
def private inclined(root : NodeId; bi : int; depth0, y0, depth1, y1, lat, thick, width : float; color : float4; visible, solid : bool) : NodeId {
    let c = base_center(bi)
    let d = base_dir(bi)
    let x0 = c.x + d * (BASE_HALF_X - depth0)
    let x1 = c.x + d * (BASE_HALF_X - depth1)
    let dx = x1 - x0
    let dy = y1 - y0
    let len = sqrt(dx * dx + dy * dy)
    let node = create_node(NodeData(name = "incl", parent = root, position = float3((x0 + x1) * 0.5, (y0 + y1) * 0.5, c.z + lat),
        rotation = quat4(0.0, 0.0, atan2(dy, dx)), scale = float3(len, thick, width)))
    if (visible) {
        add_component(node, new Mesh(meshId = CUBE_MESH_ID, color = color))
    }
    if (solid) {
        add_component(node, new Collider(shape = box_shape()))
    }
    return node
}

// The outside staircase: real stepped treads, an invisible ramp to walk on and a handrail.
def private build_stairs(root : NodeId; bi : int; var parts : BaseParts&) {
    let steps = 20
    let d0 = 3.0
    let d1 = DOOR_DEPTH
    let run = (d1 - d0) / float(steps)
    let top0 = 0.5
    let topEnd = floor_y(1) + 0.5
    let rise = (topEnd - top0) / float(steps)
    for (i in range(steps)) {
        let top = top0 + float(i + 1) * rise
        let col = i % 2 == 0 ? COL_CONCRETE : shade_col(COL_CONCRETE, 0.86)
        parts.floors |> push(bbox(root, bi, "step", d0 + (float(i) + 0.5) * run, EXT_STAIR_LAT, top * 0.5, float3(run, top, 5.2), col))
    }
    // the surface the character really walks on, just under the middle of the treads
    // (it starts below ground so there is no lip to bump into; surface = line + 0.3)
    let s0 = top0 + rise * 0.4
    let slope = (topEnd - s0) / (d1 - d0)
    inclined(root, bi, 0.0, s0 - slope * d0 - 0.3, d1, topEnd - 0.3, EXT_STAIR_LAT, 0.6, 5.2, COL_CONCRETE, false, true)
    // handrail on the open side with a post every few steps
    let railLat = EXT_STAIR_LAT - 2.5
    let railUp = 2.7
    parts.trims |> push(inclined(root, bi, d0, top0 + railUp, d1, topEnd + railUp, railLat, 0.4, 0.4, COL_CONCRETE_DARK, true, false))
    var i = 0
    while (i < steps) {
        let dep = d0 + (float(i) + 0.5) * run
        let top = top0 + float(i + 1) * rise
        let railY = top0 + (dep - d0) * (topEnd - top0) / (d1 - d0) + railUp
        parts.trims |> push(bbox(root, bi, "post", dep, railLat, (top + railY) * 0.5, float3(0.4, railY - top, 0.4), COL_CONCRETE_DARK))
        i += 4
    }
}

// Clear glass in an actual opening; opaque frames only cover the perimeter.
def private side_window(root : NodeId; bi : int; depth, lat, y : float) {
    let w = BASE_WINDOW_WIDTH
    let h = BASE_WINDOW_HEIGHT
    let frame = BASE_WINDOW_FRAME
    let inset = BASE_WINDOW_REVEAL
    for (side in range(2)) {
        let sign = side == 0 ? -1.0 : 1.0
        bbox(root, bi, "winFrameSide", depth + sign * (w + frame - inset) * 0.5, lat, y, float3(frame + inset, h + frame * 2.0, WALL_T + 0.4), COL_WHITE_FRAME)
        bbox(root, bi, "winFrameHorizontal", depth, lat, y + sign * (h + frame - inset) * 0.5, float3(w - inset * 2.0, frame + inset, WALL_T + 0.4), COL_WHITE_FRAME)
    }
    bbox(root, bi, "winMullion", depth, lat, y, float3(frame * 0.65, h - inset * 2.0, 0.18), COL_WHITE_FRAME)
    var position = base_axis_pos(bi, depth)
    position.y = y
    position.z += lat
    // One two-sided pane avoids blending the near-identical front/back faces of a thin cube.
    let glass = create_node(NodeData(name = "windowGlass", parent = root, position = position, rotation = quat4(PI * 0.5, 0.0, 0.0), scale = float3(w, 1.0, h)))
    add_component(glass, new Mesh(meshId = PLANE_MESH_ID, materialId = glassMat, color = COL_WINDOW_GLASS, visibility = MeshVisibility.VisibleInAnyCamera))
    let blocker = create_node(NodeData(name = "windowCollider", parent = root, position = position, scale = float3(w, h, WALL_T)))
    add_component(blocker, new Collider(shape = box_shape()))
}


def private window_wall(root : NodeId; bi, floor : int; lat, endDepth : float; var parts : BaseParts&) {
    let y0 = floor_y(floor)
    let low = BASE_WINDOW_Y - BASE_WINDOW_HEIGHT * 0.5
    let high = BASE_WINDOW_Y + BASE_WINDOW_HEIGHT * 0.5
    var cursor = 0.0
    for (k in range(3)) {
        let depth = BASE_WINDOW_START + float(k) * BASE_WINDOW_GAP
        let start = depth - BASE_WINDOW_WIDTH * 0.5
        let end = depth + BASE_WINDOW_WIDTH * 0.5
        parts.walls |> push(bbox(root, bi, "windowWallPier", (cursor + start) * 0.5, lat, y0 + FLOOR_H * 0.5, float3(start - cursor, FLOOR_H, WALL_T), SKINS[0].wall, true))
        parts.walls |> push(bbox(root, bi, "windowWallBelow", depth, lat, y0 + low * 0.5, float3(BASE_WINDOW_WIDTH, low, WALL_T), SKINS[0].wall, true))
        parts.walls |> push(bbox(root, bi, "windowWallAbove", depth, lat, y0 + (high + FLOOR_H) * 0.5, float3(BASE_WINDOW_WIDTH, FLOOR_H - high, WALL_T), SKINS[0].wall, true))
        side_window(root, bi, depth, lat, y0 + BASE_WINDOW_Y)
        cursor = end
    }
    parts.walls |> push(bbox(root, bi, "windowWallEnd", (cursor + endDepth) * 0.5, lat, y0 + FLOOR_H * 0.5, float3(endDepth - cursor, FLOOR_H, WALL_T), SKINS[0].wall, true))
}

def private build_pad(root : NodeId; pos : float3; color : float4) {
    mk_box(root, "padBase", float3(pos.x, 0.64, pos.z), float3(4.4, 0.16, 4.4), shade_col(color, 0.45))
    mk_box(root, "padTop", float3(pos.x, 0.74, pos.z), float3(3.6, 0.12, 3.6), color)
    mk_ball(root, "padGlow", float3(pos.x, 0.85, pos.z), float3(2.4, 0.2, 2.4), shade_col(color, 1.25))
}

def private shade_col(c : float4; k : float) : float4 {
    return float4(min(1.0, c.x * k), min(1.0, c.y * k), min(1.0, c.z * k), 1.0)
}

// Upper floors need barriers at both the stair door and the open front facade.
def private build_floor_gate(root : NodeId; name : string; pos : float3; yaw, width, height : float; var parts : BaseParts&) {
    let gate = create_node(NodeData(name = name, parent = root, position = pos, rotation = quat4(0.0, yaw, 0.0)))
    let halfWidth = width * 0.5
    var lat = -halfWidth + 0.5
    while (lat < halfWidth) {
        let laser = mk_box(gate, "laser", float3(0.0, height * 0.5, lat), float3(0.22, height, 0.22), COL_LASER_GLOW)
        laser?.Mesh.materialId = glowMat
        lat += 1.0
    }
    let rail = mk_box(gate, "laserMid", float3(0.0, height * 0.5, 0.0), float3(0.22, 0.22, width), COL_LASER_GLOW)
    rail?.Mesh.materialId = glowMat
    let blocker = create_node(NodeData(name = "floorGateBlocker", parent = gate,
        position = float3(0.0, height * 0.5, 0.0), scale = float3(WALL_T + 0.6, height, width)))
    add_component(blocker, new Collider(shape = box_shape()))
    parts.floorGates |> push(gate)
    parts.floorGateBlockers |> push(blocker)
    gate.isActive = false
}


// floors, windows and lights of one storey
def private build_storey(root : NodeId; bi : int; f : int; var parts : BaseParts&) {
    let hx = BASE_HALF_X
    let depthLen = hx * 2.0
    let sideX = HALL_HALF + 0.6
    let skin = SKINS[0]
    let y0 = floor_y(f)
    let frontInset = f == 0 ? 0.0 : BASE_FLOOR_FRONT_INSET
    let floorDepth = depthLen - frontInset - BASE_FLOOR_BACK_INSET
    let floorCenter = hx + (frontInset - BASE_FLOOR_BACK_INSET) * 0.5
    if (f == 0) {
        parts.floors |> push(bstuds(root, bi, "slab0", floorCenter, 0.0, 0.25, float3(floorDepth, 0.5, HALL_HALF * 2.0 + 2.0), skin.floorCol, 0, 4.0, true))
        parts.aisles |> push(bstuds(root, bi, "aisle0", floorCenter, 0.0, 0.52, float3(floorDepth, 0.06, 10.0), skin.aisle, 0, 4.0))
        parts.stands |> push(bbox(root, bi, "plateA0", floorCenter, -5.6, 0.56, float3(floorDepth, 0.12, 1.0), float4(0.16, 0.17, 0.20, 1.0)))
        parts.stands |> push(bbox(root, bi, "plateB0", floorCenter, 5.6, 0.56, float3(floorDepth, 0.12, 1.0), float4(0.16, 0.17, 0.20, 1.0)))
    } else {
        parts.floors |> push(bstuds(root, bi, "slab1", floorCenter, 0.0, y0 - 0.1, float3(floorDepth, 1.2, HALL_HALF * 2.0 + 2.0), skin.floorCol, 0, 4.0, true))
        parts.aisles |> push(bstuds(root, bi, "aisle1", floorCenter, 0.0, y0 + 0.52, float3(floorDepth, 0.06, 10.0), skin.aisle, 0, 4.0))
        parts.stands |> push(bbox(root, bi, "plateA1", floorCenter, -5.6, y0 + 0.56, float3(floorDepth, 0.12, 1.0), float4(0.16, 0.17, 0.20, 1.0)))
        parts.stands |> push(bbox(root, bi, "plateB1", floorCenter, 5.6, y0 + 0.56, float3(floorDepth, 0.12, 1.0), float4(0.16, 0.17, 0.20, 1.0)))
    }
    // ceiling lights: little white panels under the slab above
    let cy = y0 + FLOOR_H - 1.0
    for (a in range(5)) {
        for (b in range(3)) {
            bbox(root, bi, "light", 6.0 + float(a) * 8.5, (float(b) - 1.0) * 11.0, cy, float3(2.2, 0.25, 2.2), float4(1.0, 0.98, 0.88, 1.0))
        }
    }
    // walls of this storey (the door to the outside staircase is cut into the upper -z wall)
    let wh = FLOOR_H
    let wc = y0 + wh * 0.5
    parts.walls |> push(bbox(root, bi, "wallBack", depthLen - WALL_T * 0.5, 0.0, wc, float3(WALL_T, wh, HALL_HALF * 2.0 + 2.4), skin.wall, true))
    window_wall(root, bi, f, sideX, depthLen, parts)
    if (f == 0) {
        window_wall(root, bi, f, -sideX, depthLen, parts)
    } else {
        let doorLo = y0 + 0.5
        let doorHi = y0 + 8.0
        window_wall(root, bi, f, -sideX, DOOR_DEPTH, parts)
        parts.walls |> push(bbox(root, bi, "wallN_b", DOOR_DEPTH + 4.0, -sideX, (y0 + doorLo) * 0.5, float3(8.0, doorLo - y0, WALL_T), skin.wall, true))
        parts.walls |> push(bbox(root, bi, "wallN_c", DOOR_DEPTH + 4.0, -sideX, (doorHi + y0 + wh) * 0.5, float3(8.0, y0 + wh - doorHi, WALL_T), skin.wall, true))
        parts.walls |> push(bbox(root, bi, "wallN_d", (DOOR_DEPTH + 8.0 + depthLen) * 0.5, -sideX, wc, float3(depthLen - DOOR_DEPTH - 8.0, wh, WALL_T), skin.wall, true))
        let door = base_axis_pos(bi, DOOR_DEPTH + 4.0)
        build_floor_gate(root, "stairGate_{f}", float3(door.x, doorLo, door.z - sideX), PI * 0.5, 8.0, doorHi - doorLo, parts)
        let front = gate_pos(bi)
        build_floor_gate(root, "frontGate_{f}", float3(front.x - base_dir(bi), y0 + 0.5, front.z), 0.0, GATE_HALF_WIDTH * 2.0, FLOOR_H - 1.0, parts)
    }
    // gray facade pillars of this storey
    let fd = 1.5
    for (s in range(2)) {
        let lat = s == 0 ? -(GATE_HALF_WIDTH + 3.0) : (GATE_HALF_WIDTH + 3.0)
        parts.walls |> push(bbox(root, bi, "pillar", fd, lat, wc, float3(3.0, wh, 6.0), COL_CONCRETE, true))
        parts.walls |> push(bbox(root, bi, "pillarBand", fd - 1.55, lat, wc, float3(0.2, wh, 6.2), skin.wall))
    }
}

def private build_base(root : NodeId; bi : int) {
    let c = base_center(bi)
    let d = base_dir(bi)
    let baseRoot = create_node(NodeData(name = "base_{bi}", parent = root))
    let upper = create_node(NodeData(name = "upper_{bi}", parent = baseRoot))
    let trimColor = PLAYER_COLORS[bi % length(PLAYER_COLORS)]
    let skin = SKINS[0]
    let hx = BASE_HALF_X
    var parts : BaseParts
    let depthLen = hx * 2.0
    let fd = 1.5
    let gate = GATE_HALF_WIDTH
    let y1 = floor_y(1)

    // ---- ground storey: always there ----
    build_storey(baseRoot, bi, 0, parts)
    parts.walls |> push(bbox(baseRoot, bi, "lintel", fd, 0.0, 14.8, float3(3.0, 1.8, gate * 2.0), COL_CONCRETE, true))
    // flat roof of the single-storey base; the upgrade removes it and builds the storey above
    lowRoofs[bi] = bstuds(baseRoot, bi, "roofLow", hx, 0.0, y1 - 0.1, float3(depthLen + 2.0, 1.4, HALL_HALF * 2.0 + 6.0), COL_CONCRETE, 0, 4.0, true)
    parts.walls |> push(lowRoofs[bi])
    parts.trims |> push(bbox(baseRoot, bi, "roofEdgeLow", -1.23, 0.0, y1 + 0.2, float3(0.36, 0.5, HALL_HALF * 2.0 + 6.0), trimColor))

    // ---- upper storey: appears after the base upgrade ----
    build_storey(upper, bi, 1, parts)
    build_stairs(upper, bi, parts)
    let returnLat = EXT_STAIR_LAT - STAIR_WIDTH
    let landingLat = EXT_STAIR_LAT - STAIR_WIDTH * 0.5
    parts.floors |> push(bstuds(upper, bi, "landing", DOOR_DEPTH + 4.0, landingLat, y1 - 0.1, float3(8.0, 1.2, STAIR_WIDTH * 2.0), COL_CONCRETE, 0, 4.0, true))
    parts.trims |> push(bbox(upper, bi, "landingRail", DOOR_DEPTH + 4.0, returnLat - 2.5, y1 + 1.7, float3(8.0, 3.0, 0.4), COL_CONCRETE_DARK, true))
    parts.trims |> push(bbox(upper, bi, "landingEnd", DOOR_DEPTH + 7.8, landingLat, y1 + 1.7, float3(0.4, 3.0, STAIR_WIDTH * 2.0), COL_CONCRETE_DARK, true))
    // upper facade: recessed teal panel with a white-framed opening onto the interior
    parts.walls |> push(bbox(upper, bi, "teal1", fd, 0.0, 29.0, float3(2.6, 2.0, gate * 2.0), COL_TEAL))
    parts.walls |> push(bbox(upper, bi, "teal2", fd, -gate + 1.0, 24.5, float3(2.6, 10.0, 2.0), COL_TEAL))
    parts.walls |> push(bbox(upper, bi, "teal3", fd, gate - 1.0, 24.5, float3(2.6, 10.0, 2.0), COL_TEAL))
    parts.trims |> push(bbox(upper, bi, "frameTop", fd + 0.2, 0.0, 28.2, float3(0.6, 0.7, gate * 2.0 - 3.0), COL_WHITE_FRAME))
    parts.trims |> push(bbox(upper, bi, "frameL", fd + 0.2, -gate + 2.0, 24.0, float3(0.6, 8.4, 0.7), COL_WHITE_FRAME))
    parts.trims |> push(bbox(upper, bi, "frameR", fd + 0.2, gate - 2.0, 24.0, float3(0.6, 8.4, 0.7), COL_WHITE_FRAME))
    secondRoofs[bi] = bstuds(upper, bi, "roof", hx, 0.0, BUILD_H + 0.8, float3(depthLen + 2.0, 1.6, HALL_HALF * 2.0 + 6.0), COL_CONCRETE, 0, 4.0, true)
    parts.walls |> push(secondRoofs[bi])
    parts.trims |> push(bbox(upper, bi, "roofEdge", -1.23, 0.0, BUILD_H + 1.0, float3(0.36, 0.5, HALL_HALF * 2.0 + 6.0), trimColor))
    let third = create_node(NodeData(name="third_{bi}",parent=upper))
    thirdRoots[bi] = third
    build_storey(third,bi,2,parts)
    parts.walls |> push(bstuds(third,bi,"roof3",hx,0.0,45.8,float3(depthLen+2.0,1.6,HALL_HALF*2.0+6.0),COL_CONCRETE,0,4.0,true))
    // A return flight starts at the second-floor landing, then a balcony reaches the third-floor door.
    let stairStart = DOOR_DEPTH
    let stairEnd = 3.0
    inclined(third,bi,stairStart,15.4,stairEnd,30.4,returnLat,0.6,STAIR_WIDTH,COL_CONCRETE,false,true)
    for (i in range(20)) {
        let dep = stairStart+(stairEnd-stairStart)*(float(i)+.5)/20.0
        let y = 15.5+15.0*(float(i)+1.0)/20.0
        parts.floors |> push(bbox(third,bi,"step3",dep,returnLat,y-.16,float3(1.6,.32,STAIR_WIDTH),COL_CONCRETE))
    }
    inclined(third,bi,stairStart,18.1,stairEnd,33.1,returnLat-2.5,.4,.4,COL_CONCRETE_DARK,true,false)
    // The balcony returns above the lower flight, leaving headroom over the upper flight.
    parts.floors |> push(bstuds(third,bi,"balcony3",18.5,EXT_STAIR_LAT,29.9,float3(31.0,1.2,STAIR_WIDTH),COL_CONCRETE,0,4.0,true))
    parts.floors |> push(bstuds(third,bi,"balcony3Front",1.5,EXT_STAIR_LAT-2.6,29.9,float3(3.0,1.2,10.4),COL_CONCRETE,0,4.0,true))
    parts.floors |> push(bstuds(third,bi,"balcony3Back",38.0,EXT_STAIR_LAT-2.6,29.9,float3(8.0,1.2,10.4),COL_CONCRETE,0,4.0,true))
    parts.trims |> push(bbox(third,bi,"balcony3Rail",20.0,EXT_STAIR_LAT-7.7,31.7,float3(39.0,3.0,.4),COL_CONCRETE_DARK,true))
    parts.walls |> push(bbox(third,bi,"facade3",fd,0.0,44.2,float3(2.6,1.6,gate*2.0),COL_TEAL))
    third.isActive = false
    upper.isActive = false
    upperRoots[bi] = upper

    // solid wall behind the nameplate, standing on the low roof (the upper storey continues above it)
    parts.walls |> push(bbox(baseRoot, bi, "signBack", 1.15, 0.0, 17.6, float3(2.0, 4.4, gate * 2.0 + 2.0), skin.wall, true))

    // wooden nameplate with a darker border
    let signD = -0.6
    bbox(baseRoot, bi, "signBoard", signD, 0.0, 17.6, float3(0.9, 4.2, gate * 2.0 + 2.0), COL_WOOD)
    parts.trims |> push(bbox(baseRoot, bi, "signBorderTop", signD - 0.2, 0.0, 19.75, float3(0.6, 0.5, gate * 2.0 + 2.4), COL_WOOD_DARK))
    parts.trims |> push(bbox(baseRoot, bi, "signBorderBot", signD - 0.2, 0.0, 15.45, float3(0.6, 0.5, gate * 2.0 + 2.4), COL_WOOD_DARK))
    parts.trims |> push(bbox(baseRoot, bi, "signBorderL", signD - 0.2, -gate - 1.0, 17.6, float3(0.6, 3.8, 0.5), COL_WOOD_DARK))
    parts.trims |> push(bbox(baseRoot, bi, "signBorderR", signD - 0.2, gate + 1.0, 17.6, float3(0.6, 3.8, 0.5), COL_WOOD_DARK))
    // the name is painted flat on the board: it does not turn with the camera
    let signX = c.x + d * (hx + 1.15)
    let outYaw = flat_yaw(d, 0.0)
    baseSigns[bi] = label_flat(baseRoot, "Free Base", float3(signX, 18.2, c.z), outYaw, 52.0, COL_WHITE, 29.0)
    baseLockTexts[bi] = label_flat(baseRoot, "", float3(signX, 16.3, c.z), outYaw, 30.0, float4(0.4, 1.0, 0.5, 1.0), 29.0)

    // ---- laser gate: many thin vertical bars between the pillars (shown while the base is locked) ----
    let gateNode = create_node(NodeData(name = "laserGate", parent = baseRoot, position = float3(c.x + d * (hx - 1.0), 0.0, c.z)))
    var lat = -gate + 0.8
    while (lat < gate) {
        let laser = mk_box(gateNode, "laser", float3(0, 6.7, lat), float3(0.35, 12.4, 0.35), COL_LASER_GLOW)
        laser?.Mesh.materialId = glowMat
        mk_box(gateNode, "laserBase", float3(0, 0.45, lat), float3(0.8, 0.9, 0.8), float4(0.12, 0.12, 0.14, 1.0))
        lat += 1.7
    }
    mk_box(gateNode, "laserRail", float3(0, 13.1, 0), float3(0.7, 0.5, gate * 2.0), float4(0.12, 0.12, 0.14, 1.0))
    let laserMid = mk_box(gateNode, "laserMid", float3(0, 6.0, 0), float3(0.4, 0.3, gate * 2.0), COL_LASER_GLOW)
    laserMid?.Mesh.materialId = glowMat
    for (i in range(3)) {
        let light = create_node(NodeData(name = "laserLight", parent = gateNode, position = float3(0.0, 3.8, (float(i) - 1.0) * gate * 0.65)))
        add_component(light, new PointLight(color = float3(1.0, 0.035, 0.015), intensity = LASER_LIGHT_INTENSITY, radius = LASER_LIGHT_RADIUS, castShadows = false))
    }
    // Collision geometry is invisible by construction; opaque materials ignore mesh alpha.
    gateBlockers[bi] = create_node(NodeData(name = "blocker", parent = gateNode, position = float3(0, 6.5, 0), scale = float3(1.5, 13.0, gate * 2.0)))
    add_component(gateBlockers[bi], new Collider(shape = box_shape()))
    gateBlockers[bi].isActive = false
    gateNode.isActive = false
    gateRoots[bi] = gateNode

    // ---- paved forecourt with a green entry strip ----
    parts.floors |> push(bstuds(baseRoot, bi, "forecourt", -8.0, 0.0, 0.1, float3(16.0, 0.2, HALL_HALF * 2.0 + 6.0), float4(0.82, 0.84, 0.88, 1.0), 1, 8.0))
    bstuds(baseRoot, bi, "entryStrip", -2.5, 0.0, 0.3, float3(3.5, 0.2, gate * 1.2), COL_PAD, 0, 4.0)
    // "cash multi" board just inside the entrance, facing the street
    baseMultiTexts[bi] = label3d(baseRoot, "CASH MULTI: x1", float3(c.x + d * (hx - 3.5), 11.0, c.z), 36.0, COL_WHITE, 360.0)

    // ---- the two pads on the carpet: lock the base / upgrade the base ----
    let lp = lock_pad_pos(bi)
    let up = upgrade_pad_pos(bi)
    build_pad(baseRoot, lp, float4(1.0, 0.85, 0.2, 1.0))
    build_pad(baseRoot, up, float4(0.7, 0.4, 1.0, 1.0))
    lockPadTexts[bi] = label3d(baseRoot, "Lock Base", float3(lp.x, 4.0, lp.z), 62.0, COL_WHITE)
    upgradePadTexts[bi] = label3d(baseRoot, "Upgrade Base", float3(up.x, 4.0, up.z), 62.0, COL_WHITE)

    // ---- pedestals (dark plate + glowing disc) and green collect pads ----
    for (s in range(SLOTS_PER_BASE)) {
        let sp = slot_pos(bi, s)
        let pp = pad_pos(bi, s)
        let idx = bi * SLOTS_PER_BASE + s
        let stand = mk_box(baseRoot, "stand_{s}", float3(sp.x, sp.y + 0.9, sp.z), float3(5.6, 0.8, 5.6), skin.accent)
        mk_box(stand, "plate", float3(0, 0.55, 0), float3(0.78, 0.12, 0.78), float4(0.62, 0.64, 0.7, 1.0))
        parts.trims |> push(mk_box(stand, "ring", float3(0, 0.62, 0), float3(0.56, 0.1, 0.56), trimColor))
        mk_box(stand, "disc", float3(0, 0.7, 0), float3(0.42, 0.1, 0.42), float4(0.75, 0.92, 1.0, 1.0))
        parts.stands |> push(stand)
        standNodes[idx] = stand
        standTexts[idx] = label3d(baseRoot, "Empty", float3(sp.x, sp.y + 3.4, sp.z), 36.0, float4(1, 1, 1, 0.6))
        let pad = mk_box(baseRoot, "pad_{s}", float3(pp.x, pp.y + 0.62, pp.z), float3(4.6, 0.22, 4.6), COL_PAD)
        padNodes[idx] = pad
        padTitles[idx] = label3d(baseRoot, "", float3(pp.x, pp.y + 4.2, pp.z), 50.0, COL_WHITE)
        padTexts[idx] = label3d(baseRoot, "", float3(pp.x, pp.y + 2.5, pp.z), 56.0, float4(0.35, 1.0, 0.4, 1.0))
    }
    parts.edenDetail = create_node(NodeData(name = "edenDetail_{bi}", parent = baseRoot))
    for (side in range(2)) {
        let edenLat = side == 0 ? -HALL_HALF + 0.7 : HALL_HALF - 0.7
        let color = side == 0 ? COL_EDEN_CORAL : COL_EDEN_CYAN
        let light = bbox(parts.edenDetail, bi, "edenLight", hx, edenLat, 12.2, float3(depthLen - 4.0, 0.18, 0.18), color)
        light?.Mesh.materialId = glowMat
    }
    let badge = base_axis_pos(bi, depthLen - 1.3)
    let logo = create_node(NodeData(name = "edenLogo", parent = parts.edenDetail, position = float3(badge.x, 10.8, badge.z), rotation = quat4(PI * 0.5, d * PI * 0.5, 0.0), scale = float3(6.2, 1.0, 6.2)))
    add_component(logo, new Mesh(meshId = PLANE_MESH_ID, materialId = edenLogoMat, visibility = MeshVisibility.VisibleInAnyCamera))
    logo?.Mesh.uvRect = float4(1.0, 0.0, -1.0, 1.0)
    parts.edenDetail.isActive = false
    baseParts |> emplace(parts)
}


////////////////////////////////////////////////////////////////////////////////
// plaza: the single wooden Shop stall (plus the fuse machine) beside the carpet
////////////////////////////////////////////////////////////////////////////////

def private build_stall(root : NodeId; station : int; signText : string; signColor, awningA, awningB : float4) {
    let p = station_pos(station)
    let f = station_facing(station) // +1: customers stand on the +x side
    let yaw = f > 0.0 ? PI * 0.5 : -PI * 0.5
    let stall = create_node(NodeData(name = "stall_{station}", parent = root, position = p))
    let wood = float4(0.45, 0.25, 0.14, 1.0)
    let slab = float4(0.62, 0.64, 0.68, 1.0)
    for (sx in range(2)) {
        for (sz in range(2)) {
            mk_box(stall, "post", float3(f * (sx == 0 ? -3.2 : 3.4), 4.0, sz == 0 ? -5.2 : 5.2), float3(0.9, 8.0, 0.9), wood, true)
        }
    }
    mk_box(stall, "beamBack", float3(f * -3.2, 7.4, 0), float3(0.7, 0.7, 11.0), wood)
    mk_box(stall, "beamFront", float3(f * 3.4, 7.4, 0), float3(0.7, 0.7, 11.0), wood)
    mk_box(stall, "railLow", float3(f * 3.4, 2.0, 0), float3(0.5, 0.5, 10.6), wood)
    mk_box(stall, "railMid", float3(f * 3.4, 3.6, 0), float3(0.5, 0.5, 10.6), wood)
    mk_box(stall, "counter", float3(f * 3.4, 4.5, 0), float3(1.8, 0.7, 11.6), slab, true)
    mk_box(stall, "backBoard", float3(f * -3.2, 3.5, 0), float3(0.5, 6.0, 10.4), float4(0.55, 0.32, 0.18, 1.0), true)
    for (i in range(10)) {
        let z = -5.0 + float(i)
        let col = (i % 2 == 0) ? awningA : awningB
        mk_box(stall, "awning{i}", float3(0.0, 8.3, z), float3(8.0, 0.4, 1.0), col)
        mk_box(stall, "scallop{i}", float3(f * 4.1, 7.7, z), float3(0.4, 1.0, 1.0), col)
        mk_box(stall, "scallopB{i}", float3(f * -4.1, 8.0, z), float3(0.4, 0.7, 1.0), col)
    }
    let vendor = build_character(stall, float4(0.45, 0.28, 0.16, 1.0))
    vendor.root.localPosition = float3(f * 0.2, 0.0, 0.0)
    vendor.root.localRotation = quat4(0.0, yaw, 0.0)
    mk_box(vendor.head, "hatBrim", float3(0, 0.75, 0), float3(2.4, 0.15, 2.4), float4(0.9, 0.78, 0.45, 1.0))
    mk_box(vendor.head, "hatTop", float3(0, 1.0, 0), float3(1.3, 0.5, 1.3), float4(0.9, 0.78, 0.45, 1.0))
    mk_box(vendor.head, "hatBand", float3(0, 0.82, 0), float3(1.4, 0.2, 1.4), float4(0.2, 0.3, 0.6, 1.0))
    label3d(stall, signText, float3(f * 2.0, 12.4, 0), 110.0, signColor)
}

def private build_fuse_machine(root : NodeId; station : int) {
    let p = station_pos(station)
    let f = station_facing(station)
    let m = create_node(NodeData(name = "machine_{station}", parent = root, position = p))
    mk_box(m, "base", float3(0, 1.0, 0), float3(8.0, 2.0, 7.0), float4(0.22, 0.24, 0.3, 1.0), true)
    mk_box(m, "body", float3(f * -1.0, 5.0, 0), float3(5.0, 6.0, 5.6), float4(0.32, 0.36, 0.46, 1.0), true)
    mk_box(m, "screen", float3(f * 1.55, 5.4, 0), float3(0.3, 3.2, 4.2), float4(0.2, 0.95, 0.85, 1.0))
    for (i in range(3)) {
        mk_ball(m, "tube{i}", float3(f * 2.0, 3.4 + float(i) * 1.2, -1.8 + float(i) * 1.8), float3(1.0), PLAYER_COLORS[(i * 3) % length(PLAYER_COLORS)])
    }
    mk_box(m, "chimney", float3(f * -1.0, 9.4, 0), float3(1.6, 2.4, 1.6), float4(0.4, 0.42, 0.5, 1.0))
    mk_ball(m, "glow", float3(f * -1.0, 11.2, 0), float3(2.0), float4(0.8, 0.4, 1.0, 1.0))
    label3d(m, "Craft Machine", float3(f * 0.4, 14.0, 0), 80.0, float4(0.85, 0.55, 1.0, 1.0))
}

def private build_plaza(root : NodeId) {
    // paved square around the shop and the machine
    mk_studs(root, "plazaPaving", float3(0, 0.08, -6.0), float3(46.0, 0.16, 30.0), float4(0.78, 0.8, 0.84, 1.0), 1, 8.0)
    build_stall(root, STATION_SHOP, "Shop", float4(0.3, 1.0, 0.35, 1.0), float4(0.15, 0.4, 0.85, 1.0), float4(0.97, 0.97, 0.97, 1.0))
    build_fuse_machine(root, STATION_FUSE)
}

def private build_bench(root : NodeId; pos : float3; yaw : float) {
    let b = create_node(NodeData(name = "bench", parent = root, position = pos, rotation = quat4(0.0, yaw, 0.0)))
    mk_box(b, "seat", float3(0, 1.4, 0), float3(5.0, 0.4, 1.6), float4(0.6, 0.36, 0.18, 1.0), true)
    mk_box(b, "back", float3(0, 2.4, -0.7), float3(5.0, 1.6, 0.3), float4(0.55, 0.32, 0.16, 1.0))
    mk_box(b, "legL", float3(-2.1, 0.7, 0), float3(0.4, 1.4, 1.4), float4(0.3, 0.3, 0.35, 1.0))
    mk_box(b, "legR", float3(2.1, 0.7, 0), float3(0.4, 1.4, 1.4), float4(0.3, 0.3, 0.35, 1.0))
}

def private build_lamp(root : NodeId; pos : float3) {
    let l = create_node(NodeData(name = "lamp", parent = root, position = pos))
    mk_box(l, "pole", float3(0, 5.0, 0), float3(0.6, 10.0, 0.6), float4(0.25, 0.26, 0.3, 1.0), true)
    mk_box(l, "head", float3(0, 10.4, 0), float3(1.8, 0.9, 1.8), float4(0.25, 0.26, 0.3, 1.0))
    let bulb = mk_box(l, "bulb", float3(0, 9.9, 0), float3(1.3, 0.5, 1.3), float4(1.0, 0.95, 0.7, 1.0))
    bulb?.Mesh.materialId = glowMat
    stormLampBulbs |> push(bulb)
    let light = create_node(NodeData(name = "thunderLampLight", parent = l, position = float3(0.0, 9.5, 0.0)))
    light.isActive = false
    add_component(light, new PointLight(color = THUNDER_LIGHT_COLOR, radius = THUNDER_LAMP_RADIUS,
        intensity = 0.0, castShadows = false))
    stormLampLights |> push(light)
}

def public build_map() {
    mapRoot = create_node(NodeData(name = "map"))
    baseParts |> clear()
    clear_label_registry()
    stormGrassNodes |> clear()
    stormLampBulbs |> clear()
    stormLampLights |> clear()
    let hx = GROUND_HALF.x
    let hz = GROUND_HALF.y

    // studded grass ground with brown earth walls and a grass lip, like the original arena
    stormGround = mk_studs(mapRoot, "ground", float3(0, -1.0, 0), float3(hx * 2.0, 2.0, hz * 2.0), float4(0.28, 0.72, 0.22, 1.0), 0, 4.0, true)
    stormGrassNodes |> push(stormGround)
    let earth = float4(0.62, 0.34, 0.16, 1.0)
    let wallH = 26.0
    for (end in range(2)) {
        let z = (end == 0 ? -1.0 : 1.0) * (hz + 3.0)
        let outer = hx + 6.0
        let sideWidth = outer - CONVEYOR_HALF_WIDTH
        for (side in range(2)) {
            let x = (side == 0 ? -1.0 : 1.0) * (outer + CONVEYOR_HALF_WIDTH) * 0.5
            mk_box(mapRoot, "arenaEndWall", float3(x, wallH * 0.5, z), float3(sideWidth, wallH, 6.0), earth, true)
        }
        mk_box(mapRoot, "arenaPortalHeader", float3(0.0, (wallH + PORTAL_HEIGHT) * 0.5, z), float3(CONVEYOR_HALF_WIDTH * 2.0, wallH - PORTAL_HEIGHT, 6.0), earth, true)
    }
    mk_box(mapRoot, "wallW", float3(-hx - 3.0, wallH * 0.5, 0), float3(6.0, wallH, hz * 2.0), earth, true)
    mk_box(mapRoot, "wallE", float3(hx + 3.0, wallH * 0.5, 0), float3(6.0, wallH, hz * 2.0), earth, true)
    let lip = float4(0.28, 0.72, 0.22, 1.0)
    stormGrassNodes |> push(mk_studs(mapRoot, "lipN", float3(0, wallH + 0.4, -hz - 3.0), float3(hx * 2.0 + 12.0, 0.8, 6.4), lip, 0, 4.0))
    stormGrassNodes |> push(mk_studs(mapRoot, "lipS", float3(0, wallH + 0.4, hz + 3.0), float3(hx * 2.0 + 12.0, 0.8, 6.4), lip, 0, 4.0))
    stormGrassNodes |> push(mk_studs(mapRoot, "lipW", float3(-hx - 3.0, wallH + 0.4, 0), float3(6.4, 0.8, hz * 2.0), lip, 0, 4.0))
    stormGrassNodes |> push(mk_studs(mapRoot, "lipE", float3(hx + 3.0, wallH + 0.4, 0), float3(6.4, 0.8, hz * 2.0), lip, 0, 4.0))

    // Continuous player boundary also closes portal openings and prevents jumping over the arena walls.
    // Server-driven conveyor creatures do not use character collisions.
    for (side in range(2)) {
        let sign = side == 0 ? -1.0 : 1.0
        let eastWest = create_node(NodeData(name = "arenaBoundaryX", parent = mapRoot,
            position = float3(sign * (hx + ARENA_BOUNDARY_THICKNESS * 0.5), ARENA_BOUNDARY_HEIGHT * 0.5, 0.0),
            scale = float3(ARENA_BOUNDARY_THICKNESS, ARENA_BOUNDARY_HEIGHT, (hz + ARENA_BOUNDARY_THICKNESS) * 2.0)))
        add_component(eastWest, new Collider(shape = box_shape()))
        let northSouth = create_node(NodeData(name = "arenaBoundaryZ", parent = mapRoot,
            position = float3(0.0, ARENA_BOUNDARY_HEIGHT * 0.5, sign * (hz + ARENA_BOUNDARY_THICKNESS * 0.5)),
            scale = float3((hx + ARENA_BOUNDARY_THICKNESS) * 2.0, ARENA_BOUNDARY_HEIGHT, ARENA_BOUNDARY_THICKNESS)))
        add_component(northSouth, new Collider(shape = box_shape()))
    }

    build_conveyor(mapRoot)
    build_plaza(mapRoot)
    for (bi in range(BASE_COUNT)) {
        build_base(mapRoot, bi)
    }

    // benches and lamps between the forecourts
    for (row in range(4)) {
        let z = (float(row) - 1.5) * BASE_Z_STEP
        for (side in range(2)) {
            let sx = side == 0 ? -1.0 : 1.0
            build_lamp(mapRoot, float3(sx * 30.0, 0.0, z + 24.0))
            build_bench(mapRoot, float3(sx * 24.0, 0.0, z + 8.0), side == 0 ? PI * 0.5 : -PI * 0.5)
        }
    }
    for (i in range(9)) {
        let z = -112.0 + float(i) * 28.0
        build_tree(mapRoot, float3(-hx + 5.0, 0.0, z), 1.6)
        build_tree(mapRoot, float3(hx - 5.0, 0.0, z + 8.0), 1.6)
    }

}
