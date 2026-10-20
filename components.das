require engine.core
require engine.networking


// One per connected player. The node is owned by the server; the owning client drives its own
// local character and reports its position, the server mirrors it here for everyone else.
[replicated(sync = Transform)]
class PlayerAvatar : Component {
    playerName : string = "Player"
    colorIdx : int = 0
    baseIndex : int = -1
    cash : int64 = 0l
    rebirths : int = 0
    incomePerSec : int64 = 0l
    steals : int = 0
    carrying : bool = false
    carryDef : int = -1
    carryMutation : int = 0
    stunned : bool = false
    dancing : bool = false
    cloaked : bool = false
    stealing : bool = false
    equipped : int = -1 // gear id held in hand, -1 for empty hands
    gearMask : int = 1 // bit n set: gear n owned (bit 0 = Slap, always)
    swingCount : int = 0
    lockRemaining : float = 0.0
    lockCooldown : float = 0.0
    skin : int = 0
    floors : int = 1 // 2 once the base has been upgraded
    discovered : array<uint8> // the Index: one byte per (mutation, brainrot) pair ever owned
}


// state: 0 conveyor, 1 base, 2 carried, 3 walking to the purchasing player's base
[replicated(sync = Transform)]
class BrainrotItem : Component {
    defId : int = 0
    mutation : int = 0
    state : int = 0
    baseIndex : int = -1
    slot : int = -1
    padCash : int64 = 0l
    carrierNode : NodeId
    purchaseCount : int = 0
    @no_replicate homeBase : int = -1
    @no_replicate homeSlot : int = -1
    @no_replicate bornAt : float = 0.0
}


// a trap dropped by a player; freezes the first other player who steps on it
[replicated(sync = Transform)]
class TrapItem : Component {
    ownerNode : NodeId
    armed : bool = false
    @no_replicate armedAt : float = 0.0
}
