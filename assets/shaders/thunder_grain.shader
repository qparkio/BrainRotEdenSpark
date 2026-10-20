require engine.render.shader_dsl

var {
    @color tint = float3(0.72, 0.49, 0.18)
    opacity = 0.6
}

[pixel_shader]
def thunder_grain(inp : UnlitInput) {
    let p = inp.uv * 2.0 - float2(1.0)
    let core = 1.0 - smooth_step(0.12, 0.8, dot(p, p))
    return UnlitOutput(color = tint, alpha = core * opacity)
}
