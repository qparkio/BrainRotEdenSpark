require engine.core
require constants

// Cross-module mutable state (client side).


// recolorable pieces of one base building (skins repaint these)
struct public BaseParts {
    walls : array<NodeId>
    trims : array<NodeId>
    floors : array<NodeId>
    aisles : array<NodeId>
    stands : array<NodeId>
    floorGates : array<NodeId>
    floorGateBlockers : array<NodeId>
    edenDetail : NodeId
}

var public {
    // scene infrastructure
    cameraNode : NodeId
    sunNode : NodeId
    renderSettingsNode : NodeId
    stormGround : NodeId
    stormGrassNodes : array<NodeId>
    stormLampBulbs : array<NodeId>
    stormLampLights : array<NodeId>
    thunderWeatherBlend : float = 0.0
    mapRoot : NodeId
    basePlasticMaterial : MaterialId
    baseStudMaterial : MaterialId
    edenSurfaceMaterial : MaterialId

    // map references, filled by build_map()
    baseParts : array<BaseParts>
    baseSigns : NodeId[8] // owner name text above each gate
    baseLockTexts : NodeId[8] // "UNLOCKED" / countdown text
    gateRoots : NodeId[8]
    gateBlockers : NodeId[8]
    floorBarriers : NodeId[8] // unused (kept for layout compatibility)
    upperRoots : NodeId[8] // the whole upper storey of each base, shown after the upgrade
    thirdRoots : NodeId[8]
    secondRoofs : NodeId[8]
    lowRoofs : NodeId[8] // flat roof over the single-storey base, hidden after the upgrade
    lockPadTexts : NodeId[8] // text above the yellow lock pad
    upgradePadTexts : NodeId[8] // text above the purple upgrade pad
    padTitles : NodeId[176] // the white "Collect" line above each pad
    padTexts : NodeId[176]
    standTexts : NodeId[176]
    standNodes : NodeId[176]
    padNodes : NodeId[176]

    // local player
    localPlayer : NodeId
    localAvatar : NodeId // replicated node owned by this client
    localBase : int = -1
    cameraYaw : float = 0.0
    cameraPitch : float = 0.45
    cameraDistance : float = CAMERA_DISTANCE
    localStunned : bool = false
    localCarrying : bool = false

    // UI
    uiCanvas : NodeId
    inWorld : bool = false
    modalOpen : bool = false
    chatTyping : bool = false
    chatInputNode : NodeId
    chatPanelNode : NodeId
    baseMultiTexts : NodeId[8]
    cashBoardRows : NodeId[8]
    stealsBoardRows : NodeId[8]
}
