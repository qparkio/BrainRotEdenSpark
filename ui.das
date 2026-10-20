require engine.core
require engine.networking
require engine.ui.fast_ui
require constants
require layout
require brainrot_data
require gear_data
require skin_data
require components
require net_commands
require game_state
require sounds
require ui_assets


struct Toast {
    node : NodeId
    ttl : float
    color : float4
}

enum public Window {
    None = 0
    Shop = 1
    Index = 2
    Rebirth = 3
    Skins = 4
    Settings = 5
    Inventory = 6
    Fuse = 7
    Sell = 8
    Help = 9
    Contact = 10
}

let private {
    HUD_W = 1920.0
    HUD_H = 1080.0
    COL_PANEL = float4(0.16, 0.19, 0.24, 0.97)
    COL_CARD = float4(0.27, 0.31, 0.37, 1.0)
    COL_BTN_GREEN = float4(0.20, 0.78, 0.30, 1.0)
    COL_BTN_BLUE = float4(0.25, 0.55, 1.0, 1.0)
    COL_BTN_RED = float4(0.95, 0.28, 0.28, 1.0)
    COL_BTN_PURPLE = float4(0.62, 0.35, 0.95, 1.0)
    COL_BTN_ORANGE = float4(0.98, 0.62, 0.15, 1.0)
    COL_BTN_GRAY = float4(0.32, 0.34, 0.42, 1.0)
    COL_SLOT = float4(0.10, 0.11, 0.16, 0.85)
    COL_SLOT_ON = float4(1.0, 0.78, 0.15, 0.95)
    TOAST_BASE_Y = 150.0
    TOAST_STEP = 52.0
    INDEX_COLS = 4
    INDEX_ROWS = 3
    HOTBAR_SLOTS = 9
}

var private {
    hudButtons : array<NodeId>
    inventoryWindow : NodeId
    inventoryButtons : NodeId[11]
    inventoryLabels : NodeId[11]
    fuseWindow : NodeId
    fuseButtons : NodeId[22]
    fuseImages : NodeId[22]
    fuseNames : NodeId[22]
    fuseSelected : bool[22]
    fuseLabel : NodeId
    fuseSubmit : NodeId
    sellWindow : NodeId
    sellTitle : NodeId
    sellImage : NodeId
    sellSlot : int = -1
    indexImages : NodeId[12]
    indexProgress : NodeId
    indexPageText : NodeId
    indexPage : int = 0
    hotbarImages : NodeId[9]
    rebirthFill : NodeId
    rebirthBtn : NodeId
    rebirthNeedsImage : NodeId[2]
    rebirthNeedsText : NodeId[2]
    cashText : NodeId
    incomeText : NodeId
    promptText : NodeId
    promptBar : NodeId
    promptBarFill : NodeId
    alarmOverlay : NodeId
    carryBanner : NodeId
    lockButtonText : NodeId
    lockButton : NodeId
    helpWindow : NodeId
    contactWindow : NodeId
    rebirthInfoText : NodeId
    hotbarBg : NodeId[9]
    hotbarText : NodeId[9]
    hotbarGear : int[9]
    boardTexts : NodeId[8]
    boardRoot : NodeId
    menuRoot : NodeId
    menuStatus : NodeId
    hudRoot : NodeId
    windowRoot : NodeId

    shopWindow : NodeId
    shopTabs : NodeId[3]
    shopPages : NodeId[3]
    shopCardBtn : NodeId[11]
    shopCardText : NodeId[11]
    shopTab : int = 0

    indexWindow : NodeId
    indexTabBtn : NodeId[9]
    indexCards : NodeId[56]
    indexCardText : NodeId[56]
    indexCounter : NodeId
    indexReward : NodeId
    indexTab : int = 0
    indexDirty : bool = true
    lastIndexSum : int = -1

    rebirthWindow : NodeId
    rebirthReqText : NodeId
    rebirthBonusText : NodeId
    rebirthLockText : NodeId

    skinsWindow : NodeId
    settingsWindow : NodeId
    settingsFill : NodeId[4]
    settingsPct : NodeId[4]
    skinCards : NodeId[BASE_SKIN_COUNT]
    skinImages : NodeId[BASE_SKIN_COUNT]
    skinCardText : NodeId[BASE_SKIN_COUNT]

    toasts : array<Toast>
    shownCash : double = 0.0lf
    alarmLevel : float = 0.0
    boardTimer : float = 0.0
    lastCashInt : int64 = -1l
    openWindow : int = 0
}


////////////////////////////////////////////////////////////////////////////////
// building blocks
////////////////////////////////////////////////////////////////////////////////

def private style_text(n : NodeId; size : float; color : float4; outline : bool = true) {
    n?.UIText.fontId = game_font()
    n?.UIText.fontSize = size
    n?.UIText.color = color
    n?.UIText.wordWrapping = false
    n?.UIText.autoResizeFrame = true
    if (outline) {
        n?.UIText.effect = TextEffect.Outline
        n?.UIText.effectColor = float4(0.0, 0.0, 0.0, 1.0)
        n?.UIText.effectThickness = max(2.0, size * 0.07)
    }
}

def private ui_text(parent : NodeId; str : string; size : float; color : float4; anchor, pos, pivot : float2) : NodeId {
    let n = text(str)
    n.set_parent(parent, AddChildStrategy.KeepLocalTransform)
    style_text(n, size, color)
    set_frame_pos(n, pos)
    add_anchor(n, anchor)
    set_frame_pivot(n, pivot)
    return n
}

def private ui_box(parent : NodeId; size : float2; color : float4; anchor, pos, pivot : float2) : NodeId {
    let n = create_node(NodeData(name = "box", parent = parent))
    add_component(n, new UIImage(color = color, size = size))
    set_frame_size(n, size)
    set_frame_pos(n, pos)
    add_anchor(n, anchor)
    set_frame_pivot(n, pivot)
    return n
}

// top-left placed rectangle inside a window
def private ui_at(parent : NodeId; size : float2; color : float4; x, y : float) : NodeId {
    return ui_box(parent, size, color, float2(0.0, 0.0), float2(x, y), float2(0.0, 0.0))
}

// wrapped, centered text inside a fixed box (cards)
def private ui_card_text(parent : NodeId; str : string; size : float; color : float4; boxW, boxH, x, y : float) : NodeId {
    let n = text(str)
    n.set_parent(parent, AddChildStrategy.KeepLocalTransform)
    n?.UIText.fontId = game_font()
    n?.UIText.fontSize = size
    n?.UIText.color = color
    n?.UIText.wordWrapping = true
    n?.UIText.autoResizeFrame = false
    n?.UIText.horAlignment = TextHorAlignment.Center
    n?.UIText.vertAlignment = TextVertAlignment.Middle
    n?.UIText.effect = TextEffect.Outline
    n?.UIText.effectColor = float4(0, 0, 0, 1)
    n?.UIText.effectThickness = 2.0
    set_frame_size(n, float2(boxW, boxH))
    set_frame_pos(n, float2(x, y))
    add_anchor(n, float2(0.0, 0.0))
    set_frame_pivot(n, float2(0.0, 0.0))
    return n
}

def private ui_label(parent : NodeId; str : string; size : float; color : float4; pos : float2) : NodeId {
    let n = text(str)
    n.set_parent(parent, AddChildStrategy.KeepLocalTransform)
    style_text(n, size, color)
    set_frame_pos(n, pos)
    add_anchor(n, float2(0.0, 0.0))
    set_frame_pivot(n, float2(0.0, 0.0))
    return n
}

def private ui_button(parent : NodeId; caption : string; size : float2; color : float4; anchor, pos, pivot : float2; fontSize : float; var onClick : lambda<() : void>) : NodeId {
    let n = ui_box(parent, size, color, anchor, pos, pivot)
    add_component(n, new UIButton(onClick <- onClick))
    let t = text(caption)
    t.set_parent(n, AddChildStrategy.KeepLocalTransform)
    style_text(t, fontSize, COL_WHITE)
    add_anchor(t, float2(0.5, 0.5))
    set_frame_pivot(t, float2(0.5, 0.5))
    return n
}

def private button_label(btn : NodeId) : NodeId {
    return btn.get_child(0)
}



def private ui_picture(parent : NodeId; texture : TextureId; uv : float4; size, pos : float2) : NodeId {
    let n = ui_at(parent, size, COL_WHITE, pos.x, pos.y)
    n?.UIImage.textureId = texture
    n?.UIImage.uvRegion = uv
    return n
}

def private nav_button(parent : NodeId; caption : string; icon : int; y : float; window : int; color : float4) {
    let btn = ui_button(parent, "", float2(140, 122), color, float2(0, 0.5), float2(24, y), float2(0, 0.5), 24.0, @() { toggle_window(window) })
    btn.name = "nav_{caption}"
    hudButtons |> push(btn)
    ui_picture(btn, navigation_texture(), atlas_rect(icon, 2, 2), float2(94,94), float2(23,0))
    ui_text(btn, caption, 28.0, COL_WHITE, float2(0.5,1), float2(0,-3), float2(0.5,1))
}

def private use_shop_gear(g : int) {
    var pa = localAvatar.isAlive ? get_component(localAvatar, type<PlayerAvatar>) : null
    if (pa != null) {
        if (gear_owned(pa.gearMask,g)) { broadcast_net_command(GearEquip(gear = g)) }
        else { broadcast_net_command(GearBuy(gear = g)) }
    }
}

def private index_page(delta : int) {
    indexPage = clamp(indexPage + delta, 0, (brainrot_count() - 1) / 12)
    indexDirty = true
}

def public show_sell(slot : int; defId, mutation : int; value : int64) {
    sellSlot = slot
    sellTitle?.UIText.text = "Sell {BRAINROTS[defId].name}?\nYou receive {format_cash(value)}"
    sellImage?.UIImage.uvRegion = atlas_rect(defId,8,7)
    sellImage?.UIImage.color = mutation > 0 ? MUTATION_COLORS[mutation] : COL_WHITE
    open_window(int(Window.Sell))
}

def private confirm_sell {
    if (sellSlot >= 0) { broadcast_net_command(SellRequest(slot = sellSlot)) }
    close_windows()
}

def private submit_fuse {
    var mask = 0u
    for (i in range(SLOTS_PER_BASE)) { if (fuseSelected[i]) { mask |= 1u << uint(i) } }
    broadcast_net_command(FuseRequest(slots = mask))
    close_windows()
}

////////////////////////////////////////////////////////////////////////////////
// windows
////////////////////////////////////////////////////////////////////////////////

def public close_windows {
    openWindow = 0
    modalOpen = false
    for (w in fixed_array(shopWindow, indexWindow, rebirthWindow, skinsWindow, settingsWindow, inventoryWindow, fuseWindow, sellWindow, helpWindow, contactWindow)) {
        if (w.isAlive) {
            w.isActive = false
        }
    }
}

def public windows_open : bool {
    return openWindow != 0
}

def public ui_click_blocks_gear : bool {
    if (modalOpen) { return true }
    if (chatTyping || (chatPanelNode.isAlive && chatPanelNode.isActive && is_mouse_inside_frame(get_component(chatPanelNode, type<UIFrame>)))) { return true }
    for (button in hudButtons) {
        if (button.isAlive && is_mouse_inside_frame(get_component(button,type<UIFrame>))) { return true }
    }
    for (button in hotbarBg) {
        if (button.isAlive && button.isActive && is_mouse_inside_frame(get_component(button,type<UIFrame>))) { return true }
    }
    return false
}

def public open_window(w : int) {
    if (chatTyping) {
        set_ui_focus_node(null)
        chatTyping = false
    }
    close_windows()
    openWindow = w
    modalOpen = w != 0
    play_sfx("click", 0.7)
    if (w == int(Window.Shop)) {
        shopWindow.isActive = true
    } elif (w == int(Window.Index)) {
        indexWindow.isActive = true
        indexDirty = true
    } elif (w == int(Window.Rebirth)) {
        rebirthWindow.isActive = true
    } elif (w == int(Window.Skins)) {
        skinsWindow.isActive = true
    } elif (w == int(Window.Settings)) {
        settingsWindow.isActive = true
    } elif (w == int(Window.Inventory)) {
        inventoryWindow.isActive = true
    } elif (w == int(Window.Fuse)) {
        fuseWindow.isActive = true
        for (i in range(SLOTS_PER_BASE)) { fuseSelected[i] = false }
    } elif (w == int(Window.Sell)) {
        sellWindow.isActive = true
    } elif (w == int(Window.Help)) {
        helpWindow.isActive = true
    } elif (w == int(Window.Contact)) {
        contactWindow.isActive = true
    }
}

def public toggle_window(w : int) {
    if (openWindow == w) {
        close_windows()
        play_sfx("click", 0.5)
    } else {
        open_window(w)
    }
}

def private select_shop_tab(i : int) {
    shopTab = i
    play_sfx("click", 0.5)
    for (k in range(3)) {
        shopPages[k].isActive = k == i
    }
}

def private select_index_tab(i : int) {
    indexTab = i
    indexPage = 0
    indexDirty = true
    play_sfx("click", 0.5)
}


////////////////////////////////////////////////////////////////////////////////
// construction
////////////////////////////////////////////////////////////////////////////////

def private window_frame(parent : NodeId; title : string; titleColor : float4; w, h : float) : NodeId {
    let win = ui_box(parent, float2(w, h), COL_PANEL, float2(0.5, 0.5), float2(0), float2(0.5))
    win.name = "window_{title}"
    ui_at(win, float2(w,82), float4(0.36,0.43,0.53,1), 0.0,0.0)
    ui_text(win, title, 54.0, COL_WHITE, float2(0,0), float2(24,12), float2(0,0))
    ui_button(win, "X", float2(64), COL_BTN_RED, float2(1,0), float2(-12,9), float2(1,0), 44.0, @() { close_windows() })
    win.isActive = false
    return win
}

def private build_shop_window(root : NodeId) {
    shopWindow = window_frame(root, "SHOP", COL_WHITE, 1100.0, 850.0)
    shopTabs[0] = ui_button(shopWindow, "GEAR", float2(330,56), COL_BTN_ORANGE, float2(0), float2(20,96), float2(0), 30.0, @() { select_shop_tab(0) })
    shopTabs[1] = ui_button(shopWindow, "BACKPACK", float2(330,56), COL_BTN_BLUE, float2(0), float2(385,96), float2(0), 30.0, @() { open_window(int(Window.Inventory)) })
    shopTabs[2] = ui_button(shopWindow, "BASE SKINS", float2(330,56), COL_BTN_GREEN, float2(0), float2(750,96), float2(0), 30.0, @() { open_window(int(Window.Skins)) })
    for (k in range(3)) {
        shopPages[k] = ui_at(shopWindow, float2(1060,670), float4(0), 20.0,168.0)
        shopPages[k].isActive = k == 0
    }
    for (i in range(gear_count())) {
        let g = GEARS[i]
        let card = ui_at(shopPages[0], float2(253,210), COL_CARD, float(i%4)*269.0,float(i/4)*220.0)
        ui_picture(card, gear_texture(), atlas_rect(i,4,3), float2(104), float2(7,6))
        ui_card_text(card,g.name,23.0,COL_WHITE,132.0,78.0,112.0,16.0)
        ui_card_text(card,g.desc,17.0,float4(0.83,0.87,0.94,1),235.0,58.0,9.0,105.0)
        let gi = i
        shopCardBtn[i] = ui_button(card,"",float2(233,38),COL_BTN_GREEN,float2(0),float2(10,166),float2(0),24.0,@() { use_shop_gear(gi) })
        shopCardText[i] = button_label(shopCardBtn[i])
    }
}

def private build_index_window(root : NodeId) {
    indexWindow = window_frame(root, "INDEX / ALL BRAINROTS", COL_WHITE, 1240.0, 920.0)
    for (m in range(INDEX_MUTATIONS)) {
        let mi = m
        let title = m == 0 ? "Normal" : MUTATION_NAMES[m]
        indexTabBtn[m] = ui_button(indexWindow,title,float2(184,58),m == 0 ? COL_BTN_GRAY : shade_color(MUTATION_COLORS[m]),float2(0),float2(16,112+float(m)*68.0),float2(0),25.0,@() { select_index_tab(mi) })
    }
    for (i in range(12)) {
        let x = 218.0 + float(i%4)*250.0
        let y = 104.0 + float(i/4)*222.0
        indexCards[i] = ui_at(indexWindow,float2(238,210),COL_CARD,x,y)
        indexImages[i] = ui_picture(indexCards[i],brainrot_texture(),float4(0,0,0.125,1.0/7.0),float2(156),float2(41,4))
        indexCardText[i] = ui_card_text(indexCards[i],"",21.0,COL_WHITE,230.0,48.0,4.0,159.0)
    }
    ui_button(indexWindow,"<",float2(58),COL_BTN_BLUE,float2(0),float2(220,782),float2(0),32.0,@() { index_page(-1) })
    ui_button(indexWindow,">",float2(58),COL_BTN_BLUE,float2(0),float2(1166,782),float2(0),32.0,@() { index_page(1) })
    indexPageText = ui_text(indexWindow,"",25.0,COL_WHITE,float2(0),float2(610,787),float2(0))
    let progress = ui_at(indexWindow,float2(862,32),float4(0,0,0,0.8),292.0,822.0)
    indexProgress = ui_at(progress,float2(854,24),COL_BTN_GREEN,4.0,4.0)
    indexProgress?.UIImage.fillMode = FillMode.Horizontal
    indexProgress?.UIImage.fillOrigin = FillOrigin.Left
    indexCounter = ui_text(progress,"0/56",25.0,COL_WHITE,float2(0.5),float2(0),float2(0.5))
    indexReward = ui_text(indexWindow,"",24.0,float4(1,.9,.3,1),float2(0.5,1),float2(80,-22),float2(0.5,1))
    ui_button(indexWindow,"SKINS",float2(184,58),COL_BTN_GREEN,float2(0),float2(16,802),float2(0),25.0,@() { open_window(int(Window.Skins)) })
}

def private shade_color(c : float4) : float4 {
    return float4(c.x * 0.7, c.y * 0.7, c.z * 0.7, 1.0)
}

def private build_rebirth_window(root : NodeId) {
    rebirthWindow = window_frame(root,"REBIRTH",COL_WHITE,940.0,880.0)
    ui_card_text(rebirthWindow,"Rebirthing resets your cash and brainrots.\nYour Index, gear and skins stay unlocked.",28.0,float4(1,.35,.35,1),892.0,82.0,24.0,98.0)
    ui_label(rebirthWindow,"You Will Unlock:",38.0,float4(1,.86,.2,1),float2(32,196))
    let multi = ui_at(rebirthWindow,float2(260,140),COL_CARD,32.0,246.0)
    ui_label(multi,"CASH MULTIPLIER",21.0,COL_WHITE,float2(16,14))
    rebirthBonusText = ui_text(multi,"",40.0,COL_BTN_GREEN,float2(0.5),float2(0,16),float2(0.5))
    let lock = ui_at(rebirthWindow,float2(260,140),COL_CARD,312.0,246.0)
    ui_label(lock,"BASE PROTECTION",21.0,COL_WHITE,float2(16,14))
    rebirthLockText = ui_text(lock,"+10 sec",36.0,float4(1,.84,.2,1),float2(0.5),float2(0,16),float2(0.5))
    let reward = ui_at(rebirthWindow,float2(302,140),COL_CARD,592.0,246.0)
    ui_label(reward,"STARTING CASH",21.0,COL_WHITE,float2(16,14))
    ui_picture(reward,navigation_texture(),atlas_rect(3,2,2),float2(82),float2(12,48))
    ui_text(reward,"$5,000",38.0,COL_BTN_GREEN,float2(0.5),float2(35,16),float2(0.5))
    ui_label(rebirthWindow,"Requirements:",38.0,float4(1,.86,.2,1),float2(32,410))
    let cash = ui_at(rebirthWindow,float2(862,54),float4(0,0,0,.8),32.0,464.0)
    rebirthFill = ui_at(cash,float2(854,46),COL_BTN_GREEN,4.0,4.0)
    rebirthFill?.UIImage.fillMode = FillMode.Horizontal
    rebirthFill?.UIImage.fillOrigin = FillOrigin.Left
    rebirthReqText = ui_text(cash,"",30.0,COL_WHITE,float2(0.5),float2(0),float2(0.5))
    for (i in range(2)) {
        let card = ui_at(rebirthWindow,float2(300,220),COL_CARD,150.0+float(i)*340.0,540.0)
        rebirthNeedsImage[i] = ui_picture(card,brainrot_texture(),atlas_rect(0,8,7),float2(154),float2(73,0))
        rebirthNeedsText[i] = ui_card_text(card,"",25.0,COL_WHITE,292.0,62.0,4.0,154.0)
    }
    rebirthBtn = ui_button(rebirthWindow,"REBIRTH",float2(540,72),COL_BTN_GREEN,float2(0.5,1),float2(0,-22),float2(0.5,1),46.0,@() { broadcast_net_command(RebirthRequest(dummy = 0)) })
}

def private build_skins_window(root : NodeId) {
    skinsWindow = window_frame(root, "BASE SKINS", float4(1.0, 0.8, 0.4, 1.0), 1120.0, 660.0)
    for (i in range(skin_count())) {
        let s = SKINS[i]
        let x = 24.0 + float(i % 4) * 270.0
        let y = 100.0 + float(i / 4) * 190.0
        let si = i
        let card = ui_button(skinsWindow, "", float2(256.0, 178.0), COL_CARD, float2(0.0, 0.0), float2(x, y), float2(0.0, 0.0), 20.0, @() { broadcast_net_command(SkinSelect(skin = si)) })
        skinCards[i] = card
        skinImages[i] = ui_picture(card, base_texture(), atlas_rect(i,4,3), float2(200,100), float2(28,4))
        skinCardText[i] = button_label(card)
        skinCardText[i]?.UIText.fontSize = 18.0
        skinCardText[i]?.UIText.autoResizeFrame = false
        skinCardText[i]?.UIText.wordWrapping = true
        set_frame_size(skinCardText[i], float2(232,32))
        add_anchor(skinCardText[i], float2(0.5,1))
        set_frame_pos(skinCardText[i], float2(0,-4))
        set_frame_pivot(skinCardText[i], float2(0.5,1))
        ui_card_text(card, s.name, 26.0, COL_WHITE, 232.0, 36.0, 12.0, 106.0)
    }
}

def private volume_of(row : int) : float {
    if (row == 0) {
        return get_master_volume()
    } elif (row == 1) {
        return get_music_volume()
    } elif (row == 2) {
        return get_sfx_volume()
    }
    return get_voice_volume()
}

def private change_volume(row : int; delta : float) {
    let v = clamp(volume_of(row) + delta, 0.0, 1.0)
    if (row == 0) {
        set_master_volume(v)
    } elif (row == 1) {
        set_music_volume(v)
    } elif (row == 2) {
        set_sfx_volume(v)
    } else {
        set_voice_volume(v)
    }
    play_sfx("click", 0.5)
}

def private build_settings_window(root : NodeId) {
    settingsWindow = window_frame(root, "SOUND", COL_WHITE, 760.0, 560.0)
    let names = fixed_array("Master", "Music", "Effects", "Voices")
    for (i in range(4)) {
        let row = i
        let y = 120.0 + float(i) * 100.0
        ui_text(settingsWindow, names[i], 38.0, COL_WHITE, float2(0.0, 0.0), float2(40.0, y + 8.0), float2(0.0, 0.0))
        ui_button(settingsWindow, "-", float2(64.0, 64.0), COL_BTN_GRAY, float2(0.0, 0.0), float2(250.0, y), float2(0.0, 0.0), 44.0, @() { change_volume(row, -0.1) })
        let back = ui_at(settingsWindow, float2(250.0, 36.0), float4(0.0, 0.0, 0.0, 0.6), 326.0, y + 14.0)
        settingsFill[i] = ui_at(back, float2(242.0, 28.0), COL_BTN_GREEN, 4.0, 4.0)
        settingsFill[i]?.UIImage.fillMode = FillMode.Horizontal
        settingsFill[i]?.UIImage.fillOrigin = FillOrigin.Left
        ui_button(settingsWindow, "+", float2(64.0, 64.0), COL_BTN_GRAY, float2(0.0, 0.0), float2(590.0, y), float2(0.0, 0.0), 44.0, @() { change_volume(row, 0.1) })
        settingsPct[i] = ui_text(settingsWindow, "100%", 26.0, COL_WHITE, float2(0.0, 0.0), float2(666.0, y + 16.0), float2(0.0, 0.0))
    }
    ui_text(settingsWindow, "Brainrot voices are quieter by default.", 24.0, float4(0.8, 0.85, 0.95, 1.0), float2(0.5, 1.0), float2(0.0, -30.0), float2(0.5, 1.0))
}

def private update_settings {
    for (i in range(4)) {
        let v = volume_of(i)
        settingsFill[i]?.UIImage.fillAmount = v
        settingsPct[i]?.UIText.text = "{int(v * 100.0 + 0.5)}%"
    }
}


def private contact_author() {
    open_window(int(Window.Contact))
}


def private build_help_window(root : NodeId) {
    helpWindow = window_frame(root, "HELP", COL_WHITE, 1140.0, 850.0)
    ui_at(helpWindow, float2(382.0, 592.0), COL_CARD, 24.0, 110.0)
    ui_at(helpWindow, float2(692.0, 592.0), COL_CARD, 424.0, 110.0)
    ui_label(helpWindow, "CONTROLS", 31.0, float4(1.0, 0.84, 0.3, 1.0), float2(44.0, 128.0))
    ui_label(helpWindow, "HOW TO PLAY", 31.0, float4(1.0, 0.84, 0.3, 1.0), float2(444.0, 128.0))
    let keys = fixed_array("WASD", "Space", "E", "Hold E", "F / LMB", "1-9", "RMB", "Wheel", "B", "Enter", "Esc")
    let actions = fixed_array("Move", "Jump", "Interact / buy / sell", "Steal a brainrot", "Use equipped gear",
        "Choose a gear slot", "Hold to turn camera", "Zoom camera", "Open Backpack", "Chat / send message", "Close this window")
    for (i in range(11)) {
        let y = 182.0 + float(i) * 44.0
        ui_label(helpWindow, keys[i], 24.0, float4(0.75, 0.89, 1.0, 1.0), float2(44.0, y))
        ui_label(helpWindow, actions[i], 22.0, COL_WHITE, float2(156.0, y + 1.0))
    }
    let titles = fixed_array("BUY & COLLECT", "STEAL & DEFEND", "SELL & LOCK", "UPGRADE & REBIRTH", "CRAFT MACHINE", "THUNDER EVENT")
    let details = fixed_array(
        "Buy on the red carpet. Brainrots earn cash on your base; step on green pads to collect it.",
        "Hold E at an unlocked rival base. Carry the brainrot home; gear can stop the carrier.",
        "Use E on your own brainrot to sell it. Step on the green lock pad to protect your base.",
        "Upgrade for extra slots. Rebirth resets cash and brainrots for permanent income bonuses and progression.",
        "Craft Machine consumes 3 selected brainrots plus a fee. Check the rules before fusing.",
        "Thunder lasts 5 minutes every 30 minutes. Rare+ spawns are boosted while the storm is active."
    )
    for (i in range(6)) {
        let y = 180.0 + float(i) * 82.0
        ui_label(helpWindow, titles[i], 24.0, float4(0.78, 0.9, 1.0, 1.0), float2(444.0, y))
        let body = ui_card_text(helpWindow, details[i], 22.0, COL_WHITE, 652.0, 54.0, 444.0, y + 28.0)
        body?.UIText.horAlignment = TextHorAlignment.Left
        body?.UIText.vertAlignment = TextVertAlignment.Top
    }
    ui_at(helpWindow, float2(1092.0, 100.0), COL_CARD, 24.0, 724.0)
    ui_label(helpWindow, "CREATOR / SUPPORT", 25.0, COL_WHITE, float2(44.0, 740.0))
    ui_label(helpWindow, AUTHOR_TELEGRAM_URL, 24.0, float4(0.75, 0.89, 1.0, 1.0), float2(44.0, 780.0))
    let telegram = ui_button(helpWindow, "TELEGRAM", float2(238.0, 68.0), COL_BTN_BLUE,
        float2(0.0), float2(856.0, 740.0), float2(0.0), 30.0, @() { contact_author() })
    telegram.name = "helpTelegram"
    contactWindow = window_frame(root, "TELEGRAM", COL_WHITE, 740.0, 330.0)
    let link = ui_card_text(contactWindow, AUTHOR_TELEGRAM_URL, 36.0,
        float4(0.75, 0.89, 1.0, 1.0), 692.0, 58.0, 24.0, 106.0)
    link.name = "authorTelegramLink"
    ui_card_text(contactWindow, "Open this link in your browser to contact the creator.",
        24.0, COL_WHITE, 692.0, 64.0, 24.0, 166.0)
    let back = ui_button(contactWindow, "BACK TO HELP", float2(400.0, 58.0), COL_BTN_BLUE,
        float2(0.5, 1.0), float2(0.0, -22.0), float2(0.5, 1.0), 26.0,
        @() { open_window(int(Window.Help)) })
    back.name = "contactBackToHelp"
}


def private build_inventory_window(root : NodeId) {
    inventoryWindow = window_frame(root,"BACKPACK",COL_WHITE,1040.0,780.0)
    for (i in range(11)) {
        let gi = i
        let card = ui_button(inventoryWindow,"",float2(236,200),COL_CARD,float2(0),float2(24+float(i%4)*254.0,108+float(i/4)*218.0),float2(0),18.0,@() { broadcast_net_command(GearEquip(gear = gi)) })
        inventoryButtons[i] = card
        ui_picture(card,gear_texture(),atlas_rect(i,4,3),float2(124),float2(56,4))
        ui_card_text(card,GEARS[i].name,24.0,COL_WHITE,228.0,42.0,4.0,124.0)
        inventoryLabels[i] = ui_card_text(card,"",20.0,COL_WHITE,228.0,30.0,4.0,166.0)
    }
}

def private build_fuse_window(root : NodeId) {
    fuseWindow = window_frame(root,"FUSE MACHINE",COL_WHITE,1100.0,930.0)
    ui_label(fuseWindow,"Choose 3 brainrots from your base",32.0,float4(1,.86,.2,1),float2(28,102))
    for (i in range(SLOTS_PER_BASE)) {
        let si = i
        fuseButtons[i] = ui_button(fuseWindow,"",float2(166,132),COL_CARD,float2(0),float2(24+float(i%6)*177.0,158+float(i/6)*144.0),float2(0),20.0,@() { select_fuse_slot(si) })
        fuseImages[i] = ui_picture(fuseButtons[i],brainrot_texture(),atlas_rect(0,8,7),float2(86),float2(40,0))
        fuseNames[i] = ui_card_text(fuseButtons[i],"Empty",19.0,COL_WHITE,158.0,44.0,4.0,86.0)
    }
    ui_card_text(fuseWindow,"The 3 selected brainrots will be consumed.\nSecret and OG brainrots cannot be fused.",24.0,COL_RED,1052.0,68.0,24.0,744.0)
    fuseLabel = ui_text(fuseWindow,"",29.0,COL_WHITE,float2(.5,1),float2(0,-103),float2(.5,1))
    fuseSubmit = ui_button(fuseWindow,"FUSE",float2(500,68),COL_BTN_PURPLE,float2(.5,1),float2(0,-22),float2(.5,1),42.0,@() { submit_fuse() })
}

def private build_sell_window(root : NodeId) {
    sellWindow = window_frame(root,"SELL BRAINROT",COL_WHITE,720.0,500.0)
    sellImage = ui_picture(sellWindow,brainrot_texture(),atlas_rect(0,8,7),float2(180),float2(270,92))
    sellTitle = ui_card_text(sellWindow,"",30.0,COL_WHITE,672.0,96.0,24.0,270.0)
    ui_button(sellWindow,"SELL",float2(290,70),COL_BTN_GREEN,float2(0),float2(36,396),float2(0),38.0,@() { confirm_sell() })
    ui_button(sellWindow,"KEEP",float2(290,70),COL_BTN_BLUE,float2(0),float2(394,396),float2(0),38.0,@() { close_windows() })
}

def private update_inventory(pa : PlayerAvatar?) {
    for (i in range(11)) {
        let owned = gear_owned(pa.gearMask,i)
        inventoryButtons[i]?.UIButton.interactable = owned
        inventoryButtons[i]?.UIImage.color = pa.equipped == i ? COL_BTN_BLUE : COL_CARD
        inventoryLabels[i]?.UIText.text = owned ? (pa.equipped == i ? "EQUIPPED" : "CLICK TO EQUIP") : "NOT OWNED"
        inventoryLabels[i]?.UIText.color = owned ? COL_BTN_GREEN : float4(.7,.7,.7,1)
    }
}

def private select_fuse_slot(slot : int) {
    var count = 0
    for (selected in fuseSelected) {
        if (selected) {
            count++
        }
    }
    if (fuseSelected[slot] || count < 3) {
        fuseSelected[slot] = !fuseSelected[slot]
    }
}


def private update_fuse(pa : PlayerAvatar?) {
    var count = 0
    var total = 0l
    var present : bool[22]
    for (i in range(SLOTS_PER_BASE)) {
        fuseButtons[i]?.UIButton.interactable = false
        fuseImages[i].isActive = false
        fuseNames[i]?.UIText.text = "Empty"
        fuseButtons[i]?.UIImage.color = COL_CARD
    }
    for (it in find_components(type<BrainrotItem>)) {
        if (it.state == 1 && it.baseIndex == localBase && it.slot >= 0 && it.slot < SLOTS_PER_BASE) {
            let si = it.slot
            let allowed = BRAINROTS[it.defId].rarity < 6
            present[si] = allowed
            fuseButtons[si]?.UIButton.interactable = allowed
            fuseImages[si].isActive = true
            fuseImages[si]?.UIImage.uvRegion = atlas_rect(it.defId,8,7)
            fuseImages[si]?.UIImage.color = allowed ? COL_WHITE : float4(.3,.3,.3,1)
            fuseNames[si]?.UIText.text = BRAINROTS[it.defId].name
            fuseButtons[si]?.UIImage.color = fuseSelected[si] ? COL_BTN_GREEN : COL_CARD
            if (allowed && fuseSelected[si]) {
                count++
                total += item_price(it.defId,it.mutation)
            }
        }
    }
    for (i in range(SLOTS_PER_BASE)) {
        if (!present[i]) {
            fuseSelected[i] = false
        }
    }
    let ready = count == 3 && pa.cash >= total / 10l && !pa.carrying && !pa.stunned && !pa.dancing
    fuseSubmit?.UIButton.interactable = ready
    fuseSubmit?.UIImage.color = ready ? COL_BTN_PURPLE : COL_BTN_GRAY
    fuseLabel?.UIText.text = "{count}/3 selected   Fee: {format_cash(total / 10l)}"
}

def public build_ui() {
    if (uiCanvas.isAlive) {
        remove_node(uiCanvas)
    }
    toasts |> clear()
    hudButtons |> clear()
    modalOpen = false
    openWindow = 0
    uiCanvas = canvas(float2(HUD_W, HUD_H))
    hudRoot = ui_box(uiCanvas, float2(HUD_W, HUD_H), float4(0.0, 0.0, 0.0, 0.0), float2(0.5, 0.5), float2(0.0, 0.0), float2(0.5, 0.5))
    add_anchor(hudRoot, float2(0.0, 0.0), float2(1.0, 1.0))
    let root = hudRoot

    // alarm overlay goes first so everything else draws above it
    alarmOverlay = ui_box(root, float2(HUD_W, HUD_H), float4(1.0, 0.0, 0.0, 0.0), float2(0.5, 0.5), float2(0.0, 0.0), float2(0.5, 0.5))
    add_anchor(alarmOverlay, float2(0.0, 0.0), float2(1.0, 1.0))

    // Bold green currency, three icon buttons, and a centered owned-gear hotbar.
    cashText = ui_text(root,"$0",74.0,float4(.32,1,.23,1),float2(0,1),float2(24,-66),float2(0,1))
    incomeText = ui_text(root,"+$0/s",27.0,COL_WHITE,float2(0,1),float2(28,-28),float2(0,1))
    rebirthInfoText = ui_text(root,"",24.0,COL_WHITE,float2(0,1),float2(28,-136),float2(0,1))
    nav_button(root,"Index",0,-180.0,int(Window.Index),float4(.20,.28,.39,.88))
    nav_button(root,"Rebirth",1,-46.0,int(Window.Rebirth),float4(.15,.40,.62,.88))
    nav_button(root,"Shop",2,88.0,int(Window.Shop),float4(.43,.19,.60,.88))
    hudButtons |> push(ui_button(root,"BACKPACK",float2(190,48),COL_BTN_GRAY,float2(0,0),float2(20,20),float2(0),25.0,@() { toggle_window(int(Window.Inventory)) }))
    hudButtons |> push(ui_button(root,"SOUND",float2(142,48),COL_BTN_GRAY,float2(0,0),float2(222,20),float2(0),25.0,@() { toggle_window(int(Window.Settings)) }))
    let help = ui_button(root,"HELP",float2(120,48),COL_BTN_GRAY,float2(0,0),float2(376,20),float2(0),25.0,@() { toggle_window(int(Window.Help)) })
    help.name = "nav_HELP"
    hudButtons |> push(help)
    lockButton = ui_button(root,"",float2(0),float4(0),float2(0),float2(0),float2(0),2.0,@() {})
    lockButtonText = button_label(lockButton)
    lockButton.isActive = false
    for (i in range(HOTBAR_SLOTS)) {
        let si = i
        hotbarBg[i] = ui_button(root,"",float2(92),COL_SLOT,float2(.5,1),float2(0,-20),float2(.5,1),18.0,@() { let g = hotbar_gear(si); if (g >= 0) { broadcast_net_command(GearEquip(gear = g)) } })
        hotbarBg[i].name = "hotbar_{i+1}"
        hotbarImages[i] = ui_picture(hotbarBg[i],gear_texture(),atlas_rect(0,4,3),float2(66),float2(13,8))
        hotbarText[i] = ui_card_text(hotbarBg[i],"",16.0,COL_WHITE,88.0,24.0,2.0,66.0)
        ui_label(hotbarBg[i],"{i+1}",23.0,COL_WHITE,float2(4,0))
        hotbarGear[i] = -1
        hotbarBg[i].isActive = false
    }

    // interaction prompt + progress bar
    promptText = ui_text(root, "", 46.0, COL_WHITE, float2(0.5, 0.72), float2(0.0, 0.0), float2(0.5, 0.5))
    promptBar = ui_box(root, float2(380.0, 26.0), float4(0.0, 0.0, 0.0, 0.7), float2(0.5, 0.72), float2(0.0, 50.0), float2(0.5, 0.5))
    promptBarFill = ui_box(promptBar, float2(372.0, 18.0), float4(1.0, 0.82, 0.15, 1.0), float2(0.5, 0.5), float2(0.0, 0.0), float2(0.5, 0.5))
    promptBarFill?.UIImage.fillMode = FillMode.Horizontal
    promptBarFill?.UIImage.fillOrigin = FillOrigin.Left
    promptBarFill?.UIImage.fillAmount = 0.0
    promptBar.isActive = false

    carryBanner = ui_text(root, "RUN TO YOUR BASE!", 56.0, COL_RED, float2(0.5, 0.0), float2(0.0, 96.0), float2(0.5, 0.0))
    carryBanner.isActive = false

    // leaderboard
    boardRoot = ui_box(root, float2(350.0, 86.0), float4(0.05, 0.06, 0.1, 0.55), float2(1.0, 0.0), float2(-20.0, 20.0), float2(1.0, 0.0))
    ui_label(boardRoot, "PLAYERS", 30.0, COL_WHITE, float2(16.0, 8.0))
    for (i in range(8)) {
        boardTexts[i] = ui_label(boardRoot, "", 26.0, COL_WHITE, float2(16.0, 48.0 + float(i) * 34.0))
    }

    windowRoot = ui_box(root, float2(HUD_W, HUD_H), float4(0.0, 0.0, 0.0, 0.0), float2(0.5, 0.5), float2(0.0, 0.0), float2(0.5, 0.5))
    add_anchor(windowRoot, float2(0.0, 0.0), float2(1.0, 1.0))
    build_shop_window(windowRoot)
    build_index_window(windowRoot)
    build_rebirth_window(windowRoot)
    build_skins_window(windowRoot)
    build_settings_window(windowRoot)
    build_help_window(windowRoot)
    build_inventory_window(windowRoot)
    build_fuse_window(windowRoot)
    build_sell_window(windowRoot)

    // main menu (shown until a session starts)
    menuRoot = ui_box(uiCanvas, float2(HUD_W, HUD_H), float4(0.04, 0.05, 0.10, 0.55), float2(0.5, 0.5), float2(0.0, 0.0), float2(0.5, 0.5))
    add_anchor(menuRoot, float2(0.0, 0.0), float2(1.0, 1.0))
    ui_text(menuRoot, "STEAL MY", 120.0, float4(1.0, 0.82, 0.15, 1.0), float2(0.5, 0.28), float2(0.0, -95.0), float2(0.5, 0.5))
    ui_text(menuRoot, "BRAINROT", 160.0, float4(1.0, 0.35, 0.55, 1.0), float2(0.5, 0.28), float2(0.0, 55.0), float2(0.5, 0.5))
    ui_button(menuRoot, "PLAY", float2(420.0, 120.0), COL_BTN_GREEN, float2(0.5, 0.62), float2(0.0), float2(0.5), 76.0, @() {
        set_menu_status("")
        open_lobby_menu()
    })
    menuStatus = ui_card_text(menuRoot,"Play locally or join friends from the lobby.",28.0,float4(.85,.9,1,1),1200.0,96.0,360.0,810.0)
}

def public set_menu_status(message : string) {
    menuStatus?.UIText.text = message
}

def public set_menu_visible(v : bool) {
    if (menuRoot.isAlive) {
        menuRoot.isActive = v
    }
    if (hudRoot.isAlive) {
        hudRoot.isActive = !v
    }
}


////////////////////////////////////////////////////////////////////////////////
// runtime
////////////////////////////////////////////////////////////////////////////////

def public show_toast(msg : string; color : float4 = float4(1, 1, 1, 1)) {
    if (!uiCanvas.isAlive) {
        return
    }
    let n = ui_text(hudRoot, msg, 40.0, color, float2(0.5, 0.0), float2(0.0, TOAST_BASE_Y), float2(0.5, 0.0))
    toasts |> push(Toast(node = n, ttl = 3.4, color = color))
}

def public flash_alarm(strength : float = 1.0) {
    alarmLevel = max(alarmLevel, strength)
}

def public set_prompt(msg : string; progress : float = -1.0; color : float4 = float4(1, 1, 1, 1)) {
    if (!promptText.isAlive) {
        return
    }
    promptText?.UIText.text = msg
    promptText?.UIText.color = color
    promptBar.isActive = progress >= 0.0
    if (progress >= 0.0) {
        promptBarFill?.UIImage.fillAmount = clamp(progress, 0.0, 1.0)
    }
}

def public mark_index_dirty {
    indexDirty = true
}

def private update_toasts(dt : float) {
    var rank = 0
    var i = length(toasts) - 1
    while (i >= 0) {
        toasts[i].ttl -= dt
        if (toasts[i].ttl <= 0.0 || !toasts[i].node.isAlive) {
            if (toasts[i].node.isAlive) {
                remove_node(toasts[i].node)
            }
            toasts |> erase(i)
        } else {
            let a = clamp(toasts[i].ttl / 0.6, 0.0, 1.0)
            let y = TOAST_BASE_Y + float(rank) * TOAST_STEP
            toasts[i].node?.UIAnchor.top = y
            toasts[i].node?.UIText.color = float4(toasts[i].color.x, toasts[i].color.y, toasts[i].color.z, a)
            rank++
        }
        i--
    }
}

def private update_board(dt : float) {
    boardTimer -= dt
    if (boardTimer > 0.0) {
        return
    }
    boardTimer = 0.4
    var names : array<string>
    var cashes : array<int64>
    for (pa in find_components(type<PlayerAvatar>)) {
        names |> push(pa.playerName)
        cashes |> push(pa.cash)
    }
    var order : array<int>
    for (i in range(length(names))) {
        order |> push(i)
    }
    for (i in range(length(order))) {
        for (j in range(i + 1, length(order))) {
            if (cashes[order[j]] > cashes[order[i]]) {
                let tmp = order[i]
                order[i] = order[j]
                order[j] = tmp
            }
        }
    }
    set_frame_size(boardRoot,float2(350,50+float(length(order))*34.0))
    for (i in range(8)) {
        if (i < length(order)) {
            boardTexts[i]?.UIText.text = "{i + 1}. {names[order[i]]}  {format_cash(cashes[order[i]])}"
        } else {
            boardTexts[i]?.UIText.text = ""
        }
    }
}

def private refresh_hotbar(pa : PlayerAvatar?) {
    var count = 0
    for (g in range(gear_count())) { if (gear_owned(pa.gearMask,g)) { count++ } }
    count = min(count,HOTBAR_SLOTS)
    var slot = 0
    for (g in range(gear_count())) {
        if (gear_owned(pa.gearMask,g) && slot < HOTBAR_SLOTS) {
            hotbarGear[slot] = g
            hotbarBg[slot].isActive = true
            hotbarBg[slot]?.UIAnchor.left = (float(slot)-float(count-1)*.5)*100.0
            hotbarBg[slot]?.UIAnchor.top = -20.0
            hotbarBg[slot]?.UIImage.color = pa.equipped == g ? float4(.35,.55,.83,.92) : COL_SLOT
            hotbarText[slot]?.UIText.text = GEARS[g].name
            hotbarImages[slot]?.UIImage.uvRegion = atlas_rect(g,4,3)
            slot++
        }
    }
    while (slot < HOTBAR_SLOTS) { hotbarGear[slot] = -1; hotbarBg[slot].isActive = false; slot++ }
}

// gear id sitting in hotbar slot `slot` (0-based), or -1
def public hotbar_gear(slot : int) : int {
    return slot >= 0 && slot < HOTBAR_SLOTS ? hotbarGear[slot] : -1
}

def private update_shop(pa : PlayerAvatar?) {
    for (i in range(gear_count())) {
        let g = GEARS[i]
        let owned = gear_owned(pa.gearMask, i)
        var caption = ""
        var col = COL_BTN_GREEN
        if (owned) {
            caption = pa.equipped == i ? "EQUIPPED" : "OWNED"
            col = COL_BTN_BLUE
        } elif (pa.rebirths < g.rebirth) {
            caption = "REBIRTH {g.rebirth}"
            col = float4(0.5, 0.25, 0.25, 1.0)
        } else {
            caption = format_cash(g.price)
            col = pa.cash >= g.price ? COL_BTN_GREEN : float4(0.55, 0.25, 0.25, 1.0)
        }
        shopCardText[i]?.UIText.text = caption
        shopCardBtn[i]?.UIImage.color = col
        shopCardBtn[i]?.UIButton.interactable = owned || (pa.rebirths >= g.rebirth && pa.cash >= g.price)
    }
}

def private update_index(pa : PlayerAvatar?) {
    var sum = 0
    for (b in pa.discovered) { sum += int(b) }
    if (sum != lastIndexSum) { lastIndexSum = sum; indexDirty = true }
    if (!indexDirty) { return }
    indexDirty = false
    let m = indexTab
    let n = brainrot_count()
    for (i in range(12)) {
        let d = indexPage*12+i
        indexCards[i].isActive = d < n
        if (d < n) {
            let found = index_has(pa.discovered,d,m)
            let bd = BRAINROTS[d]
            indexImages[i]?.UIImage.uvRegion = atlas_rect(d,8,7)
            indexImages[i]?.UIImage.color = found ? (m > 0 ? MUTATION_COLORS[m] : COL_WHITE) : float4(0,0,0,1)
            indexCards[i]?.UIImage.color = COL_CARD
            indexCardText[i]?.UIText.text = found ? "{bd.name}\n{RARITY_NAMES[bd.rarity]}" : "???"
            indexCardText[i]?.UIText.color = found ? RARITY_COLORS[bd.rarity] : COL_WHITE
        }
    }
    for (i in range(INDEX_MUTATIONS)) { indexTabBtn[i]?.UIImage.color = i == m ? COL_BTN_BLUE : (i == 0 ? COL_BTN_GRAY : shade_color(MUTATION_COLORS[i])) }
    let have = index_count(pa.discovered,m)
    indexProgress?.UIImage.fillAmount = float(have)/float(n)
    indexCounter?.UIText.text = "{have}/{n}"
    indexPageText?.UIText.text = "Page {indexPage+1}/{(n+11)/12}"
    indexReward?.UIText.text = m == 0 ? "Discover every brainrot!" : "{have}/{index_needed(m)} to unlock {MUTATION_NAMES[m]} Base + 0.5x cash"
}

def private update_skins(pa : PlayerAvatar?) {
    for (i in range(skin_count())) {
        let s = SKINS[i]
        let unlocked = skin_unlocked(pa.discovered, i)
        skinImages[i]?.UIImage.color = unlocked ? COL_WHITE : float4(.4,.4,.4,1)
        skinCards[i]?.UIButton.interactable = unlocked
        var status = ""
        if (pa.skin == i) {
            status = "EQUIPPED"
        } elif (unlocked) {
            status = s.mutation == 0 && s.ownDef < 0 ? "FREE - Tap to equip" : "Tap to equip"
        } elif (s.mutation > 0) {
            status = "{index_count(pa.discovered, s.mutation)}/{index_needed(s.mutation)} {MUTATION_NAMES[s.mutation]}"
        } else {
            status = "Own {BRAINROTS[s.ownDef].name}"
        }
        skinCardText[i]?.UIText.text = status
        skinCardText[i]?.UIText.color = pa.skin == i ? float4(1.0, 0.85, 0.3, 1.0) : (unlocked ? float4(0.6, 1.0, 0.7, 1.0) : float4(1.0, 0.6, 0.6, 1.0))
        skinCards[i]?.UIImage.color = pa.skin == i ? float4(0.3, 0.27, 0.12, 1.0) : COL_CARD
    }
}

def public update_ui(dt : float) {
    if (!uiCanvas.isAlive) {
        return
    }
    update_toasts(dt)
    update_board(dt)

    if (is_action_just_pressed("closeWindow")) { close_windows() }
    if (!chatTyping && is_action_just_pressed("backpack")) { toggle_window(int(Window.Inventory)) }
    // alarm pulse
    alarmLevel = max(0.0, alarmLevel - dt * 0.45)
    let pulse = (sin(get_time() * 9.0) * 0.5 + 0.5) * alarmLevel * 0.38
    alarmOverlay?.UIImage.color = float4(1.0, 0.0, 0.0, pulse)

    var pa = localAvatar.isAlive ? get_component(localAvatar, type<PlayerAvatar>) : null
    if (pa == null) {
        cashText?.UIText.text = ""
        incomeText?.UIText.text = ""
        return
    }
    // smoothly count the cash up/down
    let target = double(pa.cash)
    var shown = double(shownCash)
    shown += (target - shown) * double(min(1.0, dt * 9.0))
    if (abs(target - shown) < 1.0lf) {
        shown = target
    }
    shownCash = shown
    let ci = int64(shown)
    if (ci != lastCashInt) {
        lastCashInt = ci
        cashText?.UIText.text = format_cash(ci)
    }
    incomeText?.UIText.text = "+{format_cash(pa.incomePerSec)}/s"
    rebirthInfoText?.UIText.text = pa.rebirths > 0 ? "Rebirth {pa.rebirths}  (x{income_multiplier(pa.rebirths)} income)" : ""
    carryBanner.isActive = pa.carrying

    refresh_hotbar(pa)

    // lock button
    if (pa.lockRemaining > 0.0) {
        lockButtonText?.UIText.text = "LOCKED\n{int(pa.lockRemaining)}s"
        lockButton?.UIImage.color = float4(0.45, 0.1, 0.1, 1.0)
    } else {
        lockButtonText?.UIText.text = "LOCK"
        lockButton?.UIImage.color = COL_BTN_RED
    }

    if (openWindow == int(Window.Shop)) {
        update_shop(pa)
    } elif (openWindow == int(Window.Index)) {
        update_index(pa)
    } elif (openWindow == int(Window.Settings)) {
        update_settings()
    } elif (openWindow == int(Window.Skins)) {
        update_skins(pa)
    } elif (openWindow == int(Window.Inventory)) {
        update_inventory(pa)
    } elif (openWindow == int(Window.Fuse)) {
        update_fuse(pa)
    } elif (openWindow == int(Window.Rebirth)) {
        let cost = rebirth_cost(pa.rebirths)
        rebirthFill?.UIImage.fillAmount = clamp(float(double(pa.cash)/double(cost)),0.0,1.0)
        rebirthReqText?.UIText.text = pa.rebirths >= MAX_REBIRTHS ? "MAX REBIRTH" : "{format_cash(pa.cash)} / {format_cash(cost)}"
        rebirthBonusText?.UIText.text = "x{income_multiplier(pa.rebirths+1)}"
        rebirthLockText?.UIText.text = pa.rebirths+1 == 2 ? "Floor 2 + 8 slots" : (pa.rebirths+1 == 10 ? "Floor 3 + 4 slots" : "+10 sec")
        var ready = pa.cash >= cost && pa.rebirths < MAX_REBIRTHS && !pa.carrying
        for (i in range(2)) {
            let defId = rebirth_required_def(pa.rebirths,i)
            var owned = false
            for (it in find_components(type<BrainrotItem>)) { if (it.state == 1 && it.baseIndex == localBase && it.defId == defId) { owned = true } }
            rebirthNeedsImage[i]?.UIImage.uvRegion = atlas_rect(defId,8,7)
            rebirthNeedsImage[i]?.UIImage.color = owned ? COL_WHITE : float4(.15,.15,.15,1)
            rebirthNeedsText[i]?.UIText.text = "{BRAINROTS[defId].name}\n{owned ? "READY" : "REQUIRED"}"
            rebirthNeedsText[i]?.UIText.color = owned ? COL_BTN_GREEN : COL_RED
            ready = ready && owned
        }
        rebirthBtn?.UIButton.interactable = ready
        rebirthBtn?.UIImage.color = ready ? COL_BTN_GREEN : COL_BTN_GRAY
    }
}
