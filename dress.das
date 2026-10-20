require engine.core
require engine.networking
require constants
require layout
require brainrot_data
require gear_data
require skin_data
require components
require net_commands
require game_state
require avatar
require player
require items_view
require ui
require constants


var private {
    padLast : string[176]
    titleLast : string[176]
    lockPadLast : string[8]
    upgradePadLast : string[8]
    standLast : string[176]
    padLit : bool[176]
    standShown : int[176] // -1 unknown, 0 hidden, 1 visible
    signLast : string[8]
    lockLast : string[8]
    skinLast : int[8]
    ownerRebirth : int[8]
    barrierLast : int[8]
    gateLast : bool[8]
    lastSwing : table<uint64; int>
    moveTimer : float = 0.0
    localSwingSeen : int = 0
    rainbowT : float = 0.0
}


def public reset_dress_state() {
    for (i in range(176)) {
        padLast[i] = ""
        titleLast[i] = "?"
        standLast[i] = ""
        padLit[i] = false
        standShown[i] = -1
    }
    for (i in range(8)) {
        lockPadLast[i] = "?"
        upgradePadLast[i] = "?"
        signLast[i] = ""
        lockLast[i] = ""
        skinLast[i] = -1
        ownerRebirth[i] = -1
        gateLast[i] = false
    }
    for (i in range(8)) {
        barrierLast[i] = -1
    }
    lastSwing |> clear()
    localSwingSeen = 0
    moveTimer = 0.0
}


////////////////////////////////////////////////////////////////////////////////
// brainrot items
////////////////////////////////////////////////////////////////////////////////

def public update_items() {
    for (it in find_components(type<BrainrotItem>)) {
        if (!has_component(it.nodeId, type<ItemView>)) {
            add_component(it.nodeId, new ItemView())
            set_mirror_interpolation(it.nodeId, true)
        }
    }
}


////////////////////////////////////////////////////////////////////////////////
// players
////////////////////////////////////////////////////////////////////////////////

def private gear_speed_factor(pa : PlayerAvatar?) : float {
    var f = 1.0
    if (pa.equipped >= 0) {
        let kind = GEARS[pa.equipped].kind
        if (kind == int(GearKind.SpeedCoil) || kind == int(GearKind.ComboCoil)) {
            f = COIL_SPEED_FACTOR
        }
    }
    if (pa.cloaked) {
        f *= 2.0
    }
    return f
}

def private gear_gravity_factor(pa : PlayerAvatar?) : float {
    var f = 1.0
    if (pa.equipped >= 0) {
        let kind = GEARS[pa.equipped].kind
        if (kind == int(GearKind.GravityCoil) || kind == int(GearKind.ComboCoil)) {
            f = COIL_GRAVITY_FACTOR
        }
    }
    return f
}

def private apply_avatar_flags(var view : AvatarView?; pa : PlayerAvatar?; isLocal : bool) {
    view.carrying = pa.carrying
    view.stunned = pa.stunned
    view.dancing = pa.dancing
    view.cloaked = pa.cloaked
    view.isLocal = isLocal
    view.playerName = pa.playerName
    view.heldGear = pa.equipped
}

def private handle_local_avatar(pa : PlayerAvatar?) {
    localAvatar = pa.nodeId
    if (!localPlayer.isAlive) {
        if (pa.baseIndex < 0) {
            return
        }
        localBase = pa.baseIndex
        spawn_local_player(spawn_pos(pa.baseIndex), PLAYER_COLORS[pa.colorIdx % length(PLAYER_COLORS)], pa.playerName)
        cameraYaw = base_dir(pa.baseIndex) > 0.0 ? PI * 0.5 : -PI * 0.5
        localPlayer.localRotation = quat4(0.0, cameraYaw, 0.0)
        localSwingSeen = pa.swingCount
        return
    }
    localBase = pa.baseIndex
    var lp = get_component(localPlayer, type<LocalPlayer>)
    if (lp != null) {
        lp.speedFactor = gear_speed_factor(pa)
        lp.gravityFactor = gear_gravity_factor(pa)
        lp.carrying = pa.carrying
        if (pa.stunned && !localStunned) {
            lp.stunTimer = max(lp.stunTimer, STUN_TIME)
        }
    }
    localStunned = pa.stunned
    localCarrying = pa.carrying
    var view = get_component(localPlayer, type<AvatarView>)
    if (view != null) {
        apply_avatar_flags(view, pa, true)
        if (pa.swingCount != localSwingSeen) {
            localSwingSeen = pa.swingCount
            view.swing()
        }
    }
}

def private handle_remote_avatar(pa : PlayerAvatar?) {
    let node = pa.nodeId
    if (!has_component(node, type<AvatarView>)) {
        add_component(node, new AvatarView(color = PLAYER_COLORS[pa.colorIdx % length(PLAYER_COLORS)], playerName = pa.playerName))
        set_mirror_interpolation(node, true)
    }
    var view = get_component(node, type<AvatarView>)
    if (view == null) {
        return
    }
    apply_avatar_flags(view, pa, false)
    let key = uint64(node)
    let seen = lastSwing?[key] ?? pa.swingCount
    if (seen != pa.swingCount) {
        view.swing()
    }
    lastSwing[key] = pa.swingCount
}

def public update_avatars() {
    for (pa in find_components(type<PlayerAvatar>)) {
        if (is_node_owner(pa.nodeId)) {
            handle_local_avatar(pa)
        } else {
            handle_remote_avatar(pa)
        }
    }
}

// the owning client reports where its character is; the server validates and replicates it
def public send_move_state(dt : float) {
    if (!localPlayer.isAlive || !has_network()) {
        return
    }
    moveTimer += dt
    if (moveTimer < 1.0 / MOVE_SEND_HZ) {
        return
    }
    moveTimer = 0.0
    let fwd = localPlayer.worldRotation * float3(0.0, 0.0, 1.0)
    broadcast_net_command(MoveState(pos = localPlayer.worldPosition, yaw = atan2(fwd.x, fwd.z), grounded = true))
}


////////////////////////////////////////////////////////////////////////////////
// bases: signs, skins, lasers, floor barriers, pedestals, pad labels
////////////////////////////////////////////////////////////////////////////////

def private hue(t : float) : float4 {
    return float4(0.55 + 0.45 * sin(t), 0.55 + 0.45 * sin(t + 2.094), 0.55 + 0.45 * sin(t + 4.188), 1.0)
}

def private paint(nodes : array<NodeId>; col : float4) {
    for (n in nodes) {
        n?.Mesh.color = col
        for (child in n.get_children()) {
            if (child.name == "studs") {
                child?.Mesh.color = col
            }
        }
    }
}

def private apply_skin(b : int; skinIdx : int; colorIdx : int) {
    let s = SKINS[clamp(skinIdx, 0, skin_count() - 1)]
    let trim = s.trim.w < 0.5 ? PLAYER_COLORS[colorIdx % length(PLAYER_COLORS)] : s.trim
    paint(baseParts[b].walls, s.wall)
    for (wall in baseParts[b].walls) {
        wall?.Mesh.materialId = skinIdx == EDEN_SKIN_INDEX ? edenSurfaceMaterial : basePlasticMaterial
        for (child in wall.get_children()) {
            if (child.name == "studs") {
                child?.Mesh.materialId = skinIdx == EDEN_SKIN_INDEX ? edenSurfaceMaterial : baseStudMaterial
            }
        }
    }
    paint(baseParts[b].floors, s.floorCol)
    paint(baseParts[b].aisles, s.aisle)
    paint(baseParts[b].trims, trim)
    paint(baseParts[b].stands, s.accent)
    baseParts[b].edenDetail.isActive = skinIdx == EDEN_SKIN_INDEX
}

def public update_bases() {
    if (length(baseParts) < 8) {
        return
    }
    rainbowT += get_delta_time() * 2.0
    var ownerName : string[8]
    var ownerColor : int[8]
    var ownerLock : float[8]
    var ownerSkin : int[8]
    var ownerRebirths : int[8]
    var ownerCooldown : float[8]
    var ownerUpgraded : bool[8]
    var ownerBonus : float[8]
    for (b in range(8)) {
        ownerName[b] = ""
        ownerColor[b] = b
        ownerLock[b] = 0.0
        ownerSkin[b] = 0
        ownerRebirths[b] = 0
        ownerCooldown[b] = 0.0
        ownerUpgraded[b] = false
    }
    for (pa in find_components(type<PlayerAvatar>)) {
        if (pa.baseIndex >= 0 && pa.baseIndex < 8) {
            ownerName[pa.baseIndex] = pa.playerName
            ownerColor[pa.baseIndex] = pa.colorIdx
            ownerLock[pa.baseIndex] = pa.lockRemaining
            ownerCooldown[pa.baseIndex] = pa.lockCooldown
            ownerSkin[pa.baseIndex] = pa.skin
            ownerRebirths[pa.baseIndex] = pa.rebirths
            ownerBonus[pa.baseIndex] = index_cash_bonus(pa.discovered)
            ownerUpgraded[pa.baseIndex] = pa.floors >= 2 || pa.rebirths >= floor_required_rebirths(1)
        }
    }
    for (b in range(8)) {
        let title = empty(ownerName[b]) ? "Free Base" : "{ownerName[b]}'s Base"
        if (title != signLast[b]) {
            signLast[b] = title
            baseSigns[b]?.UIText.text = title
        }
        let skinKey = ownerSkin[b] * 16 + ownerColor[b]
        if (skinKey != skinLast[b]) {
            skinLast[b] = skinKey
            apply_skin(b, ownerSkin[b], ownerColor[b])
        }
        if (SKINS[clamp(ownerSkin[b], 0, skin_count() - 1)].rainbow) {
            paint(baseParts[b].trims, hue(rainbowT + float(b)))
        }
        let locked = ownerLock[b] > 0.0
        if (locked != gateLast[b]) {
            gateLast[b] = locked
            gateRoots[b].isActive = locked
        }
        // only intruders are stopped by the lasers
        gateBlockers[b].isActive = locked && b != localBase
        for (gate in baseParts[b].floorGates) {
            gate.isActive = locked
        }
        for (blocker in baseParts[b].floorGateBlockers) {
            blocker.isActive = locked && b != localBase
        }
        let lockMsg = locked ? "LOCKED {int(ownerLock[b]) + 1}s" : (empty(ownerName[b]) ? "" : "UNLOCKED")
        if (lockMsg != lockLast[b]) {
            lockLast[b] = lockMsg
            baseLockTexts[b]?.UIText.text = lockMsg
            baseLockTexts[b]?.UIText.color = locked ? float4(1.0, 0.3, 0.3, 1.0) : float4(0.4, 1.0, 0.5, 1.0)
        }
        // the whole upper storey (with the outside staircase) only exists after the owner upgrades the base
        let open = ownerUpgraded[b] && !empty(ownerName[b]) ? 1 : 0
        if (open != barrierLast[b]) {
            barrierLast[b] = open
            upperRoots[b].isActive = open == 1
            lowRoofs[b].isActive = open == 0
        }
        // text above the lock and upgrade pads
        var lockPad = "Lock Base"
        if (locked) {
            lockPad = "Locked\n{int(ownerLock[b]) + 1}s"
        }
        if (lockPad != lockPadLast[b]) {
            lockPadLast[b] = lockPad
            lockPadTexts[b]?.Text3D.text = lockPad
        }
        let upPad = ownerUpgraded[b] ? "Base maxed" : "Upgrade Base\n{format_cash(int64(UNLOCK_FLOOR2_PRICE))}"
        if (upPad != upgradePadLast[b]) {
            upgradePadLast[b] = upPad
            upgradePadTexts[b]?.Text3D.text = upPad
        }
        baseMultiTexts[b]?.Text3D.text = "CASH MULTI: x{income_multiplier(ownerRebirths[b])+ownerBonus[b]}"
        thirdRoots[b].isActive = open == 1 && ownerRebirths[b] >= 10
        secondRoofs[b].isActive = ownerRebirths[b] < 10
        ownerRebirth[b] = ownerRebirths[b]
    }

    var occupied : bool[176]
    var cashAt : int64[176]
    for (it in find_components(type<BrainrotItem>)) {
        if (it.state == 1 && it.baseIndex >= 0 && it.baseIndex < 8 && it.slot >= 0 && it.slot < SLOTS_PER_BASE) {
            let idx = it.baseIndex * SLOTS_PER_BASE + it.slot
            occupied[idx] = true
            cashAt[idx] = it.padCash
        }
    }
    for (idx in range(176)) {
        let b = idx / SLOTS_PER_BASE
        let slot = idx % SLOTS_PER_BASE
        // pedestals and pads of locked storeys disappear
        let shown = slot_floor(slot) == 0 || (slot_floor(slot) == 1 && ownerUpgraded[b] && !empty(ownerName[b])) || (slot_floor(slot) == 2 && ownerRebirths[b] >= 10 && !empty(ownerName[b])) ? 1 : 0
        if (shown != standShown[idx]) {
            standShown[idx] = shown
            standNodes[idx].isActive = shown == 1
            padNodes[idx].isActive = shown == 1
            standTexts[idx].isActive = shown == 1
            padTexts[idx].isActive = shown == 1
            padTitles[idx].isActive = shown == 1
        }
        let titleMsg = occupied[idx] ? "Collect" : ""
        if (titleMsg != titleLast[idx]) {
            titleLast[idx] = titleMsg
            padTitles[idx]?.Text3D.text = titleMsg
        }
        let standMsg = occupied[idx] ? "" : "Empty"
        if (standMsg != standLast[idx]) {
            standLast[idx] = standMsg
            standTexts[idx]?.Text3D.text = standMsg
        }
        let padMsg = cashAt[idx] > 0l ? format_cash(cashAt[idx]) : (occupied[idx] ? "$0" : "")
        if (padMsg != padLast[idx]) {
            padLast[idx] = padMsg
            padTexts[idx]?.Text3D.text = padMsg
        }
        let lit = cashAt[idx] > 0l
        if (lit != padLit[idx]) {
            padLit[idx] = lit
            padNodes[idx]?.Mesh.color = lit ? float4(0.35, 1.0, 0.45, 1.0) : float4(0.14, 0.45, 0.20, 1.0)
        }
    }
}
