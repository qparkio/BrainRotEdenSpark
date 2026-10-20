require engine.core
require constants
require game_state
require avatar
require sounds


def public init_input() {
    if (has_action_set("player")) {
        remove_action_set("player")
    }
    add_and_activate_action_set("player", {
        "moveX" => Action(axisActions = AxisAction(
            keyboardAxis = [KeyboardBtnAxisInput(negativeIdx = KeyCode.A, positiveIdx = KeyCode.D)]
        )),
        "moveY" => Action(axisActions = AxisAction(
            keyboardAxis = [KeyboardBtnAxisInput(negativeIdx = KeyCode.S, positiveIdx = KeyCode.W)]
        )),
        "turnKeys" => Action(axisActions = AxisAction(
            keyboardAxis = [KeyboardBtnAxisInput(negativeIdx = KeyCode.Left, positiveIdx = KeyCode.Right)]
        )),
        "pitchKeys" => Action(axisActions = AxisAction(
            keyboardAxis = [KeyboardBtnAxisInput(negativeIdx = KeyCode.Down, positiveIdx = KeyCode.Up)]
        )),
        "lookX" => Action(axisActions = AxisAction(
            mouseMoveAxis = [MouseMoveAxisInput(idx = MouseMoveAxis.Horizontal, sensitivity = 1.0)]
        )),
        "lookY" => Action(axisActions = AxisAction(
            mouseMoveAxis = [MouseMoveAxisInput(idx = MouseMoveAxis.Vertical, sensitivity = 1.0)]
        )),
        "zoom" => Action(axisActions = AxisAction(
            mouseMoveAxis = [MouseMoveAxisInput(idx = MouseMoveAxis.Wheel, sensitivity = 1.0)]
        )),
        "lookHold" => Action(buttonActions = ButtonAction(
            mouseButtons = [MouseButtonInput(idx = MouseButton.Right)]
        )),
        "jump" => Action(buttonActions = ButtonAction(
            keyboardButtons = [KeyboardButtonInput(idx = KeyCode.Space)]
        )),
        "interact" => Action(buttonActions = ButtonAction(
            keyboardButtons = [KeyboardButtonInput(idx = KeyCode.E)]
        )),
        "swing" => Action(buttonActions = ButtonAction(
            mouseButtons = [MouseButtonInput(idx = MouseButton.Left)]
        )),
        "gearUse" => Action(buttonActions = ButtonAction(
            keyboardButtons = [KeyboardButtonInput(idx = KeyCode.F)]
        )),
        "slot1" => Action(buttonActions = ButtonAction(
            keyboardButtons = [KeyboardButtonInput(idx = KeyCode._1)]
        )),
        "slot2" => Action(buttonActions = ButtonAction(
            keyboardButtons = [KeyboardButtonInput(idx = KeyCode._2)]
        )),
        "slot3" => Action(buttonActions = ButtonAction(keyboardButtons = [KeyboardButtonInput(idx = KeyCode._3)])),
        "slot4" => Action(buttonActions = ButtonAction(keyboardButtons = [KeyboardButtonInput(idx = KeyCode._4)])),
        "slot5" => Action(buttonActions = ButtonAction(keyboardButtons = [KeyboardButtonInput(idx = KeyCode._5)])),
        "slot6" => Action(buttonActions = ButtonAction(keyboardButtons = [KeyboardButtonInput(idx = KeyCode._6)])),
        "slot7" => Action(buttonActions = ButtonAction(keyboardButtons = [KeyboardButtonInput(idx = KeyCode._7)])),
        "slot8" => Action(buttonActions = ButtonAction(keyboardButtons = [KeyboardButtonInput(idx = KeyCode._8)])),
        "slot9" => Action(buttonActions = ButtonAction(keyboardButtons = [KeyboardButtonInput(idx = KeyCode._9)])),
        "backpack" => Action(buttonActions = ButtonAction(keyboardButtons = [KeyboardButtonInput(idx = KeyCode.B)])),
        "closeWindow" => Action(buttonActions = ButtonAction(keyboardButtons = [KeyboardButtonInput(idx = KeyCode.Escape)])),
        "chatEnter" => Action(buttonActions = ButtonAction(keyboardButtons = [KeyboardButtonInput(idx = KeyCode.Return), KeyboardButtonInput(idx = KeyCode.NumpadEnter)]))
    })
}


// Drives the local character. Client-authoritative movement: the server only validates it.
class LocalPlayer : Component {
    speedFactor : float = 1.0
    gravityFactor : float = 1.0
    stunTimer : float = 0.0
    freezeTimer : float = 0.0
    invertTimer : float = 0.0
    danceTimer : float = 0.0
    carrying : bool = false
    private verticalSpeed : float = 0.0
    private wantJump : bool = false
    private lastGrounded : bool = true
    knock : float3
    private stepDist : float = 0.0
    private stepFlip : bool = false

    def override on_initialize {
        add_component(nodeId, new CharacterController(velocity = float3()))
        nodeId?.CharacterController.maxSlopeAngle = PLAYER_MAX_SLOPE
        nodeId?.CharacterController.stepHeight = PLAYER_STEP_HEIGHT
        add_component(nodeId, new Collider(shape = capsule_shape(PLAYER_RADIUS, PLAYER_HEIGHT, AxisDirection.YAxis, float3(0.0, PLAYER_HEIGHT * 0.5, 0.0))))
    }

    def override on_update {
        if (!modalOpen && !chatTyping && is_action_just_pressed("jump")) {
            wantJump = true
        }
        let dt = get_delta_time()
        stunTimer = max(0.0, stunTimer - dt)
        freezeTimer = max(0.0, freezeTimer - dt)
        invertTimer = max(0.0, invertTimer - dt)
        danceTimer = max(0.0, danceTimer - dt)
    }

    def isGrounded : bool {
        return nodeId?.CharacterController.state == CharacterState.OnGround
    }

    def fixedStep {
        let dt = get_delta_time()
        let stunned = modalOpen || chatTyping || stunTimer > 0.0 || freezeTimer > 0.0 || danceTimer > 0.0
        let yawRot = quat4(0.0, cameraYaw, 0.0)
        var move = float3(0)
        if (!stunned) {
            move = yawRot * (RIGHT * get_action_axis("moveX") + FORWARD * get_action_axis("moveY"))
        }
        if (length_sq(move) > 1.0) {
            move = normalize(move)
        }
        if (invertTimer > 0.0) {
            move = move * -1.0
        }
        let grounded = isGrounded()
        if (grounded) {
            if (!lastGrounded && verticalSpeed < -8.0) {
                play_sfx("land", 0.7)
            }
            // Eden's controller holds a walkable slope with zero vertical speed.
            // A constant downward velocity makes an idle character slide down stairs.
            verticalSpeed = 0.0
            if (wantJump && !stunned) {
                verticalSpeed = JUMP_SPEED
                play_sfx("jump", 0.6)
            }
        } else {
            verticalSpeed -= GRAVITY * gravityFactor * dt
        }
        lastGrounded = grounded
        wantJump = false

        var speed = WALK_SPEED * speedFactor
        if (carrying) {
            speed *= CARRY_SPEED_FACTOR
        }
        knock *= exp(-dt * 5.0)
        if (length_sq(knock) < 0.04) {
            knock = float3(0)
        }
        nodeId?.CharacterController.velocity = move * speed + knock + UP * verticalSpeed
        if (grounded && length_sq(move) > 0.01) {
            stepDist += speed * dt
            if (stepDist > 7.0) {
                stepDist = 0.0
                stepFlip = !stepFlip
                play_sfx(stepFlip ? "step1" : "step2", 0.35, 0.9 + random_float() * 0.2)
            }
        }

        if (length_sq(move) > 0.01) {
            let want = atan2(move.x, move.z)
            let cur = atan2(nodeId.localForward.x, nodeId.localForward.z)
            let diff = angle_diff(cur, want)
            let step = clamp(diff, -dt * 14.0, dt * 14.0)
            nodeId.localRotation = quat4(0.0, cur + step, 0.0)
        }
    }
}


def public update_camera() {
    if (!localPlayer.isAlive || !cameraNode.isAlive) {
        return
    }
    let dt = get_delta_time()
    if (modalOpen || chatTyping || (chatPanelNode.isAlive && chatPanelNode.isActive && is_mouse_inside_frame(get_component(chatPanelNode, type<UIFrame>)))) { return }
    if (is_action_pressed("lookHold")) {
        cameraYaw += get_action_axis("lookX") * CAMERA_LOOK_SENS
        cameraPitch += get_action_axis("lookY") * CAMERA_LOOK_SENS
    }
    cameraYaw += get_action_axis("turnKeys") * CAMERA_KEY_SPEED * dt
    cameraPitch -= get_action_axis("pitchKeys") * CAMERA_KEY_SPEED * 0.6 * dt
    cameraPitch = clamp(cameraPitch, CAMERA_PITCH_MIN, CAMERA_PITCH_MAX)
    cameraDistance = clamp(cameraDistance - get_action_axis("zoom") * 0.01, CAMERA_MIN_DISTANCE, CAMERA_MAX_DISTANCE)

    let focus = localPlayer.worldPosition + float3(0.0, 3.6, 0.0)
    let rot = quat4(cameraPitch, cameraYaw, 0.0)
    let back = rot * float3(0.0, 0.0, -1.0)
    // pull the camera in front of walls instead of letting it clip through them
    var dist = cameraDistance
    let startOffset = 1.4
    trace(RayCast(ray = Ray(origin = focus + back * startOffset, direction = back), maxDistance = max(cameraDistance - startOffset, 0.1))) $(hit) {
        dist = max(startOffset + hit.distance - 0.6, 2.5)
    }
    var pos = focus + back * dist
    pos.y = max(pos.y, 1.0)
    cameraNode.worldPosition = pos
    cameraNode.worldRotation = rot
}


def public spawn_local_player(pos : float3; color : float4; playerName : string) : NodeId {
    let node = create_node(NodeData(name = "localPlayer", position = pos))
    add_component(node, new AvatarView(color = color, playerName = playerName))
    add_component(node, new LocalPlayer())
    localPlayer = node
    return node
}
