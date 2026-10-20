require engine.core
require constants
require event_state
require game_state
require models
require world
require thunder_vfx


def private timer_string(seconds : int) : string {
    let minutes = max(0, seconds) / 60
    let remainder = max(0, seconds) % 60
    let padding = remainder < 10 ? "0" : ""
    return "{minutes}:{padding}{remainder}"
}


class ThunderTimers : Component {
    portalTitle : NodeId
    portalTime : NodeId
    portalBoost : NodeId
    pedestalTitle : NodeId
    pedestalTime : NodeId
    pedestalBoost : NodeId
    private lastSeconds : int = -1
    private wasActive : bool = false
    private receivedState : bool = false

    def override on_update {
        var state = find_component(type<ThunderState>)
        let active = state != null && state.active
        let seconds = state != null ? state.secondsRemaining : int(THUNDER_PERIOD)
        if (seconds == lastSeconds && active == wasActive && receivedState == (state != null)) {
            return
        }
        lastSeconds = seconds
        wasActive = active
        receivedState = state != null
        let title = active ? "THUNDER ACTIVE" : "THUNDER"
        let timer = active ? "ENDS IN {timer_string(seconds)}" : "STARTS IN {timer_string(seconds)}"
        let boost = active ? "2x RARE+ LUCK" : "EVERY 30 MIN  /  LASTS 5 MIN"
        let color = active ? float4(1.0, 0.83, 0.37, 1.0) : COL_WHITE
        portalTitle?.UIText.text = title
        portalTime?.UIText.text = timer
        portalTime?.UIText.color = color
        portalBoost?.UIText.text = boost
        pedestalTitle?.Text3D.text = title
        pedestalTime?.Text3D.text = timer
        pedestalTime?.Text3D.color = color
        pedestalBoost?.Text3D.text = active ? boost : "SANDSTORM EVENT"
    }
}


def public spawn_thunder_view(parent : NodeId) {
    let board = create_node(NodeData(name = "thunderEntranceBoard", parent = parent,
        position = float3(0.0, 23.3, -CONVEYOR_HALF_LENGTH + 1.7)))
    mk_box(board, "thunderBoardFrame", float3(0.0), float3(37.0, 10.0, 0.7), float4(0.68, 0.43, 0.13, 1.0))
    mk_box(board, "thunderBoardFace", float3(0.0, 0.0, 0.4), float3(35.8, 8.8, 0.2), float4(0.07, 0.055, 0.04, 1.0))
    let yaw = flat_yaw(0.0, 1.0)
    let title = label_flat(board, "THUNDER", float3(0.0, 2.6, 0.55), yaw, 64.0, float4(1.0, 0.81, 0.3, 1.0), 34.0)
    let timer = label_flat(board, "STARTS IN 30:00", float3(0.0, 0.0, 0.55), yaw, 62.0, COL_WHITE, 34.0)
    let boost = label_flat(board, "EVERY 30 MIN  /  LASTS 5 MIN", float3(0.0, -2.55, 0.55), yaw, 33.0, float4(0.83, 0.78, 0.65, 1.0), 34.0)
    title.name = "thunderPortalTitle"
    timer.name = "thunderPortalTimer"
    boost.name = "thunderPortalBoost"
    let pedestal = create_node(NodeData(name = "thunderPedestal", parent = parent, position = THUNDER_PEDESTAL_POSITION))
    mk_box(pedestal, "thunderPaving", float3(0.0, 0.15, 0.0), float3(12.0, 0.3, 12.0), float4(0.45, 0.39, 0.3, 1.0))
    mk_box(pedestal, "thunderPlinth", float3(0.0, 0.65, 0.0), float3(9.0, 1.3, 9.0), float4(0.19, 0.17, 0.14, 1.0), true)
    mk_box(pedestal, "thunderRim", float3(0.0, 1.45, 0.0), float3(9.2, 0.3, 9.2), float4(0.85, 0.55, 0.14, 1.0))
    mk_box(pedestal, "thunderTop", float3(0.0, 1.95, 0.0), float3(7.8, 0.7, 7.8), float4(0.30, 0.24, 0.17, 1.0), true)
    let postTitle = label3d(pedestal, "THUNDER", float3(0.0, 21.5, 0.0), 140.0, float4(1.0, 0.81, 0.3, 1.0), 1800.0)
    let postTimer = label3d(pedestal, "STARTS IN 30:00", float3(0.0, 18.9, 0.0), 125.0, COL_WHITE, 1800.0)
    let postBoost = label3d(pedestal, "SANDSTORM EVENT", float3(0.0, 17.2, 0.0), 64.0, float4(0.95, 0.75, 0.43, 1.0), 1800.0)
    postTitle.name = "thunderPedestalTitle"
    postTimer.name = "thunderPedestalTimer"
    postBoost.name = "thunderPedestalBoost"
    spawn_thunder_vortex(pedestal)
    spawn_weather_dust(parent)
    spawn_thunder_dunes(parent)
    let controller = create_node(NodeData(name = "thunderTimers", parent = parent))
    add_component(controller, new ThunderTimers(portalTitle = title, portalTime = timer, portalBoost = boost,
        pedestalTitle = postTitle, pedestalTime = postTimer, pedestalBoost = postBoost))
}
