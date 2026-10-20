# Validation notes

## Public source snapshot — 20 October 2026

The publication snapshot preserves the game scripts and runtime asset bytes. The launcher manifest keeps runtime identity and rendering settings while replacing machine-local screenshot paths with repository images. Launcher history, cached packages, local saves, assistant configuration, raw QA logs, and historical one-off patch scripts are excluded.

The exported source was checked for complete local module imports and resource metadata, a valid initial-prefab GUID, readable image files, working local documentation links, and the absence of credentials or machine-specific paths. `tools/qa/validate_assets.py` was run against the export.

These checks validate repository packaging and static assets. They are not a fresh full gameplay run.

## Earlier gameplay audit — 4 October 2026

The existing project audit and saved QA receipts report testing with two native EdenSpark clients. Destructive fixtures used a separate project and storage namespace before reconnecting the main build.

Recorded coverage includes purchases, income collection, sales, three-item fusion, stealing and delivery, all eleven gear items, twelve rebirth levels, upper-floor access, locked entrances, mutations, leaderboard updates, profile restoration, and rejection of debug money/item commands in the production configuration.

Thunder receipts report 41 event checks, 23 audio checks, and 12 later checks of active music-stream lifetimes and crossfades. Event timing boundaries were exercised with accelerated server clocks in a disposable test room.

## Boundaries

- The project configures eight player slots; the archived audit covers **two local clients**, not an eight-player internet session.
- A complete thirty-minute event cycle was not observed at real-time speed in those recorded tests.
- The six gallery screenshots are captures from the earlier EdenSpark build. They do not prove current runtime behavior.
- Static audio checks establish file integrity and levels, not subjective listening quality or ownership of legacy clips.
- Historical results describe the recorded build and should be re-run after gameplay, engine, or network changes.

[Back to the project](../README.md)
