require engine.core
require engine.networking
require constants
require server_game
require thunder_server


[export]
def on_initialize {
    set_physics_fps(PHYSICS_FPS)
    set_replication_fps(30.0)
    spawn_thunder_clock()
    print("[server] brainrot server ready")
}

[export]
def on_update {
    server_update(get_delta_time())
}

[export]
def on_exit {
    server_save()
}
