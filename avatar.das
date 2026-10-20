require engine.core
require constants
require gear_data
require models
require traps
require ui_assets


// Visual + procedural animation for one player. Works for the local player and for
// remote mirrors alike: speed is measured from the node's own movement.
class AvatarView : Component {
    color : float4 = float4(1)
    playerName : string = "Player"
    carrying : bool = false
    stunned : bool = false
    dancing : bool = false
    cloaked : bool = false
    isLocal : bool = false
    heldGear : int = -1
    swingTimer : float = 0.0

    private parts : CharacterParts
    private lastPos : float3
    private phase : float = 0.0
    private blend : float = 0.0
    private nameNode : NodeId
    private builtColor : float4
    private builtName : string = ""
    private gearNode : NodeId
    private builtGear : int = -2
    private danceT : float = 0.0

    def override on_initialize {
        parts = build_character(nodeId, color)
        builtColor = color
        lastPos = nodeId.worldPosition
        nameNode = create_node(NodeData(name = "nameTag", parent = nodeId, position = float3(0, PLAYER_NAME_HEIGHT, 0)))
        add_component(nameNode, new Text3D(text = playerName, fontId = chat_font(), useDepthScale = false, fontSize = PLAYER_NAME_SIZE, color = COL_WHITE,
            size = float2(420.0, PLAYER_NAME_SIZE * 1.5), fontAutoSize = float2(14.0, PLAYER_NAME_SIZE), wordWrapping = false,
            effect = TextEffect.Outline, effectColor = COL_BLACK, effectThickness = 3.0))
        builtName = playerName
        gearNode = mk_pivot(parts.armR, "gear", float3(0, -1.6, 0.6))
    }

    def swing {
        swingTimer = 0.35
    }

    // rebuild the tool held in the right hand
    def private rebuildGear {
        builtGear = heldGear
        var inscope kids = gearNode.get_children()
        for (k in kids) {
            remove_node(k)
        }
        if (heldGear < 0 || heldGear >= gear_count()) {
            return
        }
        let g = GEARS[heldGear]
        let kind = g.kind
        if (kind == int(GearKind.Melee)) {
            mk_box(gearNode, "handle", float3(0, 0.0, 0.9), float3(0.35, 0.35, 2.0), float4(0.55, 0.35, 0.15, 1.0))
            mk_box(gearNode, "head", float3(0, 0.0, 2.3), float3(0.9, 0.9, 1.7), g.color)
        } elif (kind == int(GearKind.SpeedCoil) || kind == int(GearKind.GravityCoil) || kind == int(GearKind.ComboCoil)) {
            for (i in range(8)) {
                let a = float(i) * PI * 2.0 / 8.0
                mk_box(gearNode, "coil{i}", float3(cos(a) * 0.9, sin(a) * 0.9, 1.0), float3(0.45, 0.45, 0.9), g.color)
            }
            mk_box(gearNode, "core", float3(0, 0, 1.0), float3(0.5, 0.5, 1.1), float4(0.3, 0.3, 0.35, 1.0))
        } elif (kind == int(GearKind.Launcher)) {
            mk_box(gearNode, "body", float3(0, 0.1, 1.0), float3(0.6, 0.8, 1.6), g.color)
            mk_box(gearNode, "barrel", float3(0, 0.2, 2.2), float3(0.35, 0.35, 1.4), float4(0.25, 0.25, 0.3, 1.0))
        } elif (kind == int(GearKind.Trap)) {
            build_trap_model(gearNode, float3(0.0, 0.0, 1.0), 0.5)
        } elif (kind == int(GearKind.Cloak)) {
            mk_box(gearNode, "orb", float3(0, 0.0, 1.0), float3(0.9, 0.9, 0.9), g.color)
        } else {
            mk_ball(gearNode, "bomb", float3(0, 0.0, 1.0), float3(1.3), g.color)
            mk_box(gearNode, "fuse", float3(0, 0.8, 1.0), float3(0.15, 0.5, 0.15), float4(0.6, 0.45, 0.25, 1.0))
        }
    }

    def override on_update {
        let dt = get_delta_time()
        if (builtName != playerName) {
            builtName = playerName
            nameNode?.Text3D.text = playerName
        }
        if (builtColor != color) {
            builtColor = color
            parts.torso?.Mesh.color = color
        }
        if (builtGear != heldGear) {
            rebuildGear()
        }
        // other players vanish while cloaked; the owner still sees themselves
        let visible = isLocal || !cloaked
        parts.root.isActive = visible
        nameNode.isActive = visible && !isLocal
        // Text3D billboarding must not inherit the avatar's yaw.
        nameNode.worldRotation = quat4(0.0, 0.0, 0.0)
        let p = nodeId.worldPosition
        let delta = float3(p.x - lastPos.x, 0.0, p.z - lastPos.z)
        let speed = dt > 0.0001 ? length(delta) / dt : 0.0
        lastPos = p
        let wantBlend = clamp(speed / WALK_SPEED, 0.0, 1.0)
        blend += (wantBlend - blend) * min(1.0, dt * 12.0)
        phase += speed * dt * 0.62
        let sw = sin(phase * 2.0) * 0.95 * blend

        var armLAng = sw
        var armRAng = -sw
        let legLAng = -sw
        let legRAng = sw

        if (carrying) {
            armLAng = -1.25
            armRAng = -1.25
        }
        if (heldGear >= 0 && !carrying) {
            armRAng = -0.9
        }
        if (swingTimer > 0.0) {
            swingTimer = max(0.0, swingTimer - dt)
            let k = 1.0 - swingTimer / 0.35
            armRAng = -2.6 + k * 2.6
        }
        var sway = 0.0
        if (dancing) {
            danceT += dt * 9.0
            armLAng = -2.8 + sin(danceT) * 0.6
            armRAng = -2.8 - sin(danceT) * 0.6
            sway = sin(danceT * 0.5) * 0.35
        }

        parts.armL.localRotation = quat4(armLAng, 0.0, 0.0)
        parts.armR.localRotation = quat4(armRAng, 0.0, 0.0)
        parts.legL.localRotation = quat4(legLAng, 0.0, 0.0)
        parts.legR.localRotation = quat4(legRAng, 0.0, 0.0)

        // stun wobble / dance sway
        var bodyTilt = 0.0
        if (stunned) {
            bodyTilt = sin(get_time() * 18.0) * 0.18 - 1.25
        }
        parts.root.localRotation = quat4(bodyTilt, sway, 0.0)
        let bob = abs(sin(phase * 2.0)) * 0.18 * blend + (dancing ? abs(sin(danceT)) * 0.5 : 0.0)
        parts.root.localPosition = float3(0.0, bob + (stunned ? 0.9 : 0.0), 0.0)
    }
}
