require engine.core
require constants
require brainrot_data


var private sparkleMaterial : MaterialId


def public load_mutation_visuals() {
    sparkleMaterial = request_material("assets/materials/glow.material")
}


// Local presentation only. The server replicates the mutation number, not runtime resources.
class MutationView : Component {
    mutation : int = 0
    modelHeight : float = 5.0
    private particles : array<NodeId>
    private bodyMeshes : array<NodeId>
    private time : float = 0.0

    def private collectMeshes(node : NodeId) {
        if (has_component(node, type<Mesh>)) {
            bodyMeshes |> push(node)
        }
        for (child in node.get_children()) {
            collectMeshes(child)
        }
    }

    def override on_initialize {
        collectMeshes(nodeId)
        for (i in range(MUTATION_FX_COUNT)) {
            let particle = create_node(NodeData(name = "mutationSpark", parent = nodeId))
            let round = mutation == 5 || mutation == 7
            add_component(particle, new Mesh(meshId = round ? SPHERE_MESH_ID : CUBE_MESH_ID,
                materialId = sparkleMaterial, color = MUTATION_COLORS[mutation], visibility = MeshVisibility.VisibleInAnyCamera))
            particles |> push(particle)
        }
    }

    def override on_update {
        time += get_delta_time() * MUTATION_FX_SPEED
        let radius = clamp(modelHeight * 0.3, 1.1, 2.8)
        if (mutation == 3) {
            let tint = float4(0.7 + 0.3 * sin(time), 0.7 + 0.3 * sin(time + 2.094), 0.7 + 0.3 * sin(time + 4.188), 1.0)
            for (mesh in bodyMeshes) {
                mesh?.Mesh.color = tint
            }
        }
        for (particle, i in particles, count()) {
            let phase = float(i) / float(MUTATION_FX_COUNT)
            let angle = phase * PI * 2.0 + time * 0.7
            let progress = time * 0.25 + phase
            let cycle = progress - floor(progress)
            var y : float = modelHeight * cycle
            var scale : float = 0.11 + 0.09 * sin(cycle * PI)
            var color = MUTATION_COLORS[mutation]
            if (mutation == 1 || mutation == 2) {
                // Gold glints and diamond shards.
                scale = (mutation == 1 ? 0.12 : 0.18) * pow(max(0.0, sin(time * 2.0 + phase * 9.0)), 4.0)
                color = mutation == 1 ? float4(1.3, 1.05, 0.32, 1.0) : float4(0.55, 1.15, 1.3, 1.0)
            } elif (mutation == 3) {
                color = float4(0.7 + 0.3 * sin(angle), 0.7 + 0.3 * sin(angle + 2.094), 0.7 + 0.3 * sin(angle + 4.188), 1.0)
            } elif (mutation == 4) {
                // Rising embers, strongest at the feet.
                color = float4(1.4, 0.2 + cycle * 0.4, 0.02, 1.0)
                scale *= 1.0 - cycle
            } elif (mutation == 5) {
                color = i % 2 == 0 ? float4(1.0, 0.28, 0.6, 1.0) : float4(1.0)
                y = modelHeight * (0.5 + 0.3 * sin(angle))
            } elif (mutation == 6) {
                // White / violet stars orbit the galaxy body.
                color = i % 2 == 0 ? float4(0.7, 0.45, 1.2, 1.0) : float4(1.1, 1.1, 1.3, 1.0)
                y = modelHeight * (0.5 + 0.35 * sin(angle * 0.8))
            } elif (mutation == 7) {
                color = float4(0.18, 1.3, 0.1, 1.0)
                scale = 0.15 + 0.12 * sin(cycle * PI)
            } elif (mutation == 8) {
                color = i % 2 == 0 ? float4(0.7, 0.01, 0.02, 1.0) : float4(0.035, 0.015, 0.045, 1.0)
                scale = 0.18 + 0.08 * sin(cycle * PI)
            }
            particle.localPosition = float3(cos(angle) * radius, y, sin(angle) * radius)
            particle.localRotation = quat4(time + phase, angle, time * 0.5)
            particle.localScale = float3(max(0.01, scale))
            particle?.Mesh.color = color
        }
    }
}
