require engine.render.shader_dsl

var {
    @color tint = float3(0.76, 0.60, 0.32)
    opacity = 0.085
}

[pixel_shader]
def thunder_dust(inp : UnlitInput) {
    let p = inp.uv * 2.0 - float2(1.0)
    let softness = exp(-dot(p, p) * 2.5)
    let edge = (1.0 - smooth_step(0.55, 1.0, abs(p.x))) * (1.0 - smooth_step(0.55, 1.0, abs(p.y)))
    let wisps = noise(inp.uv * 6.0 + float2(g_Time * 0.12, g_Time * -0.04))
    let detail = noise(inp.uv * 19.0 + float2(g_Time * 0.22, 0.0))
    let density = smooth_step(0.3, 0.75, wisps) * (0.55 + detail * 0.45)
    return UnlitOutput(color = tint * (0.75 + wisps * 0.25), alpha = softness * edge * density * opacity)
}
