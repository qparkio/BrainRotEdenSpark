require engine.core
require engine.networking
require constants
require layout
require brainrot_data
require gear_data
require net_commands
require game_state
require player
require ui
require sounds
require world


// A label that rises and fades out ("+$250" over a pad).
class FloatText : Component {
    ttl : float = 1.3
    speed : float = 5.0
    color : float4 = float4(1)
    private age : float = 0.0

    def override on_update {
        let dt = get_delta_time()
        age += dt
        var p = nodeId.localPosition
        p.y += speed * dt * (1.0 - age / ttl * 0.6)
        nodeId.localPosition = p
        let a = clamp((ttl - age) / 0.4, 0.0, 1.0)
        nodeId?.Text3D.color = float4(color.x, color.y, color.z, a)
        if (age >= ttl) {
            remove_node(nodeId)
        }
    }
}

// Expanding sparkle burst for happy events (purchases, rebirth).
class Burst : Component {
    color : float4 = float4(1, 0.85, 0.2, 1)
    count : int = 14
    private bits : array<NodeId>
    private vels : array<float3>
    private age : float = 0.0

    def override on_initialize {
        for (i in range(count)) {
            let b = create_node(NodeData(name = "spark", parent = nodeId, scale = float3(0.45)))
            add_component(b, new Mesh(meshId = CUBE_MESH_ID, color = color))
            bits |> push(b)
            let ang = random_float() * 6.28
            let up = 4.0 + random_float() * 7.0
            let out = 2.0 + random_float() * 6.0
            vels |> push(float3(cos(ang) * out, up, sin(ang) * out))
        }
    }

    def override on_update {
        let dt = get_delta_time()
        age += dt
        for (i in range(length(bits))) {
            vels[i].y -= 22.0 * dt
            bits[i].localPosition += vels[i] * dt
            bits[i].localScale = float3(max(0.05, 0.45 * (1.0 - age / 0.9)))
        }
        if (age > 0.9) {
            remove_node(nodeId)
        }
    }
}

def public spawn_float_text(pos : float3; str : string; color : float4; size : float = 40.0) {
    let n = create_node(NodeData(name = "floatText", position = pos))
    add_component(n, new Text3D(text = str, color = color, fontSize = size, effect = TextEffect.Outline, effectColor = COL_BLACK, effectThickness = 3.0))
    add_component(n, new FloatText(color = color))
}

def public spawn_burst(pos : float3; color : float4; count : int = 14) {
    let n = create_node(NodeData(name = "burst", position = pos))
    add_component(n, new Burst(color = color, count = count))
}


[net_command_handler]
def private on_fx(cmd : FxEvent) {
    if (cmd.kind == FX_BUY) {
        play_sfx("buy")
        let bd = BRAINROTS[cmd.a]
        let mutName = MUTATION_NAMES[cmd.b]
        let prefix = empty(mutName) ? "" : "{mutName} "
        show_toast("Purchased {prefix}{bd.name}!", RARITY_COLORS[bd.rarity])
        spawn_burst(cmd.pos + float3(0.0, 2.0, 0.0), RARITY_COLORS[bd.rarity], 18)
        play_voice(cmd.a, cmd.pos, 0.9, 4.0)
    } elif (cmd.kind == FX_COLLECT) {
        play_sfx("collect", 0.9)
        spawn_float_text(cmd.pos + float3(0.0, 3.0, 0.0), "+{format_cash(cmd.amount)}", COL_CASH, 46.0)
    } elif (cmd.kind == FX_STEAL_START) {
        play_sfx_at("orig_stealing", cmd.pos, 1.0)
    } elif (cmd.kind == FX_STEAL_DONE) {
        play_sfx_at("steal", cmd.pos, 0.9)
        play_voice(cmd.a, cmd.pos, 0.9, 3.5)
        spawn_burst(cmd.pos + float3(0.0, 3.0, 0.0), COL_RED, 12)
    } elif (cmd.kind == FX_BAT_SWING) {
        play_sfx_at("swing", cmd.pos, 0.9, 0.9 + random_float() * 0.2)
    } elif (cmd.kind == FX_BAT_HIT) {
        play_sfx_at("hit", cmd.pos, 1.0, 0.9 + random_float() * 0.2)
        spawn_burst(cmd.pos + float3(0.0, 3.0, 0.0), float4(1, 1, 1, 1), 10)
        spawn_float_text(cmd.pos + float3(0.0, 6.0, 0.0), "BONK!", float4(1.0, 0.9, 0.2, 1.0), 48.0)
    } elif (cmd.kind == FX_LOCK) {
        play_sfx_at("lock", cmd.pos, 1.0)
        if (cmd.a == localBase) {
            show_toast("Base locked for {cmd.b}s!", float4(1.0, 0.5, 0.5, 1.0))
        }
    } elif (cmd.kind == FX_UNLOCK) {
        play_sfx_at("unlock", cmd.pos, 0.8)
    } elif (cmd.kind == FX_REBIRTH) {
        play_sfx("rebirth")
        show_toast(cmd.text, float4(0.75, 0.5, 1.0, 1.0))
        spawn_burst(localPlayer.isAlive ? localPlayer.worldPosition + float3(0.0, 3.0, 0.0) : float3(0), float4(0.7, 0.4, 1.0, 1.0), 30)
        close_windows()
    } elif (cmd.kind == FX_DELIVER) {
        play_sfx_at("deliver", cmd.pos, 0.8)
        spawn_burst(cmd.pos + float3(0.0, 2.5, 0.0), float4(0.4, 1.0, 0.5, 1.0), 12)
        if (!empty(cmd.text)) {
            show_toast(cmd.text, float4(0.5, 1.0, 0.6, 1.0))
        }
    } elif (cmd.kind == FX_RARE_SPAWN) {
        play_sfx("rare", 0.7)
        play_voice(cmd.a, float3(0), 1.0, 5.0, false)
        show_toast(cmd.text, RARITY_COLORS[BRAINROTS[cmd.a].rarity])
    } elif (cmd.kind == FX_ERROR) {
        play_sfx("error", 0.8)
        show_toast(cmd.text, float4(1.0, 0.45, 0.45, 1.0))
    } elif (cmd.kind == FX_ALARM) {
        flash_alarm(cmd.b == 1 ? 1.0 : 0.7)
        play_alarm_once()
        show_toast(cmd.text, float4(1.0, 0.35, 0.35, 1.0))
    } elif (cmd.kind == FX_SHOP) {
        play_sfx("shop")
        show_toast(cmd.text, float4(0.5, 0.9, 1.0, 1.0))
    } elif (cmd.kind == FX_SELL) {
        play_sfx("sell")
        show_toast("Sold for {format_cash(cmd.amount)}", COL_CASH)
    } elif (cmd.kind == FX_DISCOVER) {
        play_sfx("rare", 0.5, 1.3)
        show_toast(cmd.text, float4(1.0, 0.9, 0.5, 1.0))
        mark_index_dirty()
    } elif (cmd.kind == FX_SKIN) {
        play_sfx("deliver", 0.8)
        show_toast(cmd.text, float4(1.0, 0.85, 0.4, 1.0))
    } elif (cmd.kind == FX_TRAP) {
        play_sfx_at("lock", cmd.pos, 0.7, 1.4)
        if (!empty(cmd.text)) {
            show_toast(cmd.text, float4(1.0, 0.75, 0.4, 1.0))
        }
    }
}

[net_command_handler]
def private on_knockback(cmd : KnockbackEvent) {
    if (!localPlayer.isAlive) {
        return
    }
    var lp = get_component(localPlayer, type<LocalPlayer>)
    if (lp != null) {
        lp.knock = cmd.dir * cmd.strength
    }
}

[net_command_handler]
def private on_status(cmd : StatusEvent) {
    if (!localPlayer.isAlive) {
        return
    }
    var lp = get_component(localPlayer, type<LocalPlayer>)
    if (lp == null) {
        return
    }
    if (cmd.kind == STATUS_STUN) {
        lp.stunTimer = cmd.duration
        show_toast("Stunned!", float4(1.0, 0.7, 0.3, 1.0))
    } elif (cmd.kind == STATUS_INVERT) {
        lp.invertTimer = cmd.duration
        show_toast("Controls inverted!", float4(1.0, 0.85, 0.2, 1.0))
    } elif (cmd.kind == STATUS_FREEZE) {
        lp.freezeTimer = cmd.duration
        show_toast("Frozen!", float4(0.5, 0.85, 1.0, 1.0))
    } elif (cmd.kind == STATUS_DANCE) {
        lp.danceTimer = cmd.duration
        show_toast("Boogie!", float4(1.0, 0.5, 0.85, 1.0))
    }
}
