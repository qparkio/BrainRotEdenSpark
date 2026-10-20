require engine.core
require constants
require components
require models


// One model for the tool in hand and the replicated trap on the ground.
def public build_trap_model(parent : NodeId; pos : float3; scale : float = 1.0) : NodeId {
    let root = create_node(NodeData(name = "trapModel", parent = parent, position = pos, scale = float3(scale)))
    mk_box(root, "spring", float3(0.0, 0.12, 0.0), float3(3.7, 0.22, 0.45), TRAP_DARK_METAL)
    mk_box(root, "pressurePlate", float3(0.0, 0.22, 0.0), float3(1.5, 0.18, 1.5), TRAP_METAL)
    for (i in range(TRAP_JAW_SEGMENTS)) {
        let angle = float(i) * PI * 2.0 / float(TRAP_JAW_SEGMENTS)
        let rim = mk_box(root, "jaw", float3(cos(angle) * 1.6, 0.26, sin(angle) * 1.6), float3(0.85, 0.28, 0.30), TRAP_METAL)
        rim.localRotation = quat4(0.0, -angle + PI * 0.5, 0.0)
        let tooth = mk_box(root, "tooth", float3(cos(angle) * 1.4, 0.53, sin(angle) * 1.4), float3(0.24, 0.54, 0.24), TRAP_METAL)
        tooth.localRotation = quat4(0.0, -angle, 0.0)
    }
    mk_box(root, "armedLamp", float3(0.0, 0.36, 0.0), float3(0.4, 0.14, 0.4), float4(1.0, 0.72, 0.08, 1.0))
    return root
}


class TrapView : Component {
    private model : NodeId
    private armedLamp : NodeId
    private shownArmed : bool = false

    def override on_initialize {
        model = build_trap_model(nodeId, float3(0.0))
        for (child in model.get_children()) {
            if (child.name == "armedLamp") {
                armedLamp = child
            }
        }
    }

    def override on_update {
        var trap = get_component(nodeId, type<TrapItem>)
        if (trap != null && trap.armed != shownArmed) {
            shownArmed = trap.armed
            armedLamp?.Mesh.color = shownArmed ? float4(1.0, 0.08, 0.03, 1.0) : float4(1.0, 0.72, 0.08, 1.0)
        }
    }
}


def public update_traps() {
    for (trap in find_components(type<TrapItem>)) {
        if (!has_component(trap.nodeId, type<TrapView>)) {
            add_component(trap.nodeId, new TrapView())
        }
    }
}
