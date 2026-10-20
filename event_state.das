require engine.core
require engine.networking
require constants


// Persistent room state. No visual resources or client decisions travel on wire.
[replicated]
class ThunderState : Component {
    active : bool = false
    secondsRemaining : int = int(THUNDER_PERIOD)
    rareMultiplier : float = 1.0
    cycle : int = 0
}


def public thunder_rare_multiplier() : float {
    var state = find_component(type<ThunderState>)
    return state != null ? state.rareMultiplier : 1.0
}
