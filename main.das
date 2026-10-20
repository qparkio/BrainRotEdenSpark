require engine.core
require engine.networking
require constants
require layout
require brainrot_data
require components
require net_commands
require game_state
require sounds
require world
require avatar
require player
require items_view
require traps
require mutations
require leaderboards
require dress
require interact
require fx
require ui
require ui_assets
require chat
require thunder_view
require thunder_vfx
require thunder_weather


var private {
    menuAngle : float = 0.0
    connectionMessage : string
    menuResetPending : bool = false
}


def private configure_exposure {
    var adaptation = find_component(type<HDExposureAdaptation>)
    if (adaptation != null) {
        adaptation.minExposure = SCENE_EXPOSURE
        adaptation.maxExposure = SCENE_EXPOSURE
        adaptation.exposureScale = 1.0
    }
    var bloom = find_component(type<Bloom>)
    if (bloom != null) {
        bloom.intensity = LASER_BLOOM_INTENSITY
    }
}


def private build_stage {
    reset_dress_state()
    localPlayer = NodeId()
    localAvatar = NodeId()
    localBase = -1
    localStunned = false
    localCarrying = false
    build_map()
    spawn_leaderboard_view()
    sunNode = create_node(NodeData(name = "sun", rotation = quat4(PI / 3.2, -PI * 0.2, 0.0)))
    add_component(sunNode, new DirectionalLight())
    let rs = create_render_settings()
    renderSettingsNode = rs
    add_component(rs, new DistanceFog(active = false, mode = DistanceFogMode.Exponential,
        lightingMode = DistanceFogLightingMode.None, startDistance = 12.0))
    get_component(rs) $(var amb : AmbientSettings?) {
        amb.ambientSource = AmbientSource.ConstColor
        amb.ambientColor = float3(0.85, 0.88, 1.0)
        amb.ambientStrength = 0.7
    }
    configure_exposure()
    cameraNode = create_node(NodeData(name = "camera", position = float3(0, 60, -120), rotation = quat4(0.5, 0.0, 0.0)))
    add_component(cameraNode, new Camera(backgroundColor = COL_SKY, fov = 65.0 * PI / 180.0, znear = 0.3, zfar = 800.0))
    add_component(cameraNode, new AudioListener())
    build_ui()
    spawn_chat_view(uiCanvas)
    spawn_thunder_view(mapRoot)
    spawn_thunder_weather()
}

def private show_menu {
    stop_music()
    if (inWorld) {
        inWorld = false
        // The lobby callback may run while the last network packets are still draining.
        // Keep mirrors alive until the session is fully disconnected.
        menuResetPending = true
    }
    set_menu_visible(true)
}

def private reset_to_empty_stage {
    clear_scene()
    build_stage()
}

def private enter_world {
    menuResetPending = false
    inWorld = true
    set_menu_visible(false)
    start_music()
}


[export]
def on_initialize {
    set_physics_fps(PHYSICS_FPS)
    init_input()
    show_mouse_cursor(true)
    load_sounds()
    load_ui_assets()
    load_brainrot_prefabs()
    load_world_materials()
    load_mutation_visuals()
    load_thunder_visuals()
    load_thunder_weather()
    set_lobby_callbacks(@@on_lobby_created, @@on_connection_established, @@on_connection_lost, @@on_lobby_left, @@on_lobby_destroyed)
    set_lobby_max_connections(MAX_PLAYERS)
    build_stage()
    set_menu_visible(true)
}

def on_lobby_created(data : LobbyData) {
    print("[client] lobby created, host={data.shouldHost}")
    connectionMessage = "Connecting to the host..."
    set_menu_status(connectionMessage)
}

def on_connection_established(userName : string) {
    print("[client] connected as {userName}")
    connectionMessage = ""
    set_menu_status("")
    enter_world()
}

def on_connection_lost(cause : DisconnectCause) {
    print("[client] connection lost: {cause}")
    connectionMessage = "Connection failed: {cause}. Choose Play locally in the lobby or another room."
    show_menu()
    set_menu_status(connectionMessage)
}

def on_lobby_left(kicked : bool) {
    show_menu()
    set_menu_status(connectionMessage)
}

def on_lobby_destroyed() {
    show_menu()
    set_menu_status(connectionMessage)
}


def private fly_menu_camera(dt : float) {
    menuAngle += dt * 0.12
    let r = 150.0
    cameraNode.worldPosition = float3(sin(menuAngle) * r, 70.0, cos(menuAngle) * r)
    cameraNode.worldRotation = quat4(0.42, menuAngle + PI, 0.0)
}

[export]
def on_update {
    if (menuResetPending && !has_network()) {
        menuResetPending = false
        reset_to_empty_stage()
        set_menu_visible(true)
        set_menu_status(connectionMessage)
    }
    let dt = get_delta_time()
    if (localPlayer.isAlive) {
        update_camera()
        if (localPlayer.worldPosition.y < FALL_RESET_Y && localBase >= 0) {
            localPlayer.worldPosition = spawn_pos(localBase)
        }
    } elif (cameraNode.isAlive) {
        fly_menu_camera(dt)
    }
    if (cameraNode.isAlive) {
        update_label_culling(cameraNode.worldPosition)
    }
    update_sounds()
    update_items()
    update_traps()
    update_avatars()
    update_bases()
    update_interaction(dt)
    update_ui(dt)
    send_move_state(dt)
}

[net_command_handler]
def on_position_correction(cmd : PositionCorrection; connection : ConnectionId) {
    if (localPlayer.isAlive) {
        localPlayer.worldPosition = cmd.pos
        localPlayer?.CharacterController.velocity = float3(0)
    }
}

[cheat]
def ui_open(window : int) { open_window(window) }

[cheat]
def skin_select(index : int) {
    broadcast_net_command(SkinSelect(skin = index))
}

[cheat]
def refresh_rendering {
    configure_exposure()
    for (mesh in find_components(type<Mesh>)) {
        if (mesh.nodeId.name == "edenLogo") {
            mesh.uvRect = float4(1.0, 0.0, -1.0, 1.0)
        }
    }
}

[cheat]
def buy_nearby {
    attempt_buy_nearest()
}

[cheat]
def rebuild_ui {
    build_ui()
    spawn_chat_view(uiCanvas)
    set_menu_visible(!inWorld)
}

[cheat]
def refresh_controls {
    init_input()
}

[export]
def on_fixed_update {
    if (localPlayer.isAlive) {
        get_component(localPlayer) $(var lp : LocalPlayer?) {
            lp.fixedStep()
        }
    }
}

[export]
def on_resolution_changed(res : int2) {
    // the HUD canvas scales itself (FitExtend); nothing else is sized to the screen
}


[cheat]
def goto_belt {
    if (localPlayer.isAlive) {
        localPlayer.worldPosition = float3(-12.0, 3.0, -60.0)
    }
}

[cheat]
def tp(x : float; z : float) {
    if (localPlayer.isAlive) {
        localPlayer.worldPosition = float3(x, 3.0, z)
    }
}

[cheat]
def tpy(x : float; y : float; z : float) {
    if (localPlayer.isAlive) {
        localPlayer.worldPosition = float3(x, y, z)
    }
}

[cheat]
def test_model(file : string) {
    if (!localPlayer.isAlive) {
        return
    }
    let prefab = request_prefab("assets/brainrots/{file}.glb")
    let p = localPlayer.worldPosition
    let n = instantiate_prefab(prefab, NodeData(position = float3(p.x + 6.0, p.y, p.z), scale = float3(BRAINROT_SCALE)))
    print("test_model {file}: {n}")
}

[cheat]
def give(amount : int) {
    if (has_network()) {
        broadcast_net_command(DebugCommand(kind = 1, amount = int64(amount)))
    }
}

[cheat]
def qa_item(defId : int) {
    if (has_network()) {
        broadcast_net_command(DebugCommand(kind = 5, amount = int64(defId)))
    }
}

[cheat]
def set_rebirths(n : int) {
    if (has_network()) {
        broadcast_net_command(DebugCommand(kind = 2, amount = int64(n)))
    }
}

[cheat]
def discover_all {
    if (has_network()) {
        broadcast_net_command(DebugCommand(kind = 3, amount = 0l))
    }
}

[cheat]
def debug_input {
    print("moveX={get_action_axis("moveX")} moveY={get_action_axis("moveY")} jump={is_action_pressed("jump")} interact={is_action_pressed("interact")} turn={get_action_axis("turnKeys")} look={is_action_pressed("lookHold")}")
}

[cheat]
def cam(yawDeg : float; pitchDeg : float; dist : float) {
    cameraYaw = yawDeg * PI / 180.0
    cameraPitch = pitchDeg * PI / 180.0
    cameraDistance = dist
}

[cheat]
def cull_info {
    print(cull_stats())
}

[cheat]
def upgrade_base {
    broadcast_net_command(UpgradeRequest(dummy = 0))
}

[cheat]
def lock_base {
    broadcast_net_command(LockRequest(dummy = 0))
}

[cheat]
def goto_base(index : int) {
    if (localPlayer.isAlive) {
        localPlayer.worldPosition = spawn_pos(clamp(index, 0, BASE_COUNT - 1))
    }
}


// Start the five-minute event in a local hosted room without waiting 30 minutes.
[cheat]
def audio_status {
    print_audio_status()
}


[cheat]
def audio_test {
    play_sfx("buy", 0.7)
}


// Start the five-minute event in a local hosted room without waiting 30 minutes.
[cheat]
def thunder_start {
    broadcast_net_command(ThunderStart(dummy = 0))
}
