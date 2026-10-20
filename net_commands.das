require engine.core
require engine.networking


// ---------------- client -> server ----------------

[net_command(reliability=RELIABLE_ORDERED, channel=Events)]
struct ChatSend {
    message : string
}

[net_command(reliability=RELIABLE_ORDERED, channel=Events)]
struct ChatMessage {
    author : string
    message : string
}

[net_command(reliability=RELIABLE_ORDERED, channel=Events)]
struct ChatNotice {
    message : string
}

[net_command(reliability=UNRELIABLE_SEQUENCED, channel=Controls)]
struct MoveState {
    pos : float3
    yaw : float
    grounded : bool
}

[net_command(reliability=RELIABLE_ORDERED)]
struct BuyRequest {
    item : NodeId
}

[net_command(reliability=RELIABLE_ORDERED)]
struct StealBegin {
    item : NodeId
}

[net_command(reliability=RELIABLE_ORDERED)]
struct StealCancel {
    dummy : int
}

[net_command(reliability=RELIABLE_ORDERED)]
struct StealRequest {
    item : NodeId
}

[net_command(reliability=RELIABLE_ORDERED)]
struct CollectRequest {
    slot : int
}

// use the gear in hand (swing the slap, fire the launcher, drop the trap ...)
[net_command(reliability=RELIABLE_ORDERED)]
struct GearUse {
    yaw : float
}

[net_command(reliability=RELIABLE_ORDERED)]
struct GearEquip {
    gear : int // -1 to put it away
}

[net_command(reliability=RELIABLE_ORDERED)]
struct GearBuy {
    gear : int
}

[net_command(reliability=RELIABLE_ORDERED)]
struct LockRequest {
    dummy : int
}

[net_command(reliability=RELIABLE_ORDERED)]
struct UpgradeRequest {
    dummy : int
}

[net_command(reliability=RELIABLE_ORDERED)]
struct RebirthRequest {
    dummy : int
}

[net_command(reliability=RELIABLE_ORDERED)]
struct SellRequest {
    slot : int
}

[net_command(reliability=RELIABLE_ORDERED)]
struct FuseRequest {
    slots : uint
}

[net_command(reliability=RELIABLE_ORDERED, channel=Events)]
struct PositionCorrection {
    pos : float3
}

[net_command(reliability=RELIABLE_ORDERED)]
struct SkinSelect {
    skin : int
}


// developer helper (honoured by the server only while DEBUG_CHEATS is on)
[net_command(reliability=RELIABLE_ORDERED)]
struct DebugCommand {
    kind : int // 1 give cash, 2 set rebirths, 3 discover everything, 5 seed a QA item
    amount : int64
}


// Developer console request, accepted only from the local room's first player.
[net_command(reliability=RELIABLE_ORDERED)]
struct ThunderStart {
    dummy : int
}

// ---------------- server -> client ----------------

let public {
    FX_BUY = 0
    FX_COLLECT = 1
    FX_STEAL_START = 2
    FX_STEAL_DONE = 3
    FX_BAT_SWING = 4
    FX_BAT_HIT = 5
    FX_LOCK = 6
    FX_REBIRTH = 7
    FX_DELIVER = 8
    FX_RARE_SPAWN = 9
    FX_ERROR = 10
    FX_UNLOCK = 11
    FX_ALARM = 12
    FX_SHOP = 13
    FX_SELL = 14
    FX_DISCOVER = 15
    FX_SKIN = 16
    FX_TRAP = 17
}

[net_command(reliability=RELIABLE_ORDERED, channel=Events)]
struct FxEvent {
    kind : int
    pos : float3
    a : int
    b : int
    amount : int64
    text : string
}

[net_command(reliability=RELIABLE_ORDERED, channel=Events)]
struct KnockbackEvent {
    dir : float3
    strength : float
}

// a gear effect landed on this player (see STATUS_* in gear_data.das)
[net_command(reliability=RELIABLE_ORDERED, channel=Events)]
struct StatusEvent {
    kind : int
    duration : float
}
