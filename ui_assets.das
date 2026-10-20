require engine.core

var private {
    uiFont : FontId
    chatFont : FontId
    navAtlas : TextureId
    brainrotAtlas : TextureId
    gearAtlas : TextureId
    baseAtlas : TextureId
}

def public load_ui_assets {
    uiFont = request_font("assets/fonts/rounded-bold.ttf")
    chatFont = request_font("assets/fonts/NotoSans-Bold.ttf")
    navAtlas = request_texture("assets/ui/navigation.png")
    brainrotAtlas = request_texture("assets/ui/brainrot_atlas.png")
    gearAtlas = request_texture("assets/ui/gear_atlas.png")
    baseAtlas = request_texture("assets/ui/base_atlas.png")
}

def public game_font : FontId { return uiFont }
def public chat_font : FontId { return chatFont }
def public navigation_texture : TextureId { return navAtlas }
def public brainrot_texture : TextureId { return brainrotAtlas }
def public gear_texture : TextureId { return gearAtlas }
def public base_texture : TextureId { return baseAtlas }

def public atlas_rect(i, cols, rows : int) : float4 {
    return float4(float(i % cols) / float(cols), float(i / cols) / float(rows), 1.0 / float(cols), 1.0 / float(rows))
}
