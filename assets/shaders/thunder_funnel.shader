require engine.render.shader_dsl

var {
    spinSpeed = 1.7
    opacity = 0.70
    @color sandDark = float3(0.34, 0.20, 0.06)
    @color sandLight = float3(0.91, 0.70, 0.36)
}

[pixel_shader]
def thunder_funnel(inp : UnlitInput) {
    let height = inp.uv.y
    let spin = inp.uv.x * 6.283185 + height * 11.0 - g_Time * spinSpeed
    let circular = float2(cos(spin), sin(spin))
    let turbulence = noise(float3(circular.x * 3.0, circular.y * 3.0, height * 9.0 - g_Time * 0.9))
    let fine = noise(float3(circular.x * 8.0, circular.y * 8.0, height * 23.0 - g_Time * 1.4))
    let bands = sin(spin * 4.0 + turbulence * 2.0) * 0.5 + 0.5
    let density = turbulence * 0.62 + fine * 0.18 + bands * 0.20
    let ends = smooth_step(0.0, 0.09, height) * (1.0 - smooth_step(0.76, 1.0, height))
    return UnlitOutput(color = lerp(sandDark, sandLight, density),
        alpha = ends * opacity * smooth_step(0.38, 0.76, bands + fine * 0.18))
}
