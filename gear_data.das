require engine.core
require brainrot_data

// Gear catalog (prices and rebirth requirements follow the wiki; the set is a playable subset).


enum public GearKind {
    Melee = 0
    SpeedCoil = 1
    GravityCoil = 2
    ComboCoil = 3
    Launcher = 4
    Trap = 5
    Cloak = 6
    Area = 7
}

// statuses a gear can put on another player
let public {
    STATUS_STUN = 1 // ragdolled, cannot move
    STATUS_INVERT = 2 // controls inverted (Bee Launcher)
    STATUS_FREEZE = 3 // frozen in place (Trap)
    STATUS_DANCE = 4 // forced to dance (Boogie Bomb)
}

struct public GearDef {
    name : string
    desc : string
    price : int64
    rebirth : int
    kind : int
    power : float // melee: knockback; launcher: status duration; coil: unused
    cooldown : float
    status : int
    color : float4
}

def private gear_of(name, desc : string; price : int64; rebirth, kind : int; power, cooldown : float; status : int; color : float4) : GearDef {
    return GearDef(name = name, desc = desc, price = price, rebirth = rebirth, kind = kind, power = power, cooldown = cooldown, status = status, color = color)
}

let public {
    GEARS = fixed_array(
        gear_of("Slap", "Knocks thieves back and makes them drop the brainrot", big(0, 0), 0, 0, 24.0, 0.9, 1, float4(0.95, 0.75, 0.3, 1)),
        gear_of("Speed Coil", "Run 50% faster", big(750, 0), 0, 1, 0.0, 0.0, 0, float4(1.0, 0.85, 0.2, 1)),
        gear_of("Trap", "One use. Place a trap that freezes the first thief for 3s", big(1, 3), 0, 5, 3.0, 4.0, 3, float4(0.8, 0.3, 0.3, 1)),
        gear_of("Iron Slap", "Stronger knockback", big(25, 2), 1, 0, 34.0, 0.9, 1, float4(0.7, 0.72, 0.8, 1)),
        gear_of("Gravity Coil", "Jump much higher, fall slowly", big(3, 3), 1, 2, 0.0, 0.0, 0, float4(0.4, 0.7, 1.0, 1)),
        gear_of("Bee Launcher", "Inverts a target's controls for 5s", big(1, 4), 1, 4, 5.0, 10.0, 2, float4(1.0, 0.85, 0.1, 1)),
        gear_of("Gold Slap", "Even stronger knockback", big(15, 3), 2, 0, 42.0, 0.9, 1, float4(1.0, 0.82, 0.15, 1)),
        gear_of("Coil Combo", "Speed and Gravity coil in one", big(2, 4), 2, 3, 0.0, 0.0, 0, float4(0.6, 1.0, 0.6, 1)),
        gear_of("Taser", "Stuns a target for 3s", big(1, 5), 3, 4, 3.0, 5.0, 1, float4(0.3, 0.9, 1.0, 1)),
        gear_of("Invisibility Cloak", "Invisible and twice as fast until used again", big(3, 5), 4, 6, 0.0, 1.0, 0, float4(0.7, 0.4, 0.95, 1)),
        gear_of("Boogie Bomb", "Forces nearby players to dance for 10s", big(5, 5), 4, 7, 10.0, 10.0, 4, float4(1.0, 0.4, 0.8, 1))
    )
}

def public gear_count : int {
    return length(GEARS)
}

def public gear_owned(mask, gear : int) : bool {
    return (uint(mask) & (1u << uint(gear))) != 0u
}
