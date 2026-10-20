// Tunables only. No state, no helpers.


let public {
    AUTHOR_TELEGRAM_URL = "https://t.me/andruwrus"
    LEGACY_SFX_GAIN = 0.22
    LEGACY_SFX_MAX_SECONDS = 2.5
    // Thunder starts every 30 minutes; its five minutes are part of that period.
    THUNDER_PERIOD = 1800.0
    THUNDER_DURATION = 300.0
    THUNDER_RARE_MULTIPLIER = 2.0
    THUNDER_RARE_MIN_TIER = 1
    THUNDER_TRANSITION_SECONDS = 3.0
    THUNDER_PEDESTAL_POSITION = float3(15.0, 0.0, 13.0)
    THUNDER_FUNNEL_HEIGHT = 13.5
    THUNDER_FUNNEL_SPEED = 1.25
    THUNDER_SPIRAL_COUNT = 24
    THUNDER_DUST_COUNT = 48
    THUNDER_GRAIN_COUNT = 160
    THUNDER_DUST_OPACITY = 0.085
    THUNDER_LAMP_RADIUS = 20.0
    THUNDER_LAMP_INTENSITY = 5.0
    THUNDER_FOG_DENSITY = 0.035
    THUNDER_MEDIA_DENSITY = 3.5
    THUNDER_MEDIA_TINT = float3(1.0, 0.9, 0.6)
    THUNDER_MEDIA_ABSORPTION = 0.05
    THUNDER_CLOUD_COVERAGE = 0.62
    THUNDER_CLOUD_DENSITY = 0.35
    THUNDER_SUN_INTENSITY = 0.85
    THUNDER_MUSIC_BASE = 0.30
    THUNDER_MUSIC_FADE_SECONDS = 3.0
    THUNDER_SAND_COLOR = float4(0.92, 0.80, 0.53, 1.0)
    THUNDER_DUST_COLOR = float4(0.80, 0.66, 0.37, 1.0)
    THUNDER_SKY_COLOR = float3(0.68, 0.56, 0.30)
    THUNDER_LIGHT_COLOR = float3(1.0, 0.89, 0.65)
    CHAT_MAX_CHARACTERS = 160
    CHAT_MAX_BYTES = 640
    CHAT_HISTORY_COUNT = 30
    CHAT_MESSAGE_LIFETIME = 60.0
    CHAT_INPUT_VISIBLE_CHARACTERS = 34
    CHAT_IDLE_HEIGHT = 154.0
    CHAT_SEND_INTERVAL = 1.0
    CHAT_NOTICE_SECONDS = 4.0
    CHAT_PANEL_SIZE = float2(520, 188)
    CHAT_PANEL_POSITION = float2(20, 104)
    CHAT_FONT_SIZE = 18.0
    CHAT_PANEL_COLOR = float4(0.06, 0.08, 0.12, 0.60)
    CHAT_FOCUSED_COLOR = float4(0.06, 0.08, 0.12, 0.90)

    // -------- map layout (units ~ Roblox studs) --------
    BASE_COUNT = 8
    SLOTS_PER_BASE = 22
    FLOOR_H = 15.0
    BASE_HALF_X = 23.0
    BASE_HALF_Z = 22.0
    BASE_CENTER_X = 58.0
    BASE_Z_STEP = 54.0
    GATE_HALF_WIDTH = 15.0
    CONVEYOR_HALF_WIDTH = 6.0
    CONVEYOR_HALF_LENGTH = 128.0 // portals meet the arena's end walls
    CONVEYOR_SPEED = 9.0
    GROUND_HALF = float2(100.0, 128.0)
    PORTAL_HEIGHT = 16.0
    PORTAL_FRAME_WIDTH = 2.4
    BASE_WINDOW_WIDTH = 6.0
    BASE_WINDOW_HEIGHT = 4.0
    BASE_WINDOW_Y = 8.5
    BASE_WINDOW_START = 8.0
    BASE_WINDOW_GAP = 11.0
    BASE_WINDOW_FRAME = 0.4
    BASE_WINDOW_REVEAL = 0.08 // frame faces stay clear of the wall cutout
    BASE_FLOOR_BACK_INSET = 0.4
    BASE_FLOOR_FRONT_INSET = 0.3
    BASE_SKIN_COUNT = 12
    EDEN_SKIN_INDEX = 11
    COL_WINDOW_GLASS = float4(0.72, 0.92, 1.0, 0.16)
    COL_EDEN_CORAL = float4(1.0, 0.30, 0.34, 1.0)
    COL_EDEN_CYAN = float4(0.42, 0.86, 0.96, 1.0)
    COL_LASER_GLOW = float4(3.0, 0.08, 0.04, 1.0)
    LASER_LIGHT_RADIUS = 12.0
    LASER_LIGHT_INTENSITY = 4.0
    LASER_BLOOM_INTENSITY = 0.12
    ARENA_BOUNDARY_HEIGHT = 80.0
    ARENA_BOUNDARY_THICKNESS = 2.0
    SCENE_EXPOSURE = 1.0

    // -------- player --------
    WALK_SPEED = 16.0
    CARRY_SPEED_FACTOR = 0.78
    CARRY_BASE_HEIGHT = 5.35
    CARRY_MODEL_HEIGHT = 6.0
    PLAYER_NAME_HEIGHT = 6.9
    PLAYER_NAME_SIZE = 20.0
    JUMP_SPEED = 24.0
    GRAVITY = 70.0
    PLAYER_RADIUS = 0.9
    PLAYER_HEIGHT = 5.0
    PLAYER_MAX_SLOPE = 0.7853982 // 45 degrees in radians
    PLAYER_STEP_HEIGHT = 1.0
    STAIR_WIDTH = 5.2
    CAMERA_DISTANCE = 19.0
    CAMERA_MIN_DISTANCE = 5.0
    CAMERA_MAX_DISTANCE = 40.0
    CAMERA_LOOK_SENS = 0.006
    CAMERA_KEY_SPEED = 2.2
    CAMERA_PITCH_MIN = -0.35
    CAMERA_PITCH_MAX = 1.2
    FALL_RESET_Y = -30.0

    // -------- economy --------
    START_CASH = 100
    REBIRTH_BASE_COST = 50000
    REBIRTH_COST_GROWTH = 2.5
    REBIRTH_INCOME_BONUS = 0.5
    MAX_REBIRTHS = 12
    CONVEYOR_SPAWN_INTERVAL = 3.1
    CONVEYOR_MAX_ITEMS = 18
    BRAINROT_SCALE = 1.35
    ITEM_LABEL_CLEARANCE = 0.65
    ITEM_LABEL_STEP = 0.64
    ITEM_LABEL_TOP = FLOOR_H - 3.0
    ITEM_NAME_SIZE = 58.0
    ITEM_RARITY_SIZE = 42.0
    ITEM_VALUE_SIZE = 52.0
    ITEM_NAME_WIDTH = 620.0
    INCOME_TICK = 1.0
    PAD_CAPACITY_SECONDS = 600.0

    // -------- interaction --------
    BUY_RANGE = 11.0
    STEAL_RANGE = 7.5
    SELL_RANGE = 10.0
    COLLECT_RANGE = 3.4
    STEAL_HOLD_TIME = 1.4
    DELIVER_RANGE = 20.0
    BAT_RANGE = 8.0
    BAT_COOLDOWN = 0.9
    STUN_TIME = 2.2
    BASE_LOCK_TIME = 60.0
    BASE_LOCK_COOLDOWN = 0.0
    MAX_MOVE_SPEED_SERVER = 60.0
    TELEPORT_TOLERANCE = 18.0

    // -------- shop --------
    SPEED_COIL_PRICE = 750
    GRAVITY_COIL_PRICE = 3000
    BAT_PRICE = 0
    COIL_SPEED_FACTOR = 1.5
    COIL_GRAVITY_FACTOR = 0.45
    UNLOCK_FLOOR2_PRICE = 15000
    TRAP_ARM_DELAY = 1.0
    TRAP_TRIGGER_RADIUS = 3.0
    TRAP_MAX_PER_PLAYER = 3
    TRAP_JAW_SEGMENTS = 12
    TRAP_METAL = float4(0.52, 0.58, 0.64, 1.0)
    TRAP_DARK_METAL = float4(0.14, 0.18, 0.22, 1.0)
    MUTATION_FX_COUNT = 8
    MUTATION_FX_SPEED = 1.6
    WALL_BOARD_WIDTH = 28.0
    WALL_BOARD_HEIGHT = 18.0
    WALL_BOARD_FONT_SIZE = 52.0
    WALL_BOARD_ROW_GAP = 1.6

    // -------- networking --------
    PHYSICS_FPS = 60.0
    MOVE_SEND_HZ = 30.0
    MAX_PLAYERS = 8
    DEBUG_CHEATS = false
}


let public {
    // -------- palette (bright Roblox plastic) --------
    COL_GRASS = float4(0.36, 0.74, 0.28, 1.0)
    COL_GRASS_DARK = float4(0.24, 0.58, 0.20, 1.0)
    COL_PATH = float4(0.45, 0.80, 0.34, 1.0)
    COL_CONVEYOR = float4(0.86, 0.12, 0.10, 1.0)
    COL_CONVEYOR_STRIPE = float4(1.0, 0.85, 0.15, 1.0)
    COL_FENCE = float4(0.95, 0.95, 0.98, 1.0)
    COL_GATE = float4(1.0, 0.25, 0.25, 0.55)
    COL_GATE_OPEN = float4(0.3, 1.0, 0.4, 0.35)
    COL_CASH = float4(1.0, 0.85, 0.2, 1.0)
    COL_RED = float4(1.0, 0.25, 0.25, 1.0)
    COL_WHITE = float4(1.0, 1.0, 1.0, 1.0)
    COL_BLACK = float4(0.05, 0.05, 0.07, 1.0)
    COL_SKIN = float4(0.98, 0.80, 0.30, 1.0)
    COL_SKY = float3(0.52, 0.78, 1.0)

    PLAYER_COLORS = [
        float4(0.95, 0.30, 0.30, 1.0),
        float4(0.25, 0.60, 1.00, 1.0),
        float4(0.35, 0.85, 0.40, 1.0),
        float4(1.00, 0.80, 0.20, 1.0),
        float4(0.75, 0.40, 1.00, 1.0),
        float4(1.00, 0.55, 0.20, 1.0),
        float4(0.30, 0.90, 0.90, 1.0),
        float4(1.00, 0.45, 0.75, 1.0)
    ]
}
