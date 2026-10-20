require engine.core
require engine.networking
require constants
require layout
require brainrot_data
require gear_data
require skin_data
require components
require net_commands
require chat_server
require thunder_server
require event_state

// Authoritative game logic. Runs only inside dedicated.das.



struct SavedItem {
    defId : int
    mutation : int
    slot : int
    cash : int64
}

struct SavedProfile {
    cash : int64 = int64(START_CASH)
    rebirths : int = 0
    gearMask : int = 1
    equipped : int = 0
    skin : int = 0
    floors : int = 1
    steals : int = 0
    discovered : array<uint8>
    items : array<SavedItem>
}

def private ensure_profiles {
    if (!profilesLoaded) {
        load_storage("brainrot-profiles-v1", profiles)
        profilesLoaded = true
    }
}

def private profile_key(userId : uint64; name : string) : string {
    return userId == 0ul ? "local:{name}" : "user:{userId}"
}

// Keep a stolen item's original slot reserved until theft is delivered or cancelled.
def private slot_reserved(base, slot : int) : bool {
    for (it in find_components(type<BrainrotItem>)) {
        if ((it.state == 1 || it.state == 3) && it.baseIndex == base && it.slot == slot) { return true }
        if (it.state == 2 && it.homeBase == base && it.homeSlot == slot) { return true }
    }
    return false
}

def private save_player(node : NodeId) {
    var pa = get_component(node,type<PlayerAvatar>)
    var ps = get_component(node,type<PlayerServer>)
    if (pa == null || ps == null) { return }
    ensure_profiles()
    if (empty(ps.profileKey)) { ps.profileKey = profile_key(0ul,pa.playerName) }
    var profile = SavedProfile(cash=pa.cash,rebirths=pa.rebirths,gearMask=pa.gearMask,equipped=pa.equipped,skin=pa.skin,floors=pa.floors,steals=pa.steals)
    for (b in pa.discovered) { profile.discovered |> push(b) }
    for (it in find_components(type<BrainrotItem>)) {
        if ((it.state == 1 || it.state == 3) && it.baseIndex == pa.baseIndex) {
            profile.items |> push(SavedItem(defId=it.defId,mutation=it.mutation,slot=it.slot,cash=it.padCash))
        } elif (it.state == 2 && it.homeBase == pa.baseIndex) {
            profile.items |> push(SavedItem(defId=it.defId,mutation=it.mutation,slot=it.homeSlot,cash=it.padCash))
        }
    }
    profiles[ps.profileKey] <- profile
}

def public server_save {
    ensure_profiles()
    for (pa in find_components(type<PlayerAvatar>)) { save_player(pa.nodeId) }
    let result = save_storage(profiles,"brainrot-profiles-v1")
    if (result != SaveStorageResult.Success) { print("[server] PROFILE SAVE FAILED: {result}") }
}

// server-only data that must not reach the clients
class PlayerServer : Component {
    profileKey : string
    connId : int = 0
    lastPos : float3
    lastMoveAt : float = 0.0
    stealItem : NodeId
    stealStartAt : float = -100.0
    useReadyAt : float = 0.0
    stunUntil : float = 0.0
    freezeUntil : float = 0.0
    danceUntil : float = 0.0
    lockUntil : float = 0.0
    lockReadyAt : float = 0.0
    joinedAt : float = 0.0
    traps : array<NodeId>
}


var private {
    playerByConn : table<int; NodeId>
    spawnTimer : float = 1.0
    incomeTimer : float = 0.0
    playersJoined : int = 0
    profiles : table<string; SavedProfile>
    profilesLoaded : bool = false
    saveTimer : float = 0.0
}


////////////////////////////////////////////////////////////////////////////////
// helpers
////////////////////////////////////////////////////////////////////////////////

def private send_fx(conn : int; kind : int; pos : float3 = float3(0); a : int = 0; b : int = 0; amount : int64 = 0l; text : string = "") {
    broadcast_net_command(FxEvent(kind = kind, pos = pos, a = a, b = b, amount = amount, text = text), ConnectionId(conn))
}

def private all_fx(kind : int; pos : float3 = float3(0); a : int = 0; b : int = 0; text : string = "") {
    broadcast_net_command(FxEvent(kind = kind, pos = pos, a = a, b = b, amount = 0l, text = text))
}

def private avatar_of(connection : ConnectionId) : NodeId {
    return playerByConn?[*connection] ?? NodeId()
}

def private conn_of(node : NodeId) : int {
    var c = -1
    var ps = get_component(node, type<PlayerServer>)
    if (ps != null) {
        c = ps.connId
    }
    return c
}

def private now : float {
    return get_time()
}

def private owner_of_base(baseIndex : int) : NodeId {
    var found = NodeId()
    for (pa in find_components(type<PlayerAvatar>)) {
        if (pa.baseIndex == baseIndex) {
            found = pa.nodeId
        }
    }
    return found
}

// lowest free slot that the base owner has unlocked
def private free_slot(baseIndex : int) : int {
    var taken : bool[22]
    for (it in find_components(type<BrainrotItem>)) {
        if ((it.state == 1 || it.state == 3) && it.baseIndex == baseIndex && it.slot >= 0 && it.slot < SLOTS_PER_BASE) {
            taken[it.slot] = true
        }
    }
    var maxFloor = 0
    let owner = owner_of_base(baseIndex)
    if (owner.isAlive) {
        var pa = get_component(owner, type<PlayerAvatar>)
        if (pa != null) {
            maxFloor = pa.rebirths >= 10 ? 2 : ((pa.floors >= 2 || pa.rebirths >= 2) ? 1 : 0)
        }
    }
    var result = -1
    for (i in range(SLOTS_PER_BASE)) {
        if (result < 0 && !taken[i] && !slot_reserved(baseIndex,i) && slot_floor(i) <= maxFloor) {
            result = i
        }
    }
    return result
}

// record the brainrot in the owner's Index; congratulate on new entries
def private mark_discovered(owner : NodeId; defId, mutation : int) {
    var pa = get_component(owner, type<PlayerAvatar>)
    if (pa == null) {
        return
    }
    if (length(pa.discovered) < index_size()) {
        pa.discovered |> resize(index_size())
    }
    let p = index_pos(defId, mutation)
    if (p >= 0 && p < length(pa.discovered) && pa.discovered[p] == uint8(0)) {
        pa.discovered[p] = uint8(1)
        let c = conn_of(owner)
        if (c >= 0) {
            send_fx(c, FX_DISCOVER, float3(0), defId, mutation, 0l, "Index: {MUTATION_NAMES[mutation]} {BRAINROTS[defId].name} discovered!")
        }
    }
}

def private place_in_slot(var it : BrainrotItem?; baseIndex, slot : int) {
    it.state = 1
    it.baseIndex = baseIndex
    it.slot = slot
    it.padCash = 0l
    it.carrierNode = NodeId()
    it.homeBase = baseIndex
    it.homeSlot = slot
    let p = slot_pos(baseIndex, slot)
    it.nodeId.localPosition = float3(p.x, p.y + 1.3, p.z)
    it.nodeId.localRotation = quat4(0.0, slot_yaw(slot), 0.0)
    let owner = owner_of_base(baseIndex)
    if (owner.isAlive) {
        mark_discovered(owner, it.defId, it.mutation)
    }
}

def private carried_item_of(avatar : NodeId) : BrainrotItem? {
    for (it in find_components(type<BrainrotItem>)) {
        if (it.state == 2 && it.carrierNode == avatar) {
            return it
        }
    }
    return null
}

def private new_item(defId, mutation : int; pos : float3) : NodeId {
    let node = create_node(NodeData(name = "brainrot_{BRAINROTS[defId].name}", position = pos))
    add_component(node, new BrainrotItem(defId = defId, mutation = mutation, state = 0, bornAt = now()))
    return node
}

// put a carried/stolen item back where it came from, or delete it if there is nowhere to go
def private drop_carried(avatar : NodeId) {
    var pa = get_component(avatar, type<PlayerAvatar>)
    if (pa == null) {
        return
    }
    var it = carried_item_of(avatar)
    pa.carrying = false
    pa.carryDef = -1
    if (it == null) {
        return
    }
    let banked = it.padCash
    let owner = owner_of_base(it.homeBase)
    var restored = false
    if (owner.isAlive && it.homeBase >= 0 && it.homeSlot >= 0) {
        var occupied = false
        for (other in find_components(type<BrainrotItem>)) {
            if (other.state == 1 && other.baseIndex == it.homeBase && other.slot == it.homeSlot) {
                occupied = true
            }
        }
        if (!occupied) {
            place_in_slot(it, it.homeBase, it.homeSlot)
            restored = true
        } else {
            let fs = free_slot(it.homeBase)
            if (fs >= 0) {
                place_in_slot(it, it.homeBase, fs)
                restored = true
            }
        }
    }
    if (!restored) {
        remove_node(it.nodeId)
    } else {
        it.padCash = banked
        let c = conn_of(owner)
        if (c >= 0) {
            send_fx(c, FX_ERROR, float3(0), 0, 0, 0l, "Your brainrot returned to your base!")
        }
    }
}

// hit another player with a gear effect
def private apply_status(target : NodeId; status : int; duration : float) {
    var pa = get_component(target, type<PlayerAvatar>)
    var ps = get_component(target, type<PlayerServer>)
    if (pa == null || ps == null) {
        return
    }
    let t = now()
    if (status == STATUS_STUN || status == STATUS_FREEZE) {
        pa.stunned = true
        ps.stunUntil = t + duration
        if (status == STATUS_FREEZE) {
            pa.dancing = false
            ps.freezeUntil = t + duration
        }
        drop_carried(target)
        pa.stealing = false
        ps.stealStartAt = -100.0
    } elif (status == STATUS_DANCE) {
        pa.dancing = true
        ps.danceUntil = t + duration
        drop_carried(target)
        pa.stealing = false
        ps.stealStartAt = -100.0
    }
    broadcast_net_command(StatusEvent(kind = status, duration = duration), ConnectionId(ps.connId))
}


////////////////////////////////////////////////////////////////////////////////
// lifecycle
////////////////////////////////////////////////////////////////////////////////

def private restore_profile(node : NodeId; base : int; profile : SavedProfile) {
    var player = get_component(node, type<PlayerAvatar>)
    player.cash = max(profile.cash, 0l)
    player.rebirths = clamp(profile.rebirths, 0, MAX_REBIRTHS)
    player.gearMask = profile.gearMask | 1
    let restoredGear = clamp(profile.equipped, 0, gear_count() - 1)
    player.equipped = gear_owned(player.gearMask, restoredGear) ? restoredGear : 0
    player.skin = clamp(profile.skin, 0, skin_count() - 1)
    player.floors = clamp(profile.floors, 1, 2)
    player.steals = max(profile.steals, 0)
    for (i in range(min(index_size(), length(profile.discovered)))) {
        player.discovered[i] = profile.discovered[i]
    }
    for (entry in profile.items) {
        if (entry.defId < 0 || entry.defId >= brainrot_count() || entry.mutation < 0 || entry.mutation >= INDEX_MUTATIONS || entry.slot < 0 || entry.slot >= SLOTS_PER_BASE || slot_reserved(base, entry.slot)) {
            continue
        }
        let itemNode = new_item(entry.defId, entry.mutation, slot_pos(base, entry.slot))
        var item = get_component(itemNode, type<BrainrotItem>)
        place_in_slot(item, base, entry.slot)
        item.padCash = max(entry.cash, 0l)
    }
}


[net_event_handler(client_connected)]
def private on_client_connected(conn : ConnectionId; userId : uint64; name : string) {
    ensure_profiles()
    var base = -1
    for (b in range(BASE_COUNT)) {
        if (base < 0 && !owner_of_base(b).isAlive) {
            base = b
        }
    }
    if (base < 0) { return }
    playersJoined++
    var pname = empty(name) ? "Player{playersJoined}" : name
    var profileKey = profile_key(userId, pname)
    for (existing in find_components(type<PlayerServer>)) {
        if (existing.profileKey == profileKey) {
            // Local matching may join the same account from several editor instances.
            // Keep each guest's inventory separate from the active owner's profile.
            profileKey = "{profileKey}:guest:{base}"
            pname = "{pname} {base + 1}"
            break
        }
    }
    let spawn = base >= 0 ? spawn_pos(base) : float3(0, 3, 0)
    let node = create_node(NodeData(name = "player_{pname}", position = spawn))
    var pa = new PlayerAvatar(playerName = pname, colorIdx = max(base, 0), baseIndex = base, cash = int64(START_CASH), equipped = 0)
    pa.discovered |> resize(index_size())
    add_component(node, pa)
    add_component(node, new PlayerServer(connId = *conn, lastPos = spawn, lastMoveAt = now(), joinedAt = now(), lockUntil = now() + 30.0))
    set_node_owner(node, conn)
    add_component(node, new ChatSender())
    playerByConn[*conn] = node
    var serverPlayer = get_component(node,type<PlayerServer>)
    serverPlayer.profileKey = profileKey
    // Block lookup reads an existing value without inserting into the locked table.
    var restored = get(profiles, serverPlayer.profileKey) $(profile) {
        restore_profile(node, base, profile)
    }
    if (!restored && pname == "local") {
        restored = get(profiles, profile_key(0ul, pname)) $(profile) {
            restore_profile(node, base, profile)
        }
    }
    if (restored) {
        print("[server] PROFILE LOADED {serverPlayer.profileKey}")
    }
    print("[server] {pname} joined conn={*conn} base={base}")
}

[net_event_handler(client_disconnected)]
def private on_client_disconnected(conn : ConnectionId; cause : DisconnectCause) {
    let node = avatar_of(conn)
    if (!node.isAlive) {
        return
    }
    drop_carried(node)
    server_save()
    var pa = get_component(node, type<PlayerAvatar>)
    var ps = get_component(node, type<PlayerServer>)
    let base = pa != null ? pa.baseIndex : -1
    if (base >= 0) {
        for (it in find_components(type<BrainrotItem>)) {
            if (it.baseIndex == base && (it.state == 1 || it.state == 3)) {
                remove_node(it.nodeId)
            } elif (it.state == 2 && it.homeBase == base) {
                var thief = get_component(it.carrierNode,type<PlayerAvatar>)
                if (thief != null) { thief.carrying = false; thief.carryDef = -1 }
                remove_node(it.nodeId)
            }
        }
    }
    if (ps != null) {
        for (t in ps.traps) {
            if (t.isAlive) {
                remove_node(t)
            }
        }
    }
    remove_node(node)
    playerByConn |> erase(*conn)
    print("[server] connection {*conn} left (base {base} freed)")
}


////////////////////////////////////////////////////////////////////////////////
// command handlers
////////////////////////////////////////////////////////////////////////////////

[net_command_handler]
def private on_move(cmd : MoveState; connection : ConnectionId) {
    let node = avatar_of(connection)
    if (!node.isAlive) { return }
    var ps = get_component(node,type<PlayerServer>)
    var pa = get_component(node,type<PlayerAvatar>)
    if (ps == null || pa == null) { return }
    let t = now()
    let dt = clamp(t-ps.lastMoveAt,0.02,0.5)
    var p = cmd.pos
    // NaN/Inf cannot become authoritative transforms.
    if (!(abs(p.x)<10000.0 && abs(p.y)<10000.0 && abs(p.z)<10000.0 && abs(cmd.yaw)<10000.0)) { return }
    let step = p-ps.lastPos
    let maxStep = MAX_MOVE_SPEED_SERVER*dt+3.0
    if (length(step)>maxStep) { p = ps.lastPos+normalize(step)*maxStep }
    if ((ps.freezeUntil > t || ps.danceUntil > t) && flat_distance(p,ps.lastPos) > .4) { p = ps.lastPos }
    p.x = clamp(p.x, -GROUND_HALF.x + PLAYER_RADIUS, GROUND_HALF.x - PLAYER_RADIUS)
    p.z = clamp(p.z, -GROUND_HALF.y + PLAYER_RADIUS, GROUND_HALF.y - PLAYER_RADIUS)
    // Validate entry to locked bases on the server as well as the local collider.
    for (other in find_components(type<PlayerAvatar>)) {
        if (other.baseIndex >= 0 && other.baseIndex != pa.baseIndex && other.lockRemaining > 0.0 && in_base(other.baseIndex,p,-.8) && !in_base(other.baseIndex,ps.lastPos,-.8)) { p = ps.lastPos }
    }
    if (p.y < FALL_RESET_Y) { p = spawn_pos(pa.baseIndex) }
    if (length(p-cmd.pos)>1.0) { broadcast_net_command(PositionCorrection(pos=p),connection) }
    ps.lastPos = p
    ps.lastMoveAt = t
    node.localPosition = p
    node.localRotation = quat4(0.0,cmd.yaw,0.0)
}

[net_command_handler]
def private on_buy(cmd : BuyRequest; connection : ConnectionId) {
    let node = avatar_of(connection)
    if (!node.isAlive || !cmd.item.isAlive) { return }
    var pa = get_component(node,type<PlayerAvatar>)
    var it = get_component(cmd.item,type<BrainrotItem>)
    if (pa == null || it == null || (it.state != 0 && it.state != 3) || pa.baseIndex < 0 || pa.stunned || pa.dancing || pa.carrying || it.baseIndex == pa.baseIndex) { return }
    if (flat_distance(node.localPosition,cmd.item.localPosition)>BUY_RANGE+2.0 || abs(node.localPosition.y-cmd.item.localPosition.y)>5.0) { return }
    let price = scale_money(item_price(it.defId,it.mutation),1.0+float(it.purchaseCount)*.5)
    if (pa.cash < price) { send_fx(*connection,FX_ERROR,text="Not enough cash!"); return }
    let slot = free_slot(pa.baseIndex)
    if (slot < 0) { send_fx(*connection,FX_ERROR,text="Your base is full!"); return }
    if (it.state == 3) {
        let previous = owner_of_base(it.baseIndex)
        let c = conn_of(previous)
        if (c >= 0) { send_fx(c,FX_ALARM,text="{pa.playerName} bought your delivery! Buy it back before it reaches their base.") }
    }
    pa.cash -= price
    it.state = 3
    it.baseIndex = pa.baseIndex
    it.slot = slot
    it.purchaseCount++
    it.carrierNode = NodeId()
    send_fx(*connection,FX_BUY,cmd.item.localPosition,it.defId,it.mutation,price,"")
}

[net_command_handler]
def private on_collect(cmd : CollectRequest; connection : ConnectionId) {
    let node = avatar_of(connection)
    if (!node.isAlive) {
        return
    }
    var pa = get_component(node, type<PlayerAvatar>)
    if (pa == null || pa.baseIndex < 0 || cmd.slot < 0 || cmd.slot >= SLOTS_PER_BASE) {
        return
    }
    let pad = pad_pos(pa.baseIndex, cmd.slot)
    if (flat_distance(node.localPosition, pad) > COLLECT_RANGE + 3.0 || abs(node.localPosition.y - pad.y) > 6.0) {
        return
    }
    for (it in find_components(type<BrainrotItem>)) {
        if (it.state == 1 && it.baseIndex == pa.baseIndex && it.slot == cmd.slot && it.padCash > 0l) {
            pa.cash += it.padCash
            send_fx(*connection, FX_COLLECT, pad, cmd.slot, 0, it.padCash, "")
            it.padCash = 0l
        }
    }
}

[net_command_handler]
def private on_sell(cmd : SellRequest; connection : ConnectionId) {
    let node = avatar_of(connection)
    if (!node.isAlive) {
        return
    }
    var pa = get_component(node, type<PlayerAvatar>)
    if (pa == null || pa.baseIndex < 0) {
        return
    }
    if (pa.stunned || pa.dancing || pa.carrying || cmd.slot < 0 || cmd.slot >= SLOTS_PER_BASE) { return }
    let pos = slot_pos(pa.baseIndex,cmd.slot)
    if (flat_distance(node.localPosition,pos)>SELL_RANGE+2.0 || abs(node.localPosition.y-pos.y)>5.0) { return }
    for (it in find_components(type<BrainrotItem>)) {
        if (it.state == 1 && it.baseIndex == pa.baseIndex && it.slot == cmd.slot) {
            let value = item_price(it.defId, it.mutation) / int64(2) + it.padCash
            pa.cash += value
            send_fx(*connection, FX_SELL, slot_pos(pa.baseIndex, cmd.slot), 0, 0, value, "")
            remove_node(it.nodeId)
            return
        }
    }
}

[net_command_handler]
def private on_steal_begin(cmd : StealBegin; connection : ConnectionId) {
    let node = avatar_of(connection)
    if (!node.isAlive || !cmd.item.isAlive) {
        return
    }
    var pa = get_component(node, type<PlayerAvatar>)
    var ps = get_component(node, type<PlayerServer>)
    var it = get_component(cmd.item, type<BrainrotItem>)
    if (pa == null || ps == null || it == null) {
        return
    }
    if (it.state != 1 || it.baseIndex == pa.baseIndex || pa.carrying || pa.stunned || pa.dancing) {
        return
    }
    let owner = owner_of_base(it.baseIndex)
    if (!owner.isAlive) {
        return
    }
    var opa = get_component(owner, type<PlayerAvatar>)
    if (opa != null && opa.lockRemaining > 0.0) {
        send_fx(*connection, FX_ERROR, float3(0), 0, 0, 0l, "That base is locked!")
        return
    }
    if (free_slot(pa.baseIndex)<0 || abs(node.localPosition.y-cmd.item.localPosition.y)>5.0 || flat_distance(node.localPosition, cmd.item.localPosition) > STEAL_RANGE + 2.0) {
        return
    }
    ps.stealItem = cmd.item
    ps.stealStartAt = now()
    pa.stealing = true
    let oc = conn_of(owner)
    if (oc >= 0) {
        send_fx(oc, FX_ALARM, cmd.item.localPosition, it.defId, 0, 0l, "{pa.playerName} is stealing your {BRAINROTS[it.defId].name}!")
    }
    all_fx(FX_STEAL_START, cmd.item.localPosition, 0, 0, "")
}

[net_command_handler]
def private on_steal_cancel(cmd : StealCancel; connection : ConnectionId) {
    let node = avatar_of(connection)
    if (!node.isAlive) {
        return
    }
    var pa = get_component(node, type<PlayerAvatar>)
    var ps = get_component(node, type<PlayerServer>)
    if (pa != null && ps != null) {
        pa.stealing = false
        ps.stealStartAt = -100.0
    }
}

[net_command_handler]
def private on_steal_request(cmd : StealRequest; connection : ConnectionId) {
    let node = avatar_of(connection)
    if (!node.isAlive || !cmd.item.isAlive) {
        return
    }
    var pa = get_component(node, type<PlayerAvatar>)
    var ps = get_component(node, type<PlayerServer>)
    var it = get_component(cmd.item, type<BrainrotItem>)
    if (pa == null || ps == null || it == null) {
        return
    }
    pa.stealing = false
    if (ps.stealItem != cmd.item || now() - ps.stealStartAt < STEAL_HOLD_TIME - 0.08) {
        return
    }
    if (it.state != 1 || it.baseIndex == pa.baseIndex || pa.carrying || pa.stunned || pa.dancing) {
        return
    }
    let victimOwner = owner_of_base(it.baseIndex)
    var victimPlayer = get_component(victimOwner,type<PlayerAvatar>)
    if (victimPlayer == null || victimPlayer.lockRemaining > 0.0 || free_slot(pa.baseIndex)<0) { return }
    if (abs(node.localPosition.y-cmd.item.localPosition.y)>5.0 || flat_distance(node.localPosition, cmd.item.localPosition) > STEAL_RANGE + 2.0) {
        return
    }
    let victimBase = it.baseIndex
    let victim = owner_of_base(victimBase)
    it.homeBase = victimBase
    it.homeSlot = it.slot
    it.state = 2
    it.carrierNode = node
    pa.carrying = true
    pa.carryDef = it.defId
    pa.carryMutation = it.mutation
    ps.stealItem = NodeId()
    all_fx(FX_STEAL_DONE, cmd.item.localPosition, it.defId, 0, "")
    let vc = conn_of(victim)
    if (vc >= 0) {
        send_fx(vc, FX_ALARM, cmd.item.localPosition, it.defId, 1, 0l, "{pa.playerName} stole your {BRAINROTS[it.defId].name}!")
    }
}

def private nearest_target_in_front(node : NodeId; yaw : float; maxRange : float; minDot : float) : NodeId {
    let fwd = float3(sin(yaw), 0.0, cos(yaw))
    var best = NodeId()
    var bestDist = 1.0e9
    for (other in find_components(type<PlayerAvatar>)) {
        if (other.nodeId == node) {
            continue
        }
        let to = float3(other.nodeId.localPosition.x - node.localPosition.x, 0.0, other.nodeId.localPosition.z - node.localPosition.z)
        let dist = length(to)
        if (abs(other.nodeId.localPosition.y-node.localPosition.y)>5.0 || dist > maxRange) {
            continue
        }
        if (dist > 1.5 && dot(normalize(to), fwd) < minDot) {
            continue
        }
        if (dist < bestDist) {
            bestDist = dist
            best = other.nodeId
        }
    }
    return best
}

def private do_melee(node : NodeId; var pa : PlayerAvatar?; var ps : PlayerServer?; g : GearDef; yaw : float) {
    pa.swingCount++
    all_fx(FX_BAT_SWING, node.localPosition, 0, 0, "")
    let fwd = float3(sin(yaw), 0.0, cos(yaw))
    for (other in find_components(type<PlayerAvatar>)) {
        if (other.nodeId == node || other.stunned) {
            continue
        }
        var ops = get_component(other.nodeId, type<PlayerServer>)
        if (ops == null) {
            continue
        }
        let to = float3(other.nodeId.localPosition.x - node.localPosition.x, 0.0, other.nodeId.localPosition.z - node.localPosition.z)
        let dist = length(to)
        if (dist > BAT_RANGE || abs(other.nodeId.localPosition.y - node.localPosition.y) > 7.0) {
            continue
        }
        if (dist > 1.5 && dot(normalize(to), fwd) < 0.15) {
            continue
        }
        apply_status(other.nodeId, STATUS_STUN, STUN_TIME)
        let dir = dist > 0.01 ? normalize(to) : fwd
        broadcast_net_command(KnockbackEvent(dir = dir, strength = g.power), ConnectionId(ops.connId))
        all_fx(FX_BAT_HIT, other.nodeId.localPosition, 0, 0, "")
    }
}

[net_command_handler]
def private on_gear_use(cmd : GearUse; connection : ConnectionId) {
    let node = avatar_of(connection)
    if (!node.isAlive) {
        return
    }
    var pa = get_component(node, type<PlayerAvatar>)
    var ps = get_component(node, type<PlayerServer>)
    if (pa == null || ps == null || pa.equipped < 0 || pa.equipped >= gear_count() || !gear_owned(pa.gearMask, pa.equipped) || pa.stunned || pa.dancing || pa.carrying) {
        return
    }
    if (!(abs(cmd.yaw) < 10000.0)) {
        return
    }
    if (now() < ps.useReadyAt) {
        return
    }
    let g = GEARS[pa.equipped]
    let kind = g.kind
    if (kind == int(GearKind.Melee)) {
        ps.useReadyAt = now() + g.cooldown
        do_melee(node, pa, ps, g, cmd.yaw)
    } elif (kind == int(GearKind.Launcher)) {
        ps.useReadyAt = now() + g.cooldown
        let target = nearest_target_in_front(node, cmd.yaw, 60.0, 0.85)
        pa.swingCount++
        if (target.isAlive) {
            apply_status(target, g.status, g.power)
            all_fx(FX_BAT_HIT, target.localPosition, 0, 0, "")
        } else {
            send_fx(*connection, FX_ERROR, float3(0), 0, 0, 0l, "No target in sight!")
        }
    } elif (kind == int(GearKind.Trap)) {
        ps.useReadyAt = now() + g.cooldown
        // keep at most three traps alive per player
        var trapIndex = length(ps.traps) - 1
        while (trapIndex >= 0) {
            if (!ps.traps[trapIndex].isAlive) {
                ps.traps |> erase(trapIndex)
            }
            trapIndex--
        }
        while (length(ps.traps) >= TRAP_MAX_PER_PLAYER) {
            if (ps.traps[0].isAlive) {
                remove_node(ps.traps[0])
            }
            ps.traps |> erase(0)
        }
        let tn = create_node(NodeData(name = "trap", position = node.localPosition))
        add_component(tn, new TrapItem(ownerNode = node, armedAt = now() + TRAP_ARM_DELAY))
        ps.traps |> push(tn)
        pa.gearMask = int(uint(pa.gearMask) & ~(1u << uint(pa.equipped)))
        pa.equipped = 0
        send_fx(*connection, FX_TRAP, node.localPosition, 0, 0, 0l, "Trap placed!")
    } elif (kind == int(GearKind.Cloak)) {
        ps.useReadyAt = now() + g.cooldown
        pa.cloaked = !pa.cloaked
    } elif (kind == int(GearKind.Area)) {
        ps.useReadyAt = now() + g.cooldown
        pa.swingCount++
        for (other in find_components(type<PlayerAvatar>)) {
            if (other.nodeId != node && flat_distance(other.nodeId.localPosition, node.localPosition) <= 25.0) {
                apply_status(other.nodeId, g.status, g.power)
            }
        }
        all_fx(FX_BAT_HIT, node.localPosition, 0, 0, "")
    }
}

[net_command_handler]
def private on_gear_equip(cmd : GearEquip; connection : ConnectionId) {
    let node = avatar_of(connection)
    if (!node.isAlive) {
        return
    }
    var pa = get_component(node, type<PlayerAvatar>)
    if (pa == null) {
        return
    }
    if (cmd.gear < 0) {
        pa.equipped = -1
    } elif (cmd.gear < gear_count() && gear_owned(pa.gearMask, cmd.gear)) {
        pa.equipped = (pa.equipped == cmd.gear) ? -1 : cmd.gear
    }
}

[net_command_handler]
def private on_gear_buy(cmd : GearBuy; connection : ConnectionId) {
    let node = avatar_of(connection)
    if (!node.isAlive || cmd.gear < 0 || cmd.gear >= gear_count()) {
        return
    }
    var pa = get_component(node, type<PlayerAvatar>)
    if (pa == null || gear_owned(pa.gearMask, cmd.gear)) {
        return
    }
    let g = GEARS[cmd.gear]
    if (pa.rebirths < g.rebirth) {
        send_fx(*connection, FX_ERROR, float3(0), 0, 0, 0l, "{g.name} needs rebirth {g.rebirth}!")
        return
    }
    if (pa.cash < g.price) {
        send_fx(*connection, FX_ERROR, float3(0), 0, 0, 0l, "Not enough cash!")
        return
    }
    pa.cash -= g.price
    pa.gearMask = int(uint(pa.gearMask) | (1u << uint(cmd.gear)))
    pa.equipped = cmd.gear
    send_fx(*connection, FX_SHOP, float3(0), cmd.gear, 0, g.price, "{g.name} purchased!")
}

[net_command_handler]
def private on_skin_select(cmd : SkinSelect; connection : ConnectionId) {
    let node = avatar_of(connection)
    if (!node.isAlive) {
        return
    }
    var pa = get_component(node, type<PlayerAvatar>)
    if (pa == null) {
        return
    }
    if (skin_unlocked(pa.discovered, cmd.skin)) {
        pa.skin = cmd.skin
        send_fx(*connection, FX_SKIN, float3(0), cmd.skin, 0, 0l, "{SKINS[cmd.skin].name} base skin equipped!")
    } else {
        send_fx(*connection, FX_ERROR, float3(0), 0, 0, 0l, "Skin locked - fill the Index first!")
    }
}

[net_command_handler]
def private on_lock(cmd : LockRequest; connection : ConnectionId) {
    let node = avatar_of(connection)
    if (!node.isAlive) {
        return
    }
    var pa = get_component(node, type<PlayerAvatar>)
    var ps = get_component(node, type<PlayerServer>)
    if (pa == null || ps == null || pa.baseIndex < 0) {
        return
    }
    if (flat_distance(node.localPosition,lock_pad_pos(pa.baseIndex))>4.5 || abs(node.localPosition.y)>6.0 || pa.stunned || pa.dancing) { return }
    if (now() < ps.lockUntil) {
        return // already locked
    }
    let duration = lock_duration(pa.rebirths)
    ps.lockUntil = now() + duration
    all_fx(FX_LOCK, gate_pos(pa.baseIndex), pa.baseIndex, int(duration), "")
}

[net_command_handler]
def private on_upgrade(cmd : UpgradeRequest; connection : ConnectionId) {
    let node = avatar_of(connection)
    if (!node.isAlive) {
        return
    }
    var pa = get_component(node, type<PlayerAvatar>)
    if (pa == null || pa.baseIndex < 0) {
        return
    }
    if (pa.floors >= 2 || pa.rebirths >= floor_required_rebirths(1)) {
        send_fx(*connection, FX_ERROR, float3(0), 0, 0, 0l, "Your base is fully upgraded!")
        return
    }
    if (flat_distance(node.localPosition,upgrade_pad_pos(pa.baseIndex))>5.0 || abs(node.localPosition.y)>6.0 || pa.stunned || pa.dancing) { return }
    let price = int64(UNLOCK_FLOOR2_PRICE)
    if (pa.cash < price) {
        send_fx(*connection, FX_ERROR, float3(0), 0, 0, 0l, "Upgrade costs {format_cash(price)}!")
        return
    }
    pa.cash -= price
    pa.floors = 2
    send_fx(*connection, FX_SKIN, gate_pos(pa.baseIndex), 0, 0, price, "Base upgraded! Floor 2 unlocked (+8 slots)")
}

[net_command_handler]
def private on_rebirth(cmd : RebirthRequest; connection : ConnectionId) {
    let node = avatar_of(connection)
    if (!node.isAlive) {
        return
    }
    var pa = get_component(node, type<PlayerAvatar>)
    if (pa == null || pa.baseIndex < 0 || pa.rebirths >= MAX_REBIRTHS) {
        return
    }
    let cost = rebirth_cost(pa.rebirths)
    if (pa.cash < cost) {
        send_fx(*connection, FX_ERROR, float3(0), 0, 0, 0l, "Need {format_cash(cost)} to rebirth!")
        return
    }
    if (pa.carrying || pa.stunned || pa.dancing) { return }
    for (i in range(2)) {
        let need = rebirth_required_def(pa.rebirths,i)
        var found = false
        for (item in find_components(type<BrainrotItem>)) { if (item.state == 1 && item.baseIndex == pa.baseIndex && item.defId == need) { found = true } }
        if (!found) { send_fx(*connection,FX_ERROR,text="Need {BRAINROTS[need].name} in your base!"); return }
    }
    for (it in find_components(type<BrainrotItem>)) {
        if ((it.state == 1 || it.state == 3) && it.baseIndex == pa.baseIndex) {
            remove_node(it.nodeId)
        } elif (it.state == 2 && it.homeBase == pa.baseIndex) {
            var thief = get_component(it.carrierNode,type<PlayerAvatar>)
            if (thief != null) { thief.carrying = false; thief.carryDef = -1 }
            remove_node(it.nodeId)
        }
    }
    pa.cash = 5000l
    pa.rebirths++
    pa.incomePerSec = 0l
    send_fx(*connection, FX_REBIRTH, float3(0), pa.rebirths, 0, 0l, "REBIRTH {pa.rebirths}! Income x{income_multiplier(pa.rebirths)}")
}


[net_command_handler]
def private on_debug(cmd : DebugCommand; connection : ConnectionId) {
    if (!DEBUG_CHEATS) {
        return
    }
    let node = avatar_of(connection)
    if (!node.isAlive) {
        return
    }
    var pa = get_component(node, type<PlayerAvatar>)
    if (pa == null) {
        return
    }
    if (cmd.kind == 1) {
        pa.cash += cmd.amount
    } elif (cmd.kind == 2) {
        pa.rebirths = clamp(int(cmd.amount), 0, MAX_REBIRTHS)
    } elif (cmd.kind == 3) {
        pa.discovered |> resize(index_size())
        for (i in range(index_size())) {
            pa.discovered[i] = uint8(1)
        }
    } elif (cmd.kind == 5 && pa.baseIndex >= 0 && cmd.amount >= 0l && cmd.amount < int64(brainrot_count())) {
        let slot = free_slot(pa.baseIndex)
        if (slot >= 0) {
            let item = new_item(int(cmd.amount), 0, slot_pos(pa.baseIndex, slot))
            var component = get_component(item, type<BrainrotItem>)
            place_in_slot(component, pa.baseIndex, slot)
        }
    }
}

////////////////////////////////////////////////////////////////////////////////
// per-frame simulation
////////////////////////////////////////////////////////////////////////////////

def private tick_conveyor(dt : float) {
    spawnTimer -= dt
    var count = 0
    for (it in find_components(type<BrainrotItem>)) {
        if (it.state != 0) {
            continue
        }
        count++
        var p = it.nodeId.localPosition
        p.z += CONVEYOR_SPEED * dt
        it.nodeId.localPosition = p
        if (p.z > CONVEYOR_HALF_LENGTH) {
            remove_node(it.nodeId)
        }
    }
    if (spawnTimer <= 0.0 && count < CONVEYOR_MAX_ITEMS && length(playerByConn) > 0) {
        spawnTimer = CONVEYOR_SPAWN_INTERVAL
        let defId = pick_brainrot_def(random_float(), random_float(), thunder_rare_multiplier())
        let mut = pick_mutation(random_float())
        let x = 0.0
        new_item(defId, mut, float3(x, 0.4, -CONVEYOR_HALF_LENGTH))
        // Mythic and above are announced to everyone, like on the red carpet
        if (BRAINROTS[defId].rarity >= 3) {
            all_fx(FX_RARE_SPAWN, float3(0), defId, mut, "{RARITY_NAMES[BRAINROTS[defId].rarity]}: {BRAINROTS[defId].name} is on the red carpet!")
        }
    }
}

def private tick_income(dt : float) {
    incomeTimer += dt
    if (incomeTimer < INCOME_TICK) {
        return
    }
    let step = incomeTimer
    incomeTimer = 0.0
    for (pa in find_components(type<PlayerAvatar>)) {
        pa.incomePerSec = 0l
    }
    for (it in find_components(type<BrainrotItem>)) {
        if (it.state != 1) {
            continue
        }
        let owner = owner_of_base(it.baseIndex)
        if (!owner.isAlive) {
            continue
        }
        var pa = get_component(owner, type<PlayerAvatar>)
        let perSec = scale_money(item_income(it.defId, it.mutation), income_multiplier(pa.rebirths) + index_cash_bonus(pa.discovered))
        pa.incomePerSec += perSec
        let cap = scale_money(perSec, PAD_CAPACITY_SECONDS)
        it.padCash = min(it.padCash + scale_money(perSec, step), cap)
    }
}

def private tick_traps() {
    let t = now()
    for (trap in find_components(type<TrapItem>)) {
        if (t < trap.armedAt) {
            continue
        }
        trap.armed = true
        for (pa in find_components(type<PlayerAvatar>)) {
            if (pa.nodeId == trap.ownerNode || pa.stunned) {
                continue
            }
            if (flat_distance(pa.nodeId.localPosition, trap.nodeId.localPosition) < TRAP_TRIGGER_RADIUS && abs(pa.nodeId.localPosition.y - trap.nodeId.localPosition.y) < TRAP_TRIGGER_RADIUS) {
                apply_status(pa.nodeId, STATUS_FREEZE, GEARS[2].power)
                all_fx(FX_TRAP, trap.nodeId.localPosition, 1, 0, "")
                remove_node(trap.nodeId)
                break
            }
        }
    }
}

def private tick_players(dt : float) {
    let t = now()
    for (pa in find_components(type<PlayerAvatar>)) {
        var ps = get_component(pa.nodeId, type<PlayerServer>)
        if (ps == null) {
            continue
        }
        if ((pa.stunned || ps.stunUntil > 0.0) && t >= ps.stunUntil) {
            pa.stunned = false
            ps.stunUntil = 0.0
        }
        if (pa.dancing && t >= ps.danceUntil) {
            pa.dancing = false
        }
        pa.lockRemaining = max(ps.lockUntil - t, 0.0)
        pa.lockCooldown = max(ps.lockReadyAt - t, 0.0)
        if (pa.carrying) {
            var it = carried_item_of(pa.nodeId)
            if (it == null) {
                pa.carrying = false
                pa.carryDef = -1
            } else {
                let p = pa.nodeId.localPosition
                it.nodeId.localPosition = float3(p.x, p.y + CARRY_BASE_HEIGHT, p.z)
                it.nodeId.localRotation = pa.nodeId.localRotation
                // arriving home delivers the brainrot
                if (pa.baseIndex >= 0 && in_base(pa.baseIndex, p, -1.0)) {
                    let slot = free_slot(pa.baseIndex)
                    if (slot >= 0) {
                        let defId = it.defId
                        place_in_slot(it, pa.baseIndex, slot)
                        pa.steals++
                        pa.carrying = false
                        pa.carryDef = -1
                        send_fx(ps.connId, FX_DELIVER, slot_pos(pa.baseIndex, slot), defId, 0, 0l, "Stolen {BRAINROTS[defId].name} added to your base!")
                        all_fx(FX_DELIVER, slot_pos(pa.baseIndex, slot), 0, 0, "")
                    }
                }
            }
        }
        if (pa.stealing) {
            if (!ps.stealItem.isAlive || flat_distance(pa.nodeId.localPosition, ps.stealItem.localPosition) > STEAL_RANGE + 6.0) {
                pa.stealing = false
            }
        }
    }
}


def private tick_deliveries(dt : float) {
    for (it in find_components(type<BrainrotItem>)) {
        if (it.state != 3) { continue }
        if (!owner_of_base(it.baseIndex).isAlive) { remove_node(it.nodeId); continue }
        var p = it.nodeId.localPosition
        var goal = gate_pos(it.baseIndex)
        goal.y = .4
        let delta = goal-p
        let dist = length(delta)
        if (dist <= CONVEYOR_SPEED*dt+1.0) {
            let bi = it.baseIndex
            let slot = it.slot
            place_in_slot(it,bi,slot)
            all_fx(FX_DELIVER,slot_pos(bi,slot))
        } else {
            p += normalize(delta)*CONVEYOR_SPEED*dt
            it.nodeId.localPosition = p
            it.nodeId.localRotation = quat4(0.0,atan2(delta.x,delta.z),0.0)
        }
    }
}

[net_command_handler]
def private on_fuse(cmd : FuseRequest; connection : ConnectionId) {
    let node = avatar_of(connection)
    var pa = get_component(node,type<PlayerAvatar>)
    if (pa == null || pa.carrying || pa.stunned || pa.dancing || flat_distance(node.localPosition,station_pos(STATION_FUSE))>STATION_RANGE+2.0 || abs(node.localPosition.y)>5.0) { return }
    var selected : array<NodeId>
    var total = 0l
    var rarity = 0
    var mutation = -1
    var same = true
    for (it in find_components(type<BrainrotItem>)) {
        if (it.state == 1 && it.baseIndex == pa.baseIndex && it.slot >= 0 && (cmd.slots & (1u<<uint(it.slot)))!=0u) {
            selected |> push(it.nodeId)
            total += item_price(it.defId,it.mutation)
            rarity = max(rarity,BRAINROTS[it.defId].rarity)
            if (mutation < 0) { mutation = it.mutation } else { same = same && mutation == it.mutation }
        }
    }
    let fee = total/10l
    if (rarity >= 6) { send_fx(*connection,FX_ERROR,text="Secret and OG brainrots cannot be fused."); return }
    if (length(selected)!=3 || pa.cash<fee) { send_fx(*connection,FX_ERROR,text="Choose exactly 3 brainrots and cover the fuse fee."); return }
    var candidates : array<int>
    let target = min(rarity+1,7)
    for (i in range(brainrot_count())) { if (BRAINROTS[i].rarity==target) { candidates |> push(i) } }
    if (empty(candidates)) { return }
    let output = candidates[min(int(random_float()*float(length(candidates))),length(candidates)-1)]
    for (n in selected) { remove_node(n) }
    pa.cash -= fee
    let slot = free_slot(pa.baseIndex)
    let newNode = new_item(output,same ? mutation : 0,slot_pos(pa.baseIndex,slot))
    var item = get_component(newNode,type<BrainrotItem>)
    place_in_slot(item,pa.baseIndex,slot)
    send_fx(*connection,FX_DISCOVER,a=output,b=item.mutation,text="Fused: {BRAINROTS[output].name}!")
}

def public server_update(dt : float) {
    tick_conveyor(dt)
    tick_deliveries(dt)
    saveTimer += dt
    if (saveTimer >= 5.0) { saveTimer = 0.0; server_save() }
    tick_income(dt)
    tick_players(dt)
    tick_traps()
}


[net_command_handler]
def private on_thunder_start(cmd : ThunderStart; connection : ConnectionId) {
    if (!has_network() || !is_server()) {
        return
    }
    let node = avatar_of(connection)
    var player = get_component(node, type<PlayerAvatar>)
    var serverPlayer = get_component(node, type<PlayerServer>)
    if (player == null || serverPlayer == null) {
        return
    }
    // Authenticate the sender through its server-owned avatar, never its name.
    // The room's first player controls development events; guests cannot start them.
    if (player.baseIndex != 0) {
        send_fx(*connection, FX_ERROR, text = "Thunder cheat is available to the room host only.")
        return
    }
    start_thunder_server()
}
