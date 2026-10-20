require engine.render.shader_dsl

// Moving cyan and coral light fields on the charcoal EdenSpark background.
// World coordinates keep the paint continuous across the wall sections and roofs.
var {
    flowSpeed = 0.72
    @color charcoal = float3(0.010, 0.014, 0.020)
    @color cyan = float3(0.07, 0.65, 0.95)
    @color coral = float3(1.0, 0.035, 0.10)
}

[pixel_shader]
def eden_surface(inp : UnlitInput) {
    let time = g_Time * flowSpeed
    let latitude = (frac((inp.worldPos.z + 108.0) / 54.0) * 54.0 - 27.0) / 22.0
    let pos = float3((abs(inp.worldPos.x) - 58.0) / 23.0, inp.worldPos.y / 18.0, latitude)
    let cyanCenter = float3(sin(time * 0.8) * 0.9, 0.4 + sin(time * 0.6) * 0.65, cos(time) * 0.8)
    let coralCenter = float3(cos(time * 0.7 + 1.8) * 0.9, 0.5 + cos(time * 0.5) * 0.7, sin(time + 2.5) * 0.9)
    let cyanDelta = pos - cyanCenter
    let coralDelta = pos - coralCenter
    let cyanField = exp(-dot(cyanDelta, cyanDelta) * 1.1)
    let coralField = exp(-dot(coralDelta, coralDelta) * 1.1)
    let lights = cyan * cyanField * 0.055 + coral * coralField * 0.065
    return UnlitOutput(
        color = charcoal + lights,
        alpha = 1.0
    )
}
