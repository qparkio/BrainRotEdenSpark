require engine.core
require brainrot_files
require constants
require event_state


let private {
    SFX_NAMES = fixed_array("buy", "collect", "click", "jump", "land", "step1", "step2", "swing", "hit", "steal",
        "alarm", "deliver", "error", "lock", "unlock", "rebirth", "rare", "shop", "sell", "pop")
    // Previously imported fan-game clips; their original-game provenance is unverified.
    ORIG_NAMES = fixed_array("orig_stealing", "orig_steal_loud", "orig_steal2", "orig_craft", "orig_lucky", "orig_brainrot_steal")
    MUSIC_BASE = 0.22
}

struct PlayingVoice {
    handle : SoundHandle
    stopAt : float
}

var private {
    sfx : table<string; SoundId>
    voices : array<SoundId>
    playing : array<PlayingVoice>
    musicId : SoundId
    thunderMusicId : SoundId
    musicNode : NodeId
    alarmHandle : SoundHandle
    masterVolume : float = 1.0
    sfxVolume : float = 1.0
    voiceVolume : float = 0.3
    musicVolume : float = 1.0
}

// Characters without a clip of their own borrow the voice of a relative.
def private voice_file(slug : string) : string {
    var s = slug
    if (slug == "los_noobinis" || slug == "noobini_pizzanini") {
        return "" // the only clip we have for them contains a Roblox advert, so they stay silent
    } elif (slug == "tree_tree_tree_sahur" || slug == "pop_pop_sahur") {
        s = "tung_tung_tung_sahur"
    } elif (slug == "tim_cheese") {
        s = "talpa_di_fero"
    } elif (slug == "bandito_axolito") {
        s = "bandito_bobritto"
    } elif (slug == "gato_celesto") {
        s = "fluriflura"
    }
    return "assets/voices/{s}.mp3"
}

def public load_sounds() {
    for (n in SFX_NAMES) {
        sfx[n] = request_sound("assets/sounds/{n}.wav")
    }
    for (n in ORIG_NAMES) {
        sfx[n] = request_sound("assets/sounds/{n}.mp3")
    }
    voices |> clear()
    for (slug in BRAINROT_MODEL_FILES) {
        let path = voice_file(slug)
        if (empty(path)) {
            voices |> push(SoundId())
        } else {
            voices |> push(request_sound(path))
        }
    }
    musicId = request_sound("assets/sounds/orig_theme.mp3")
    thunderMusicId = request_sound("assets/sounds/thunder_theme.ogg")
}


////////////////////////////////////////////////////////////////////////////////
// volume settings (0..1)
////////////////////////////////////////////////////////////////////////////////

def private apply_music_volume {
    if (musicNode.isAlive) {
        get_component(musicNode) $(var fader : MusicCrossfade?) {
            fader.apply_volumes()
        }
    }
}

def public set_master_volume(v : float) {
    masterVolume = clamp(v, 0.0, 1.0)
    apply_music_volume()
}

def public set_sfx_volume(v : float) {
    sfxVolume = clamp(v, 0.0, 1.0)
}

def public set_voice_volume(v : float) {
    voiceVolume = clamp(v, 0.0, 1.0)
}

def public set_music_volume(v : float) {
    musicVolume = clamp(v, 0.0, 1.0)
    apply_music_volume()
}

def public get_master_volume : float {
    return masterVolume
}

def public get_sfx_volume : float {
    return sfxVolume
}

def public get_voice_volume : float {
    return voiceVolume
}

def public get_music_volume : float {
    return musicVolume
}


def public print_audio_status() {
    print("[Audio] active={is_audio_active()} master={masterVolume} music={musicVolume} effects={sfxVolume} voices={voiceVolume} playing={get_playing_sounds_count()}")
    print("[Audio] themeLoaded={is_resource_alive(musicId)} thunderLoaded={is_resource_alive(thunderMusicId)}")
    if (musicNode.isAlive) {
        get_component(musicNode) $(var audio : AudioSource?) {
            print("[Audio] theme playing={is_playing(audio.currentSound)} gain={audio.volume} position={get_position(audio.currentSound)}")
        }
        get_component(musicNode) $(var fader : MusicCrossfade?) {
            get_component(fader.eventNode) $(var audio : AudioSource?) {
                print("[Audio] thunder playing={is_playing(audio.currentSound)} gain={audio.volume} position={get_position(audio.currentSound)}")
            }
        }
    }
}


def private source_gain(name : string) : float {
    for (original in ORIG_NAMES) {
        if (name == original) {
            return LEGACY_SFX_GAIN
        }
    }
    return 1.0
}


def private track_legacy_sound(name : string; handle : SoundHandle) {
    if (source_gain(name) < 1.0) {
        playing |> push(PlayingVoice(handle = handle, stopAt = get_time() + LEGACY_SFX_MAX_SECONDS))
    }
}


def public play_sfx(name : string; volume : float = 1.0; pitch : float = 1.0) {
    let id = sfx?[name] ?? SoundId()
    if (!id) {
        return
    }
    let h = play_sound(id)
    set_volume(h, clamp(volume, 0.0, 1.0) * masterVolume * sfxVolume * source_gain(name))
    track_legacy_sound(name, h)
    if (pitch != 1.0) {
        set_pitch(h, pitch)
    }
}

// positional sound; falls off with distance from the listener
def public play_sfx_at(name : string; pos : float3; volume : float = 1.0; pitch : float = 1.0) {
    let id = sfx?[name] ?? SoundId()
    if (!id) {
        return
    }
    let h = play_3d_sound(id, pos, inverse_distance_attenuation(18.0))
    set_volume(h, clamp(volume, 0.0, 1.0) * masterVolume * sfxVolume * source_gain(name))
    track_legacy_sound(name, h)
    if (pitch != 1.0) {
        set_pitch(h, pitch)
    }
}

// the character's own voice line, cut after `maxSeconds` so long clips do not pile up
def public play_voice(defId : int; pos : float3; volume : float = 1.0; maxSeconds : float = 4.5; positional : bool = true) {
    if (defId < 0 || defId >= length(voices)) {
        return
    }
    let id = voices[defId]
    if (!id) {
        return
    }
    if (masterVolume * voiceVolume < 0.01) {
        return
    }
    var h : SoundHandle
    if (positional) {
        h = play_3d_sound(id, pos, inverse_distance_attenuation(40.0))
    } else {
        h = play_sound(id)
    }
    set_volume(h, volume * masterVolume * voiceVolume)
    playing |> push(PlayingVoice(handle = h, stopAt = get_time() + min(maxSeconds, 3.2)))
}

def public update_sounds {
    let t = get_time()
    var i = length(playing) - 1
    while (i >= 0) {
        if (t >= playing[i].stopAt) {
            stop(playing[i].handle)
            playing |> erase(i)
        }
        i--
    }
}

def public play_alarm_once() {
    let id = sfx?["alarm"] ?? SoundId()
    if (!id) {
        return
    }
    if (is_playing(alarmHandle)) {
        return
    }
    alarmHandle = play_sound(id)
    set_volume(alarmHandle, 0.8 * masterVolume * sfxVolume)
}

def private set_music_source_gain(node : NodeId; gain : float) {
    get_component(node) $(var audio : AudioSource?) {
        audio.volume = gain
        // AudioSource fields describe the source; update the live mixer handle too.
        set_volume(audio.currentSound, gain)
    }
}


class MusicCrossfade : Component {
    eventNode : NodeId
    private blend : float = 0.0
    private eventStarted : bool = false

    def apply_volumes() {
        set_music_source_gain(nodeId, MUSIC_BASE * musicVolume * masterVolume * (1.0 - blend))
        set_music_source_gain(eventNode, THUNDER_MUSIC_BASE * musicVolume * masterVolume * blend)
    }

    def stop_sources() {
        get_component(nodeId) $(var audio : AudioSource?) {
            audio.stop()
        }
        get_component(eventNode) $(var audio : AudioSource?) {
            audio.stop()
        }
        eventStarted = false
    }

    def override on_update {
        var state = find_component(type<ThunderState>)
        let active = state != null && state.active
        if (active && !eventStarted) {
            get_component(eventNode) $(var audio : AudioSource?) {
                audio.volume = 0.0
                audio.playSource(thunderMusicId)
                eventStarted = true
            }
        }
        let target = active ? 1.0 : 0.0
        blend = clamp(blend + sign(target - blend) * get_delta_time() / THUNDER_MUSIC_FADE_SECONDS, 0.0, 1.0)
        apply_volumes()
        if (!active && blend == 0.0 && eventStarted) {
            get_component(eventNode) $(var audio : AudioSource?) {
                audio.stop()
            }
            eventStarted = false
        }
    }

    def override on_destroy {
        stop_sources()
    }
}


def public start_music() {
    if (!musicId || musicNode.isAlive) {
        return
    }
    musicNode = create_node(NodeData(name = "music"))
    add_component(musicNode, new AudioSource(source = musicId, isLoop = true, autoPlay = true, volume = MUSIC_BASE * musicVolume * masterVolume))
    let eventNode = create_node(NodeData(name = "thunderMusic", parent = musicNode))
    add_component(eventNode, new AudioSource(source = thunderMusicId, isLoop = true, autoPlay = false, volume = 0.0))
    add_component(musicNode, new MusicCrossfade(eventNode = eventNode))
}

def public stop_music() {
    if (musicNode.isAlive) {
        get_component(musicNode) $(var fader : MusicCrossfade?) {
            fader.stop_sources()
        }
        remove_node(musicNode)
    }
    musicNode = NodeId()
}
