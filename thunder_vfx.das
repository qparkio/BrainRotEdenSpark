require engine.core
require constants
require game_state


var private {
    funnelPrefab : PrefabId
    funnelMaterial : MaterialId
    dustMaterial : MaterialId
    grainMaterial : MaterialId
    windGrainMaterial : MaterialId
    duneMaterial : MaterialId
    dunePrefab : PrefabId
}


def public load_thunder_visuals() {
    funnelPrefab = request_prefab("assets/vfx/thunder_funnel.glb")
    funnelMaterial = request_material("assets/materials/thunder_funnel.material")
    dustMaterial = request_material("assets/materials/thunder_dust.material")
    grainMaterial = request_material("assets/materials/glow.material")
    windGrainMaterial = request_material("assets/materials/thunder_grain.material")
    dunePrefab = request_prefab("assets/vfx/thunder_dune.glb")
    duneMaterial = create_material(MaterialImport(shaderName = "standard_diffuse_shader",
        diffuse = request_texture("assets/vfx/sand.png")))
}


def private dress_funnel(node : NodeId) : int {
    var meshes = 0
    get_component(node) $(var mesh : Mesh?) {
        mesh.materialId = funnelMaterial
        mesh.visibility = MeshVisibility.VisibleInAnyCamera
        meshes++
    }
    for (child in node.get_children()) {
        meshes += dress_funnel(child)
    }
    return meshes
}


class ThunderVortex : Component {
    private dressed : bool = false
    private time : float = 0.0

    def override on_update {
        if (!dressed) {
            dressed = dress_funnel(nodeId) > 0
        }
        time += get_delta_time() * THUNDER_FUNNEL_SPEED
        nodeId.localRotation = quat4(0.0, time, 0.0)
    }
}


class SandSpiral : Component {
    phase : float = 0.0
    private time : float = 0.0

    def override on_update {
        time += get_delta_time()
        let travel = time * 0.13 + phase
        let progress = travel - floor(travel)
        let radius = 0.45 + pow(progress, 1.38) * 4.0
        let angle = time * 3.2 + phase * 42.0 - progress * 8.0
        nodeId.localPosition = float3(cos(angle) * radius, progress * THUNDER_FUNNEL_HEIGHT, sin(angle) * radius)
        let size = 0.06 + sin(progress * PI) * 0.12
        nodeId.localScale = float3(size * 1.5, size * 0.6, size)
    }
}


class WeatherDust : Component {
    visual : NodeId
    phase : float = 0.0
    grain : bool = false
    private time : float = 0.0

    def override on_update {
        time += get_delta_time()
        visual.isActive = inWorld && thunderWeatherBlend > 0.01
        if (!visual.isActive || !cameraNode.isAlive) {
            return
        }
        let travel = time * (grain ? 0.17 : 0.045) + phase
        let wind = travel - floor(travel)
        let x = -90.0 + wind * 180.0
        let scatterZ = phase * 17.7
        let scatterY = phase * 9.3
        let z = -114.0 + (scatterZ - floor(scatterZ)) * 228.0
        let y = 0.8 + (scatterY - floor(scatterY)) * 17.0 + sin(time * 0.8 + phase * 6.0) * 0.5
        visual.worldPosition = float3(x, y, z)
        visual.worldRotation = cameraNode.worldRotation * quat4(PI * 0.5, 0.0, 0.0)
    }
}


def public spawn_thunder_vortex(parent : NodeId) {
    let vortex = instantiate_prefab(funnelPrefab, NodeData(name = "thunderVortex", parent = parent,
        position = float3(0.0, 2.25, 0.0)))
    add_component(vortex, new ThunderVortex())
    let debris = create_node(NodeData(name = "thunderSandSpirals", parent = parent, position = float3(0.0, 2.25, 0.0)))
    for (i in range(THUNDER_SPIRAL_COUNT)) {
        let grain = create_node(NodeData(name = "sandGrain", parent = debris))
        add_component(grain, new Mesh(meshId = SPHERE_MESH_ID, materialId = grainMaterial,
            color = THUNDER_SAND_COLOR, visibility = MeshVisibility.VisibleInAnyCamera))
        add_component(grain, new SandSpiral(phase = float(i) / float(THUNDER_SPIRAL_COUNT)))
    }
}


def public spawn_weather_dust(parent : NodeId) {
    let root = create_node(NodeData(name = "thunderDust", parent = parent))
    for (i in range(THUNDER_DUST_COUNT)) {
        let controller = create_node(NodeData(name = "weatherDustController", parent = root))
        let visual = create_node(NodeData(name = "weatherDust", parent = controller, scale = float3(14.0, 1.0, 7.0)))
        visual.isActive = false
        add_component(visual, new Mesh(meshId = PLANE_MESH_ID, materialId = dustMaterial, visibility = MeshVisibility.VisibleInAnyCamera))
        add_component(controller, new WeatherDust(visual = visual, phase = float(i) / float(THUNDER_DUST_COUNT)))
    }
    for (i in range(THUNDER_GRAIN_COUNT)) {
        let controller = create_node(NodeData(name = "windGrainController", parent = root))
        let size = 0.05 + float(i % 7) * 0.015
        let visual = create_node(NodeData(name = "windSandGrain", parent = controller, scale = float3(size * 3.0, 1.0, size)))
        visual.isActive = false
        add_component(visual, new Mesh(meshId = PLANE_MESH_ID, materialId = windGrainMaterial, visibility = MeshVisibility.VisibleInAnyCamera))
        add_component(controller, new WeatherDust(visual = visual, phase = float(i) / float(THUNDER_GRAIN_COUNT), grain = true))
    }
}


def public set_thunder_dust_strength(strength : float) {
    update_material(dustMaterial, MaterialProperties("opacity", strength * THUNDER_DUST_OPACITY))
    update_material(windGrainMaterial, MaterialProperties("opacity", strength * 0.6))
}


class ThunderDunes : Component {
    visual : NodeId
    private dressed : bool = false

    def override on_update {
        if (!dressed) {
            var count = 0
            for (node in visual.get_children()) {
                get_component(node) $(var mesh : Mesh?) {
                    mesh.materialId = duneMaterial
                    count++
                }
            }
            dressed = count > 0
        }
        visual.isActive = inWorld && thunderWeatherBlend > 0.01
        visual.localScale = float3(1.0, max(0.01, thunderWeatherBlend), 1.0)
    }
}


def public spawn_thunder_dunes(parent : NodeId) {
    let controller = create_node(NodeData(name = "thunderDunesController", parent = parent))
    let root = create_node(NodeData(name = "thunderExitDunes", parent = parent))
    root.isActive = false
    for (side in fixed_array(-1.0, 1.0)) {
        instantiate_prefab(dunePrefab, NodeData(name = "thunderDune", parent = root,
            position = float3(side * 18.0, 0.03, CONVEYOR_HALF_LENGTH - 11.0), rotation = quat4(0.0, side * 0.3, 0.0)))
        instantiate_prefab(dunePrefab, NodeData(name = "thunderDune", parent = root,
            position = float3(side * 29.0, 0.03, CONVEYOR_HALF_LENGTH - 6.0), scale = float3(1.3, 1.4, 0.8)))
    }
    add_component(controller, new ThunderDunes(visual = root))
}
