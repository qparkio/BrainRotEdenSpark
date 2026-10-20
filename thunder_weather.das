require engine.core
require constants
require event_state
require game_state
require thunder_vfx


var private sandMaterial : MaterialId


def public load_thunder_weather() {
    sandMaterial = create_material(MaterialImport(shaderName = "standard_diffuse_shader",
        diffuse = request_texture("assets/vfx/sand.png")))
}


struct WeatherSurface {
    node : NodeId
    color : float4
    material : MaterialId
    isDecal : bool = false
}


class ThunderWeather : Component {
    private surfaces : array<WeatherSurface>
    private blend : float = 0.0
    private lastApplied : float = -1.0
    private refresh : float = 0.0
    private skyNode : NodeId
    private mediaDensity : float = 0.0
    private mediaTint : float3 = float3(1.0)
    private mediaAbsorption : float = 1.0
    private mediaHeight : float = 1.0
    private skyTint : float3 = float3(1.0)
    private skyGround : float3 = float3(0.1)
    private coverage : float = 0.2
    private cloudDensity : float = 0.5
    private cumulonimbus : float = 0.0
    private sunColor : float3 = float3(1.0, 0.96, 0.92)
    private sunIntensity : float = 1.0

    def private save_surface(node : NodeId; decal : bool) {
        get_component(node) $(var mesh : Mesh?) {
            surfaces |> push(WeatherSurface(node = node, color = mesh.color, material = mesh.materialId, isDecal = decal))
        }
    }

    def override on_initialize {
        thunderWeatherBlend = 0.0
        for (node in stormGrassNodes) {
            save_surface(node, false)
            for (child in node.get_children()) {
                if (child.name == "studs") {
                    save_surface(child, true)
                }
            }
        }
        get_component(sunNode) $(var light : DirectionalLight?) {
            sunColor = light.color
            sunIntensity = light.intensity
        }
    }

    def private capture_sky() {
        var sky = find_component(type<HDSky>)
        if (sky != null) {
            skyNode = sky.nodeId
            mediaDensity = sky.atmosphere.mediaDensity
            mediaTint = sky.atmosphere.mediaTint
            mediaAbsorption = sky.atmosphere.mediaAbsorption
            mediaHeight = sky.atmosphere.mediaHeight
            skyTint = sky.atmosphere.atmosphereTint
            skyGround = sky.atmosphere.groundColor
            coverage = sky.clouds.layers[0].coverage
            cloudDensity = sky.clouds.layers[0].density
            cumulonimbus = sky.clouds.form.cumulonimbusCoverage
        }
    }

    def private apply_weather() {
        for (surface in surfaces) {
            if (surface.node.isAlive) {
                surface.node?.Mesh.color = lerp(surface.color, THUNDER_SAND_COLOR, blend)
                if (surface.isDecal) {
                    surface.node?.Mesh.materialId = blend > 0.02 ? sandMaterial : surface.material
                }
            }
        }
        for (bulb in stormLampBulbs) {
            bulb?.Mesh.color = lerp(float4(1.0, 0.95, 0.7, 1.0), float4(2.0, 1.5, 0.65, 1.0), blend)
        }
        for (light in stormLampLights) {
            light.isActive = blend > 0.01
            light?.PointLight.intensity = THUNDER_LAMP_INTENSITY * blend
        }
        get_component(sunNode) $(var light : DirectionalLight?) {
            light.color = lerp(sunColor, THUNDER_LIGHT_COLOR, blend)
            light.intensity = lerp(sunIntensity, THUNDER_SUN_INTENSITY, blend)
        }
        get_component(cameraNode) $(var camera : Camera?) {
            camera.backgroundColor = lerp(COL_SKY, THUNDER_SKY_COLOR, blend)
        }
        get_component(renderSettingsNode) $(var fog : DistanceFog?) {
            fog.active = blend > 0.01
            fog.color = THUNDER_DUST_COLOR
            fog.density = THUNDER_FOG_DENSITY * blend
        }
        get_component(skyNode) $(var sky : HDSky?) {
            sky.atmosphere.mediaDensity = lerp(mediaDensity, THUNDER_MEDIA_DENSITY, blend)
            sky.atmosphere.mediaTint = lerp(mediaTint, THUNDER_MEDIA_TINT, blend)
            sky.atmosphere.mediaAbsorption = lerp(mediaAbsorption, THUNDER_MEDIA_ABSORPTION, blend)
            sky.atmosphere.mediaHeight = lerp(mediaHeight, 0.1, blend)
            sky.atmosphere.atmosphereTint = lerp(skyTint, float3(1.0, 0.96, 0.82), blend)
            sky.atmosphere.groundColor = lerp(skyGround, float3(0.64, 0.51, 0.30), blend)
            sky.clouds.layers[0].coverage = lerp(coverage, THUNDER_CLOUD_COVERAGE, blend)
            sky.clouds.layers[0].density = lerp(cloudDensity, THUNDER_CLOUD_DENSITY, blend)
            sky.clouds.form.cumulonimbusCoverage = lerp(cumulonimbus, 0.18, blend)
        }
        set_thunder_dust_strength(blend)
        lastApplied = blend
    }

    def override on_update {
        if (!skyNode.isAlive) {
            capture_sky()
        }
        var state = find_component(type<ThunderState>)
        let active = inWorld && state != null && state.active
        let target = active ? 1.0 : 0.0
        let dt = get_delta_time()
        blend = clamp(blend + sign(target - blend) * dt / THUNDER_TRANSITION_SECONDS, 0.0, 1.0)
        thunderWeatherBlend = blend
        refresh -= dt
        if (refresh <= 0.0 && abs(blend - lastApplied) > 0.0001) {
            refresh = 0.1
            apply_weather()
        }
    }
}


def public spawn_thunder_weather() {
    let node = create_node(NodeData(name = "thunderWeather"))
    add_component(node, new ThunderWeather())
}
