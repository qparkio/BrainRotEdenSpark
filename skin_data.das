require engine.core
require brainrot_data

// Base skins and the Index (collection book) bookkeeping.
//
// The Index remembers every (brainrot, mutation) pair a player has ever owned. Collecting 75% of the
// roster with one mutation unlocks that mutation's base skin; two skins unlock by owning one OG brainrot.


let public {
    INDEX_MUTATIONS = 9
    SKIN_UNLOCK_FRACTION = 0.75
}

struct public SkinDef {
    name : string
    mutation : int // >0: collect 75% of the roster with this mutation; 0: free
    ownDef : int // >=0: owning this brainrot (any mutation) unlocks the skin
    wall : float4
    trim : float4 // alpha 0: use the owner's player color
    floorCol : float4
    aisle : float4
    accent : float4
    rainbow : bool
}

def private skin_of(name : string; mutation, ownDef : int; wall, trim, floorCol, aisle, accent : float4; rainbow : bool = false) : SkinDef {
    return SkinDef(name = name, mutation = mutation, ownDef = ownDef, wall = wall, trim = trim, floorCol = floorCol, aisle = aisle, accent = accent, rainbow = rainbow)
}

def private def_index(nm : string) : int {
    for (i in range(length(BRAINROTS))) {
        if (BRAINROTS[i].name == nm) {
            return i
        }
    }
    return -1
}

let public {
    SKINS = fixed_array(
        skin_of("Default", 0, -1, float4(0.09, 0.15, 0.27, 1), float4(0, 0, 0, 0), float4(0.82, 0.84, 0.88, 1), float4(0.93, 0.27, 0.12, 1), float4(0.20, 0.21, 0.25, 1)),
        skin_of("Gold", 1, -1, float4(0.42, 0.34, 0.10, 1), float4(1.0, 0.84, 0.15, 1), float4(0.95, 0.88, 0.6, 1), float4(0.95, 0.72, 0.10, 1), float4(0.55, 0.42, 0.08, 1)),
        skin_of("Diamond", 2, -1, float4(0.16, 0.36, 0.44, 1), float4(0.45, 0.95, 1.0, 1), float4(0.75, 0.92, 0.98, 1), float4(0.35, 0.85, 0.95, 1), float4(0.2, 0.5, 0.6, 1)),
        skin_of("Rainbow", 3, -1, float4(0.20, 0.20, 0.26, 1), float4(1.0, 0.4, 0.7, 1), float4(0.88, 0.88, 0.92, 1), float4(0.9, 0.35, 0.8, 1), float4(0.3, 0.3, 0.4, 1), true),
        skin_of("Lava", 4, -1, float4(0.26, 0.09, 0.07, 1), float4(1.0, 0.45, 0.08, 1), float4(0.45, 0.22, 0.16, 1), float4(0.95, 0.3, 0.05, 1), float4(0.35, 0.12, 0.08, 1)),
        skin_of("Candy", 5, -1, float4(0.95, 0.62, 0.82, 1), float4(1.0, 1.0, 1.0, 1), float4(1.0, 0.9, 0.94, 1), float4(1.0, 0.45, 0.7, 1), float4(0.98, 0.7, 0.85, 1)),
        skin_of("Galaxy", 6, -1, float4(0.10, 0.05, 0.26, 1), float4(0.7, 0.3, 1.0, 1), float4(0.35, 0.28, 0.6, 1), float4(0.5, 0.2, 0.9, 1), float4(0.18, 0.1, 0.4, 1)),
        skin_of("Radioactive", 7, -1, float4(0.12, 0.20, 0.10, 1), float4(0.4, 1.0, 0.3, 1), float4(0.55, 0.7, 0.5, 1), float4(0.3, 0.9, 0.2, 1), float4(0.15, 0.28, 0.12, 1)),
        skin_of("Cursed", 8, -1, float4(0.14, 0.05, 0.07, 1), float4(0.9, 0.1, 0.15, 1), float4(0.4, 0.2, 0.24, 1), float4(0.55, 0.05, 0.10, 1), float4(0.22, 0.07, 0.1, 1)),
        skin_of("Strawberry", 0, def_index("Strawberry Elephant"), float4(0.9, 0.25, 0.35, 1), float4(0.4, 0.85, 0.3, 1), float4(0.55, 0.15, 0.2, 1), float4(0.95, 0.3, 0.4, 1), float4(0.75, 0.2, 0.3, 1)),
        skin_of("Skibidi", 0, def_index("Skibidi Toilet"), float4(0.85, 0.88, 0.92, 1), float4(0.3, 0.55, 1.0, 1), float4(0.7, 0.75, 0.82, 1), float4(0.3, 0.5, 0.95, 1), float4(0.6, 0.65, 0.75, 1)),
        skin_of("EdenSpark", 0, -1, float4(0.07, 0.09, 0.11, 1), float4(1.0, 0.30, 0.34, 1), float4(0.68, 0.78, 0.84, 1), float4(0.12, 0.18, 0.21, 1), float4(0.42, 0.86, 0.96, 1))
    )
}

def public skin_count : int {
    return length(SKINS)
}

def public index_size : int {
    return brainrot_count() * INDEX_MUTATIONS
}

def public index_pos(defId, mutation : int) : int {
    return mutation * brainrot_count() + defId
}

def public index_has(discovered : array<uint8>; defId, mutation : int) : bool {
    let p = index_pos(defId, mutation)
    return p >= 0 && p < length(discovered) && discovered[p] != uint8(0)
}

def public index_count(discovered : array<uint8>; mutation : int) : int {
    var n = 0
    for (d in range(brainrot_count())) {
        if (index_has(discovered, d, mutation)) {
            n++
        }
    }
    return n
}

def public index_total_discovered(discovered : array<uint8>) : int {
    var n = 0
    for (d in range(brainrot_count())) {
        var any = false
        for (m in range(INDEX_MUTATIONS)) {
            if (index_has(discovered, d, m)) {
                any = true
            }
        }
        if (any) {
            n++
        }
    }
    return n
}

def public index_needed(mutation : int) : int {
    return int(ceil(float(brainrot_count()) * SKIN_UNLOCK_FRACTION))
}

def public skin_unlocked(discovered : array<uint8>; skin : int) : bool {
    if (skin < 0 || skin >= length(SKINS)) {
        return false
    }
    let s = SKINS[skin]
    if (s.mutation > 0) {
        return index_count(discovered, s.mutation) >= index_needed(s.mutation)
    }
    if (s.ownDef >= 0) {
        for (m in range(INDEX_MUTATIONS)) {
            if (index_has(discovered, s.ownDef, m)) {
                return true
            }
        }
        return false
    }
    return true
}

def public index_cash_bonus(discovered : array<uint8>) : float {
    var bonus = 0.0
    for (m in range(1, INDEX_MUTATIONS)) {
        if (index_count(discovered,m) >= index_needed(m)) { bonus += 0.5 }
    }
    return bonus
}
