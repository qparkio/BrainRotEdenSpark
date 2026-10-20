require engine.core
require engine.networking
require constants
require layout
require brainrot_data
require gear_data
require components
require net_commands
require game_state
require player
require ui
require sounds


var private {
    lockPadArmed : bool = true
    holdTime : float = 0.0
    holdItem : NodeId
    collectCooldown : float = 0.0
    useCooldown : float = 0.0
    buyCooldown : float = 0.0
}


def private cancel_steal {
    if (holdItem.isAlive) {
        broadcast_net_command(StealCancel(dummy = 0))
    }
    holdItem = NodeId()
    holdTime = 0.0
}

def private handle_hotbar(pa : PlayerAvatar?) {
    let keys = fixed_array("slot1", "slot2", "slot3", "slot4", "slot5", "slot6", "slot7", "slot8", "slot9")
    for (i in range(9)) {
        if (is_action_just_pressed(keys[i])) {
            let g = hotbar_gear(i)
            if (g >= 0) {
                broadcast_net_command(GearEquip(gear = g))
                play_sfx("click", 0.5)
            }
        }
    }
}

// left click / F: use whatever is in hand (slap swing, launcher shot, trap, cloak, bomb)
def private handle_gear_use(pa : PlayerAvatar?; dt : float) {
    useCooldown = max(0.0, useCooldown - dt)
    let keyboardUse = has_action("gearUse") && is_action_just_pressed("gearUse")
    let mouseUse = is_action_just_pressed("swing") && !ui_click_blocks_gear()
    if (pa.equipped < 0 || pa.stunned || pa.dancing || useCooldown > 0.0 || (!keyboardUse && !mouseUse)) {
        return
    }
    let g = GEARS[pa.equipped]
    let kind = g.kind
    if (kind == int(GearKind.SpeedCoil) || kind == int(GearKind.GravityCoil) || kind == int(GearKind.ComboCoil)) {
        return
    }
    if (pa.carrying && kind == int(GearKind.Melee)) {
        return
    }
    useCooldown = max(g.cooldown, 0.2)
    let fwd = localPlayer.worldRotation * float3(0.0, 0.0, 1.0)
    broadcast_net_command(GearUse(yaw = atan2(fwd.x, fwd.z)))
}

def private handle_collect(pa : PlayerAvatar?; dt : float; padCash : int64[22]) {
    collectCooldown = max(0.0, collectCooldown - dt)
    if (collectCooldown > 0.0 || localBase < 0) {
        return
    }
    let me = localPlayer.worldPosition
    for (s in range(SLOTS_PER_BASE)) {
        let pad = pad_pos(localBase, s)
        if (padCash[s] > 0l && flat_distance(me, pad) <= COLLECT_RANGE && abs(me.y - pad.y) < 4.0) {
            broadcast_net_command(CollectRequest(slot = s))
            collectCooldown = 0.5
            return
        }
    }
}

def private nearest_station(me : float3) : int {
    var best = -1
    var bestDist = STATION_RANGE
    for (i in range(STATION_COUNT)) {
        let d = flat_distance(me, station_pos(i))
        if (d < bestDist) {
            bestDist = d
            best = i
        }
    }
    return best
}

def private open_station(i : int) {
    if (i == STATION_SHOP) {
        open_window(int(Window.Shop))
    } elif (i == STATION_FUSE) {
        open_window(int(Window.Fuse))
        play_sfx("orig_craft", 0.8)
    }
}

// Editor smoke tests use the same request and range rules as the keyboard action.
def public attempt_buy_nearest {
    if (!localPlayer.isAlive || !localAvatar.isAlive || windows_open()) {
        return
    }
    let player = get_component(localAvatar, type<PlayerAvatar>)
    if (player == null || player.carrying || player.stunned || player.dancing) {
        return
    }
    var nearest = NodeId()
    var bestDistance = BUY_RANGE
    for (item in find_components(type<BrainrotItem>)) {
        let distance = flat_distance(localPlayer.worldPosition, item.nodeId.worldPosition)
        if ((item.state == 0 || (item.state == 3 && item.baseIndex != localBase)) && distance <= bestDistance && abs(localPlayer.worldPosition.y - item.nodeId.worldPosition.y) < 5.0) {
            nearest = item.nodeId
            bestDistance = distance
        }
    }
    if (nearest.isAlive) {
        broadcast_net_command(BuyRequest(item = nearest))
    }
}


def public update_interaction(dt : float) {
    if (!localPlayer.isAlive || !localAvatar.isAlive) {
        return
    }
    var pa = get_component(localAvatar, type<PlayerAvatar>)
    if (pa == null) {
        return
    }
    buyCooldown = max(0.0, buyCooldown - dt)
    if (windows_open() || chatTyping) {
        cancel_steal()
        set_prompt("")
        return
    }
    handle_hotbar(pa)
    if (pa.stunned || pa.dancing) {
        cancel_steal()
        set_prompt("")
        return
    }
    handle_gear_use(pa, dt)

    // gather what is in reach this frame
    let me = localPlayer.worldPosition
    var locks : float[8]
    for (a in find_components(type<PlayerAvatar>)) {
        if (a.baseIndex >= 0 && a.baseIndex < 8) {
            locks[a.baseIndex] = a.lockRemaining
        }
    }
    var padCash : int64[22]
    var buyItem = NodeId()
    var buyDist = 1.0e9
    var buyDef = 0
    var buyMut = 0
    var stealItem = NodeId()
    var stealDist = 1.0e9
    var stealDef = 0
    var sellSlot = -1
    var sellDef = 0
    var sellMut = 0
    var sellValue = 0l
    var sellDist = SELL_RANGE
    for (it in find_components(type<BrainrotItem>)) {
        let d = flat_distance(me, it.nodeId.worldPosition)
        if ((it.state == 0 || (it.state == 3 && it.baseIndex != localBase)) && abs(me.y-it.nodeId.worldPosition.y)<5.0 && d <= BUY_RANGE && d < buyDist) {
            buyDist = d
            buyItem = it.nodeId
            buyDef = it.defId
            buyMut = it.mutation
        } elif (it.state == 1) {
            if (it.baseIndex == localBase && it.slot >= 0 && it.slot < SLOTS_PER_BASE) {
                padCash[it.slot] = it.padCash
                if (d < sellDist && abs(me.y-it.nodeId.worldPosition.y)<5.0) {
                    sellSlot = it.slot
                    sellDef = it.defId
                    sellMut = it.mutation
                    sellValue = item_price(it.defId,it.mutation)/2l+it.padCash
                    sellDist = d
                }
            } elif (it.baseIndex != localBase && !pa.carrying && d <= STEAL_RANGE && abs(me.y - it.nodeId.worldPosition.y) < 5.0 && d < stealDist && locks[it.baseIndex] <= 0.0) {
                stealDist = d
                stealItem = it.nodeId
                stealDef = it.defId
            }
        }
    }
    handle_collect(pa, dt, padCash)

    // The owner's pedestal takes priority over a passing conveyor item.
    if (sellSlot >= 0 && !pa.carrying) {
        cancel_steal()
        set_prompt("[E] Sell {BRAINROTS[sellDef].name}  {format_cash(sellValue)}")
        if (is_action_just_pressed("interact")) {
            show_sell(sellSlot, sellDef, sellMut, sellValue)
        }
        return
    }

    if (stealItem.isAlive) {
        let name = BRAINROTS[stealDef].name
        if (is_action_pressed("interact")) {
            if (holdItem != stealItem) {
                cancel_steal()
                holdItem = stealItem
                holdTime = 0.0
                broadcast_net_command(StealBegin(item = stealItem))
            }
            holdTime += dt
            set_prompt("Stealing {name}...", holdTime / STEAL_HOLD_TIME, float4(1.0, 0.6, 0.3, 1.0))
            if (holdTime >= STEAL_HOLD_TIME) {
                broadcast_net_command(StealRequest(item = holdItem))
                holdItem = NodeId()
                holdTime = 0.0
            }
        } else {
            cancel_steal()
            set_prompt("Hold [E] to steal {name}", -1.0, float4(1.0, 0.85, 0.3, 1.0))
        }
        return
    }
    cancel_steal()
    if (buyItem.isAlive) {
        var targetItem = get_component(buyItem,type<BrainrotItem>)
        let price = scale_money(item_price(buyDef, buyMut),1.0+float(targetItem.purchaseCount)*.5)
        let canBuy = pa.cash >= price
        let mutName = MUTATION_NAMES[buyMut]
        let title = empty(mutName) ? BRAINROTS[buyDef].name : "{mutName} {BRAINROTS[buyDef].name}"
        set_prompt("[E] Buy {title}  {format_cash(price)}", -1.0, canBuy ? float4(0.5, 1.0, 0.6, 1.0) : float4(1.0, 0.45, 0.45, 1.0))
        if (is_action_just_pressed("interact") && buyCooldown <= 0.0) {
            buyCooldown = 0.25
            broadcast_net_command(BuyRequest(item = buyItem))
        }
        return
    }
    let st = nearest_station(me)
    if (st >= 0) {
        set_prompt("[E] {STATION_NAMES[st]}", -1.0, float4(0.7, 0.9, 1.0, 1.0))
        if (is_action_just_pressed("interact")) {
            open_station(st)
        }
        return
    }
    // the lock and upgrade pads inside the player's own base
    if (localBase >= 0 && me.y < 4.0) {
        if (flat_distance(me, lock_pad_pos(localBase)) < 2.6) {
            // stepping on the yellow pad locks the base right away, no button and no cooldown
            if (pa.lockRemaining > 0.0) {
                set_prompt("Base locked  {int(pa.lockRemaining) + 1}s", -1.0, float4(1.0, 0.5, 0.4, 1.0))
            } else {
                set_prompt("Base locked for {int(lock_duration(pa.rebirths))}s!", -1.0, float4(1.0, 0.9, 0.4, 1.0))
                if (lockPadArmed) {
                    lockPadArmed = false
                    broadcast_net_command(LockRequest(dummy = 0))
                    play_sfx("lock", 0.7)
                }
            }
            return
        }
        lockPadArmed = true
        if (flat_distance(me, upgrade_pad_pos(localBase)) < 2.8) {
            set_prompt("[E] Upgrade Base  {format_cash(int64(UNLOCK_FLOOR2_PRICE))}", -1.0, float4(0.8, 0.6, 1.0, 1.0))
            if (is_action_just_pressed("interact")) {
                broadcast_net_command(UpgradeRequest(dummy = 0))
            }
            return
        }
    }
    set_prompt("")
}
