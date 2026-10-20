# Development

The game is an EdenSpark project written in Gen2 Daslang. Runtime assets are already included: Blender, Python, and Node.js are not required just to play.

## Runtime layout

| Layer | Modules |
| --- | --- |
| Entry points | `main.das` (client), `dedicated.das` (server) |
| Shared definitions | `constants.das`, `layout.das`, `brainrot_data.das`, `gear_data.das`, `skin_data.das` |
| Shared runtime / network state | `game_state.das`, `components.das`, `net_commands.das`, `event_state.das` |
| Server rules | `server_game.das`, `thunder_server.das`, `chat_server.das` |
| Player and interaction | `player.das`, `avatar.das`, `interact.das`, `dress.das`, `traps.das` |
| World and presentation | `world.das`, `models.das`, `items_view.das`, `mutations.das`, `fx.das`, `leaderboards.das` |
| UI and audio | `ui.das`, `ui_assets.das`, `chat.das`, `chat_input.das`, `chat_text.das`, `sounds.das` |
| Thunder presentation | `thunder_view.das`, `thunder_vfx.das`, `thunder_weather.das` |

The server owns purchases, progression, inventory, stealing outcomes, and saving. Player movement is client-driven with server validation; it is not a full server-side movement simulation.

## Working on a copy

Keep resource `.meta` files: materials, prefabs, and imported models depend on their GUIDs. `manifest.blk` points to the initial `main.prefab` by GUID.

Use a separate project identity and storage namespace for destructive gameplay experiments. The public snapshot keeps the authored runtime identity but excludes launcher caches, local saves, raw QA logs, and editor-machine configuration.

`DEBUG_CHEATS` is `false`. Do not enable money, inventory, or progression fixtures against a real player profile.

## Asset checks

Install the optional tooling dependencies:

```sh
python -m pip install -r tools/requirements.txt
python tools/qa/validate_assets.py
```

The checker verifies the 56 roster GLBs, their bounds and feet, unique model bytes, 79 thumbnail cells, UI import settings, world textures, and the EdenSpark logo. It writes `tools/qa/asset_validation.json`, which is ignored by Git. This is a static asset check, not a gameplay or networking test.

## Rebuilding assets

From the repository root, with Blender available on your command line:

```sh
blender -b --factory-startup -P tools/blender/make_brainrots.py -- .
blender -b --factory-startup -P tools/blender/render_ui.py -- .
blender -b --factory-startup -P tools/blender/render_bases.py -- .
python tools/textures/pack_ui.py .
```

`make_brainrots.py` reads the roster and writes GLBs plus the matching bounds/file tables. The render scripts generate the actual model thumbnails before `pack_ui.py` assembles the atlases. Commit the model, bounds table, and atlas changes together.

Other tools:

- `tools/textures/`: procedural tiles, world detail textures, and official-logo rasterization. `render_eden_branding.cjs` optionally uses Node.js with `sharp`.
- `tools/vfx/make_thunder_assets.py`: procedural Thunder mesh and sand texture.
- `tools/sounds/build_recorded_sfx.py`: prepares the current Kenney CC0 effects from source packs using NumPy and FFmpeg; see the script's arguments.
- `tools/sounds/gen_sounds.py`: earlier synthesized sound generator; running it over the current audio directory replaces the shipped effects.

No model or texture rebuild is necessary for a normal source checkout.

## Thunder

The first automatic event begins thirty minutes after room creation. It lasts five minutes; the next event starts twenty-five minutes after it ends. Rare-and-above rarity **weights** are multiplied by two, which is not the same as doubling the final drop probability.

The first player's console command `thunder_start` requests an immediate event through the server. The server checks that player's ownership of base 0 and ignores repeat starts while an event is active.

[Back to the project](../README.md)
