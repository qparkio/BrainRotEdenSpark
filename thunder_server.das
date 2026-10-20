require engine.core
require engine.networking
require constants
require event_state


// The only clock that changes event phase. This component exists on the server.
class ThunderClock : Component {
    private remaining : float = THUNDER_PERIOD

    def private publish() {
        var state = get_component(nodeId, type<ThunderState>)
        if (state != null) {
            state.secondsRemaining = max(0, int(ceil(remaining)))
            state.rareMultiplier = state.active ? THUNDER_RARE_MULTIPLIER : 1.0
        }
    }

    def start_now() {
        var state = get_component(nodeId, type<ThunderState>)
        if (state == null || state.active) {
            return
        }
        state.active = true
        state.cycle++
        remaining = THUNDER_DURATION
        publish()
        print("[Thunder] started: 300 seconds, Rare+ weights x2")
    }

    def advance(seconds : float) {
        var state = get_component(nodeId, type<ThunderState>)
        if (state == null) {
            return
        }
        remaining -= max(0.0, seconds)
        while (remaining <= 0.0) {
            if (state.active) {
                state.active = false
                remaining += THUNDER_PERIOD - THUNDER_DURATION
                print("[Thunder] ended")
            } else {
                state.active = true
                state.cycle++
                remaining += THUNDER_DURATION
                print("[Thunder] scheduled start")
            }
        }
        publish()
    }

    def override on_update {
        if (has_network() && is_server()) {
            advance(get_delta_time())
        }
    }
}


def public spawn_thunder_clock() {
    let node = create_node(NodeData(name = "thunderClock"))
    add_component(node, new ThunderState())
    add_component(node, new ThunderClock())
}


def public start_thunder_server() {
    var clock = find_component(type<ThunderClock>)
    if (clock != null) {
        clock.start_now()
    }
}
