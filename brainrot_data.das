require engine.core
require constants

// Brainrot roster, rarities, mutations and money formatting. Numbers follow the Steal a Brainrot wiki
// (October 2026). Money is int64 everywhere because late units cost trillions.


enum public Rarity {
    Common = 0
    Rare = 1
    Epic = 2
    Legendary = 3
    Mythic = 4
    BrainrotGod = 5
    Secret = 6
    OG = 7
}

// voxel body archetypes used by the procedural model builder (see models.das)
enum public Shape {
    Noob = 0
    ElephantCactus = 1
    Cheese = 2
    PigBomb = 3
    Kiwi = 4
    ShrimpCat = 5
    Beaver = 6
    TireFrog = 7
    Log = 8
    CoffeeNinja = 9
    TreeMonkey = 10
    FishLegs = 11
    DolphinBanana = 12
    ChimpBanana = 13
    Ballerina = 14
    CrocPlane = 15
    SharkSneaker = 16
    CowSaturn = 17
    Elephant = 18
    Animal = 19
    Fruit = 20
    Robot = 21
    Octopus = 22
    Bird = 23
    Panda = 24
    Human = 25
    Toilet = 26
}

struct public BrainrotDef {
    name : string
    rarity : int
    price : int64
    income : int64
    shape : int
    colorA : float4
    colorB : float4
}

// m * 10^e without floating point
def public big(m : int; e : int) : int64 {
    var r = int64(m)
    for (i in range(e)) {
        r *= int64(10)
    }
    return r
}

def private def_of(name : string; rarity : int; price, income : int64; shape : int; a, b : float4) : BrainrotDef {
    return BrainrotDef(name = name, rarity = rarity, price = price, income = income, shape = shape, colorA = a, colorB = b)
}

let public {
    RARITY_NAMES = fixed_array("Common", "Rare", "Epic", "Legendary", "Mythic", "Brainrot God", "Secret", "OG")
    // label colors as on the wiki: green, cyan, purple, yellow, red, rainbow, black/white, yellow/black
    RARITY_COLORS = fixed_array(
        float4(0.35, 0.95, 0.40, 1.0),
        float4(0.30, 0.85, 1.00, 1.0),
        float4(0.75, 0.40, 1.00, 1.0),
        float4(1.00, 0.90, 0.20, 1.0),
        float4(1.00, 0.25, 0.25, 1.0),
        float4(1.00, 0.50, 0.90, 1.0),
        float4(0.95, 0.95, 0.95, 1.0),
        float4(1.00, 0.80, 0.10, 1.0)
    )
    // relative spawn weight of each tier on the conveyor
    RARITY_WEIGHTS = fixed_array(60.0, 26.0, 9.0, 4.0, 1.6, 0.4, 0.07, 0.01)
}

let public {
    BRAINROTS = fixed_array(
        // ---- Common ----
        def_of("Noobini Pizzanini", 0, big(25, 0), big(1, 0), 0, float4(0.25, 0.45, 0.95, 1), float4(1.0, 0.65, 0.2, 1)),
        def_of("Lirili Larila", 0, big(250, 0), big(3, 0), 1, float4(0.35, 0.72, 0.35, 1), float4(0.95, 0.85, 0.35, 1)),
        def_of("Tim Cheese", 0, big(500, 0), big(5, 0), 2, float4(1.0, 0.82, 0.2, 1), float4(0.95, 0.6, 0.1, 1)),
        def_of("Fluriflura", 0, big(750, 0), big(7, 0), 19, float4(0.97, 0.6, 0.78, 1), float4(1.0, 1.0, 1.0, 1)),
        def_of("Talpa Di Fero", 0, big(1000, 0), big(9, 0), 19, float4(0.5, 0.5, 0.58, 1), float4(0.95, 0.65, 0.55, 1)),
        def_of("Svinina Bombardino", 0, big(12, 2), big(10, 0), 3, float4(1.0, 0.65, 0.72, 1), float4(0.1, 0.1, 0.12, 1)),
        def_of("Pipi Kiwi", 0, big(15, 2), big(13, 0), 4, float4(0.55, 0.38, 0.22, 1), float4(0.5, 0.85, 0.3, 1)),
        def_of("Pipi Corni", 0, big(17, 2), big(14, 0), 20, float4(1.0, 0.85, 0.25, 1), float4(0.35, 0.75, 0.3, 1)),
        // ---- Rare ----
        def_of("Trippi Troppi", 1, big(2, 3), big(15, 0), 5, float4(1.0, 0.55, 0.3, 1), float4(0.97, 0.8, 0.7, 1)),
        def_of("Gangster Footera", 1, big(4, 3), big(30, 0), 19, float4(0.2, 0.2, 0.25, 1), float4(0.95, 0.8, 0.3, 1)),
        def_of("Bandito Bobritto", 1, big(45, 2), big(35, 0), 6, float4(0.55, 0.36, 0.2, 1), float4(0.85, 0.15, 0.15, 1)),
        def_of("Boneca Ambalabu", 1, big(5, 3), big(40, 0), 7, float4(0.12, 0.12, 0.14, 1), float4(0.4, 0.85, 0.35, 1)),
        def_of("Cacto Hipopotamo", 1, big(65, 2), big(50, 0), 1, float4(0.45, 0.65, 0.5, 1), float4(0.95, 0.5, 0.65, 1)),
        def_of("Ta Ta Ta Ta Sahur", 1, big(75, 2), big(55, 0), 8, float4(0.72, 0.45, 0.22, 1), float4(0.35, 0.22, 0.12, 1)),
        def_of("Tric Trac Baraboom", 1, big(9, 3), big(65, 0), 21, float4(0.55, 0.6, 0.7, 1), float4(0.95, 0.35, 0.3, 1)),
        def_of("Pipi Avocado", 1, big(95, 2), big(70, 0), 20, float4(0.4, 0.62, 0.25, 1), float4(0.6, 0.4, 0.2, 1)),
        // ---- Epic ----
        def_of("Cappuccino Assassino", 2, big(10, 3), big(75, 0), 9, float4(0.72, 0.5, 0.3, 1), float4(0.12, 0.12, 0.14, 1)),
        def_of("Bandito Axolito", 2, big(125, 2), big(90, 0), 19, float4(1.0, 0.65, 0.78, 1), float4(0.9, 0.2, 0.3, 1)),
        def_of("Brr Brr Patapim", 2, big(15, 3), big(100, 0), 10, float4(0.58, 0.38, 0.2, 1), float4(0.3, 0.6, 0.25, 1)),
        def_of("Trulimero Trulicina", 2, big(20, 3), big(125, 0), 11, float4(0.3, 0.55, 0.95, 1), float4(0.98, 0.8, 0.65, 1)),
        def_of("Bananita Dolphinita", 2, big(25, 3), big(150, 0), 12, float4(1.0, 0.88, 0.3, 1), float4(0.5, 0.75, 0.95, 1)),
        def_of("Perochello Lemonchello", 2, big(275, 2), big(160, 0), 20, float4(1.0, 0.92, 0.25, 1), float4(0.4, 0.75, 0.3, 1)),
        def_of("Gato Celesto", 2, big(4, 4), big(250, 0), 19, float4(0.55, 0.78, 1.0, 1), float4(1.0, 1.0, 0.8, 1)),
        def_of("Penguino Cocosino", 2, big(45, 3), big(300, 0), 23, float4(0.25, 0.25, 0.3, 1), float4(0.6, 0.4, 0.22, 1)),
        // ---- Legendary ----
        def_of("Chimpanzini Bananini", 3, big(5, 4), big(300, 0), 13, float4(1.0, 0.88, 0.3, 1), float4(0.45, 0.3, 0.18, 1)),
        def_of("Ballerina Cappuccina", 3, big(1, 5), big(500, 0), 14, float4(0.97, 0.7, 0.85, 1), float4(0.75, 0.52, 0.32, 1)),
        def_of("Chef Crabracadabra", 3, big(15, 4), big(600, 0), 19, float4(0.95, 0.3, 0.25, 1), float4(1.0, 1.0, 1.0, 1)),
        def_of("Lionel Cactuseli", 3, big(175, 3), big(650, 0), 1, float4(0.95, 0.75, 0.3, 1), float4(0.35, 0.7, 0.3, 1)),
        def_of("Glorbo Fruttodrillo", 3, big(2, 5), big(750, 0), 15, float4(0.35, 0.75, 0.35, 1), float4(0.95, 0.3, 0.35, 1)),
        def_of("Blueberrinni Octopusini", 3, big(25, 4), big(1, 3), 22, float4(0.3, 0.35, 0.85, 1), float4(0.65, 0.7, 1.0, 1)),
        def_of("Strawberrelli Flamingelli", 3, big(275, 3), big(11, 2), 23, float4(1.0, 0.45, 0.6, 1), float4(0.35, 0.75, 0.3, 1)),
        def_of("Pandaccini Bananini", 3, big(3, 5), big(125, 1), 24, float4(1.0, 1.0, 1.0, 1), float4(0.1, 0.1, 0.12, 1)),
        def_of("Sigma Boy", 3, big(325, 3), big(135, 1), 25, float4(0.2, 0.2, 0.28, 1), float4(0.98, 0.8, 0.3, 1)),
        // ---- Mythic ----
        def_of("Frigo Camelo", 4, big(35, 4), big(19, 2), 19, float4(0.85, 0.95, 1.0, 1), float4(0.55, 0.75, 0.95, 1)),
        def_of("Orangutini Ananassini", 4, big(4, 5), big(2, 3), 20, float4(1.0, 0.7, 0.2, 1), float4(0.3, 0.65, 0.3, 1)),
        def_of("Rhino Toasterino", 4, big(45, 4), big(21, 2), 19, float4(0.6, 0.62, 0.68, 1), float4(0.95, 0.75, 0.4, 1)),
        def_of("Bombardiro Crocodilo", 4, big(5, 5), big(25, 2), 15, float4(0.38, 0.55, 0.32, 1), float4(0.5, 0.52, 0.55, 1)),
        def_of("Bombombini Gusini", 4, big(1, 6), big(5, 3), 23, float4(0.95, 0.95, 0.95, 1), float4(0.35, 0.4, 0.3, 1)),
        def_of("Zibra Zubra Zibralini", 4, big(1, 6), big(6, 3), 19, float4(0.97, 0.97, 0.97, 1), float4(0.1, 0.1, 0.12, 1)),
        def_of("Avocadorilla", 4, big(2, 6), big(7, 3), 19, float4(0.38, 0.55, 0.25, 1), float4(0.6, 0.4, 0.2, 1)),
        def_of("Te Te Te Sahur", 4, big(4, 6), big(95, 2), 8, float4(0.8, 0.5, 0.25, 1), float4(0.2, 0.15, 0.1, 1)),
        def_of("Los Noobinis", 4, big(43, 5), big(125, 2), 0, float4(0.95, 0.8, 0.25, 1), float4(1.0, 0.65, 0.2, 1)),
        def_of("Tree Tree Tree Sahur", 4, big(49, 5), big(17, 3), 8, float4(0.45, 0.65, 0.3, 1), float4(0.35, 0.22, 0.12, 1)),
        // ---- Brainrot God ----
        def_of("Girafa Celestre", 5, big(75, 5), big(2, 4), 19, float4(0.98, 0.85, 0.4, 1), float4(0.55, 0.75, 1.0, 1)),
        def_of("Tralalero Tralala", 5, big(1, 7), big(5, 4), 16, float4(0.35, 0.55, 0.9, 1), float4(0.95, 0.95, 0.98, 1)),
        def_of("Odin Din Din Dun", 5, big(125, 5), big(75, 3), 21, float4(0.6, 0.62, 0.7, 1), float4(0.3, 0.8, 0.95, 1)),
        def_of("Los Crocodillitos", 5, big(125, 5), big(55, 3), 15, float4(0.35, 0.6, 0.3, 1), float4(0.85, 0.85, 0.3, 1)),
        def_of("Pop Pop Sahur", 5, big(65, 6), big(295, 3), 8, float4(0.88, 0.55, 0.3, 1), float4(0.15, 0.1, 0.1, 1)),
        // ---- Secret ----
        def_of("La Vacca Saturno Saturnita", 6, big(5, 7), big(300, 3), 17, float4(0.45, 0.8, 0.95, 1), float4(0.97, 0.97, 0.97, 1)),
        def_of("Chimpanzini Spiderini", 6, big(1, 8), big(325, 3), 13, float4(0.15, 0.15, 0.2, 1), float4(0.9, 0.2, 0.25, 1)),
        def_of("Los Tralaleritos", 6, big(1, 8), big(5, 5), 16, float4(0.35, 0.5, 0.85, 1), float4(0.9, 0.45, 0.2, 1)),
        def_of("Graipuss Medussi", 6, big(1, 9), big(1, 6), 22, float4(0.6, 0.35, 0.8, 1), float4(0.55, 0.85, 0.3, 1)),
        def_of("Garama and Madundung", 6, big(1, 10), big(5, 7), 21, float4(0.95, 0.35, 0.3, 1), float4(0.97, 0.97, 0.97, 1)),
        def_of("Nuclearo Dinossauro", 6, big(15, 9), big(15, 6), 19, float4(0.3, 0.9, 0.35, 1), float4(0.15, 0.15, 0.15, 1)),
        // ---- OG ----
        def_of("Skibidi Toilet", 7, big(45, 10), big(45, 8), 26, float4(0.97, 0.97, 0.97, 1), float4(0.95, 0.8, 0.65, 1)),
        def_of("Strawberry Elephant", 7, big(5, 11), big(75, 8), 18, float4(0.95, 0.2, 0.3, 1), float4(0.35, 0.75, 0.3, 1))
    )
}

// mutations: 0 none; multipliers and look follow the wiki
let public {
    MUTATION_NAMES = fixed_array("", "Gold", "Diamond", "Rainbow", "Lava", "Candy", "Galaxy", "Radioactive", "Cursed")
    MUTATION_MULT = fixed_array(1.0, 1.25, 1.5, 10.0, 6.0, 4.0, 7.0, 8.5, 9.0)
    MUTATION_COLORS = fixed_array(
        float4(1, 1, 1, 1),
        float4(1.0, 0.82, 0.15, 1),
        float4(0.45, 0.92, 1.0, 1),
        float4(1.0, 0.35, 0.65, 1),
        float4(1.0, 0.45, 0.1, 1),
        float4(1.0, 0.55, 0.8, 1),
        float4(0.6, 0.25, 0.95, 1),
        float4(0.35, 1.0, 0.3, 1),
        float4(0.75, 0.1, 0.15, 1)
    )
    // chance of each mutation when a brainrot spawns (checked in order, rarest first)
    MUTATION_CHANCES = fixed_array(0.0, 0.040, 0.020, 0.004, 0.003, 0.002, 0.0015, 0.001, 0.001)
}

def public brainrot_count : int {
    return length(BRAINROTS)
}

// pick a roster entry: first a tier by weight, then uniformly inside the tier
def public pick_brainrot_def(r1, r2 : float; rareMultiplier : float = 1.0) : int {
    var total = 0.0
    for (i in range(length(RARITY_WEIGHTS))) {
        let multiplier = i >= THUNDER_RARE_MIN_TIER ? rareMultiplier : 1.0
        total += RARITY_WEIGHTS[i] * multiplier
    }
    var acc = 0.0
    var tier = 0
    let target = r1 * total
    for (i in range(length(RARITY_WEIGHTS))) {
        let multiplier = i >= THUNDER_RARE_MIN_TIER ? rareMultiplier : 1.0
        acc += RARITY_WEIGHTS[i] * multiplier
        if (target < acc) {
            tier = i
            break
        }
    }
    var count = 0
    for (d in BRAINROTS) {
        if (d.rarity == tier) {
            count++
        }
    }
    if (count == 0) {
        return 0
    }
    var pick = min(int(r2 * float(count)), count - 1)
    for (i in range(length(BRAINROTS))) {
        if (BRAINROTS[i].rarity == tier) {
            if (pick == 0) {
                return i
            }
            pick--
        }
    }
    return 0
}

def public pick_mutation(r : float) : int {
    var m = 0
    var acc = 0.0
    for (i in range(1, length(MUTATION_CHANCES))) {
        acc += MUTATION_CHANCES[i]
        if (r < acc) {
            m = i
            break
        }
    }
    return m
}

def public scale_money(v : int64; mult : float) : int64 {
    return int64(double(v) * double(mult))
}

def public item_price(defId, mutation : int) : int64 {
    return scale_money(BRAINROTS[defId].price, MUTATION_MULT[mutation])
}

def public item_income(defId, mutation : int) : int64 {
    return scale_money(BRAINROTS[defId].income, MUTATION_MULT[mutation])
}

def private one_decimal(v : double; unit : double) : string {
    let x = v / unit
    let whole = int64(x)
    let frac = int64((x - double(whole)) * 10.0lf)
    return "{whole}.{frac}"
}

// $999, $12.3K, $4.5M, $7.0B, $1.2T, $3.4Qa
def public format_cash(v : int64) : string {
    var s = ""
    let d = double(v)
    if (v >= big(1, 15)) {
        s = "{one_decimal(d, 1000000000000000.0lf)}Qa"
    } elif (v >= big(1, 12)) {
        s = "{one_decimal(d, 1000000000000.0lf)}T"
    } elif (v >= int64(1000000000)) {
        s = "{one_decimal(d, 1000000000.0lf)}B"
    } elif (v >= int64(1000000)) {
        s = "{one_decimal(d, 1000000.0lf)}M"
    } elif (v >= int64(10000)) {
        s = "{one_decimal(d, 1000.0lf)}K"
    } else {
        s = "{v}"
    }
    return "${s}"
}

// ---------------- rebirths ----------------

let public {
    REBIRTH_COSTS = fixed_array(
        big(1, 6), big(5, 6), big(25, 6), big(1, 8), big(5, 8), big(25, 8),
        big(1, 10), big(5, 10), big(25, 10), big(1, 12), big(5, 12), big(25, 12)
    )
    REBIRTH_MULTIPLIERS = fixed_array(1.0, 1.5, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 10.0, 12.0, 14.0, 16.0)
}

def public income_multiplier(rebirths : int) : float {
    return REBIRTH_MULTIPLIERS[clamp(rebirths, 0, length(REBIRTH_MULTIPLIERS) - 1)]
}

def public rebirth_cost(rebirths : int) : int64 {
    return REBIRTH_COSTS[clamp(rebirths, 0, length(REBIRTH_COSTS) - 1)]
}

// Requirements use characters present in this port's roster.
def public rebirth_required_def(rebirths, which : int) : int {
    let first = fixed_array(8, 16, 19, 24, 33, 36, 44, 43, 48, 49, 51, 52)
    let second = fixed_array(9, 18, 25, 26, 34, 37, 45, 46, 50, 51, 52, 53)
    let r = clamp(rebirths, 0, MAX_REBIRTHS - 1)
    return which == 0 ? first[r] : second[r]
}

def public lock_duration(rebirths : int) : float {
    return BASE_LOCK_TIME + 10.0 * float(rebirths)
}

def public floor_slot_count(rebirths : int) : int {
    // floor 1: 10 slots, floor 2 (+8) from rebirth 2, floor 3 (+4) from rebirth 10
    var n = 10
    if (rebirths >= 2) {
        n += 8
    }
    if (rebirths >= 10) {
        n += 4
    }
    return n
}
