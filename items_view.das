require engine.core
require constants
require brainrot_data
require components
require models
require world
require game_state
require layout
require mutations


def private hue_color(t : float) : float4 {
    return float4(0.55 + 0.45 * sin(t), 0.55 + 0.45 * sin(t + 2.094), 0.55 + 0.45 * sin(t + 4.188), 1.0)
}

// Dresses a replicated BrainrotItem with a model, floating labels and idle animation.
class ItemView : Component {
    private root : NodeId
    private labelRoot : NodeId
    private rarityText : NodeId
    private nameText : NodeId
    private incomeText : NodeId
    private priceText : NodeId
    private builtDef : int = -1
    private builtMutation : int = -1
    private builtLabelSize : float = 0.0
    private labelSpacing : float = ITEM_LABEL_STEP
    private t : float = 0.0
    private phase : float = 0.0
    private lastState : int = -1
    private rarity : int = 0
    private mutation : int = 0

    def override on_initialize {
        phase = random_float() * 6.28
    }

    def private build(defId, mut : int) {
        if (root.isAlive) {
            remove_node(root)
        }
        if (labelRoot.isAlive) {
            remove_node(labelRoot)
        }
        builtDef = defId
        builtMutation = mut
        builtLabelSize = ITEM_NAME_SIZE
        mutation = mut
        let bd = BRAINROTS[defId]
        rarity = bd.rarity
        root = build_brainrot(nodeId, defId, mut)
        if (mut > 0) {
            add_component(root, new MutationView(mutation = mut, modelHeight = brainrot_height(defId)))
        }
        let h = brainrot_height(defId) * BRAINROT_SCALE
        labelSpacing = min(ITEM_LABEL_STEP, (ITEM_LABEL_TOP - h - ITEM_LABEL_CLEARANCE) / 3.0)
        let labelStep = labelSpacing
        let labelScale = labelStep / ITEM_LABEL_STEP
        labelRoot = create_node(NodeData(name = "labels", parent = nodeId, position = float3(0, h + ITEM_LABEL_CLEARANCE, 0)))
        rarityText = label3d(labelRoot, "", float3(0, labelStep * 2.0, 0), ITEM_RARITY_SIZE * labelScale, RARITY_COLORS[bd.rarity])
        nameText = label3d(labelRoot, "", float3(0, labelStep * 3.0, 0), ITEM_NAME_SIZE * labelScale, COL_WHITE, ITEM_NAME_WIDTH)
        incomeText = label3d(labelRoot, "", float3(0, labelStep, 0), ITEM_VALUE_SIZE * labelScale, float4(1.0, 0.92, 0.18, 1.0))
        priceText = label3d(labelRoot, "", float3(0), ITEM_VALUE_SIZE * labelScale, float4(0.3, 0.95, 0.35, 1.0))
        let rarityName = RARITY_NAMES[bd.rarity]
        let mutName = MUTATION_NAMES[mut]
        rarityText?.Text3D.text = empty(mutName) ? rarityName : "{mutName} {rarityName}"
        if (mut > 0) {
            nameText?.Text3D.color = MUTATION_COLORS[mut]
        }
        nameText?.Text3D.text = bd.name
        lastState = -1
    }

    def override on_update {
        var it = get_component(nodeId, type<BrainrotItem>)
        if (it == null) {
            return
        }
        if (it.defId != builtDef || it.mutation != builtMutation || builtLabelSize != ITEM_NAME_SIZE) {
            build(it.defId, it.mutation)
        }
        let dt = get_delta_time()
        t += dt
        // Stack along camera-up: row spacing stays compact when looking down at a creature.
        labelRoot.worldRotation = quat4(0.0, 0.0, 0.0)
        let labelUp = cameraNode.worldRotation * UP
        if (it.state == 0 || it.state == 3) {
            priceText?.Text3D.text = format_cash(scale_money(item_price(it.defId,it.mutation),1.0+float(it.purchaseCount)*.5))
        }
        if (it.state != lastState) {
            lastState = it.state
            incomeText?.Text3D.text = "{format_cash(item_income(it.defId, it.mutation))}/s"
            let showPrice = it.state == 0 || it.state == 3
            priceText.isActive = showPrice
            if (showPrice) {
                priceText?.Text3D.text = format_cash(scale_money(item_price(it.defId, it.mutation),1.0+float(it.purchaseCount)*.5))
            }
            rarityText.isActive = it.state != 2
            nameText?.Text3D.text = it.state == 2 ? "{BRAINROTS[it.defId].name} (STOLEN!)" : BRAINROTS[it.defId].name
        }
        let nearOwned = it.state == 1 && it.baseIndex == localBase && localPlayer.isAlive && flat_distance(localPlayer.worldPosition, nodeId.worldPosition) <= SELL_RANGE && abs(localPlayer.worldPosition.y - nodeId.worldPosition.y) < 5.0
        if (it.state == 1) {
            priceText.isActive = nearOwned
            priceText?.Text3D.text = "[E] Sell"
            priceText?.Text3D.color = COL_WHITE
        } else {
            priceText?.Text3D.color = float4(0.3, 0.95, 0.35, 1.0)
        }
        var row = priceText.isActive ? 1 : 0
        incomeText.localPosition = labelUp * float(row) * labelSpacing
        row++
        if (rarityText.isActive) {
            rarityText.localPosition = labelUp * float(row) * labelSpacing
            row++
        }
        nameText.localPosition = labelUp * float(row) * labelSpacing
        // tier labels shimmer like on the wiki: God rainbow, Secret black/white, OG yellow/black
        if (rarity == 5) {
            rarityText?.Text3D.color = hue_color(t * 3.0)
        } elif (rarity == 6) {
            let k = sin(t * 4.0) * 0.5 + 0.5
            rarityText?.Text3D.color = float4(k, k, k, 1.0)
        } elif (rarity == 7) {
            let k = sin(t * 4.0) * 0.5 + 0.5
            rarityText?.Text3D.color = float4(1.0 * (0.4 + 0.6 * k), 0.8 * (0.4 + 0.6 * k), 0.1 * k, 1.0)
        }
        if (mutation == 3) {
            nameText?.Text3D.color = hue_color(t * 2.5)
        }
        // idle animation: wobble on the belt, breathing on a pedestal, spin while stolen
        if (it.state == 0 || it.state == 3) {
            root.localRotation = quat4(0.0, 0.0, sin(t * 4.0 + phase) * 0.07)
            root.localPosition = float3(0.0, abs(sin(t * 3.0 + phase)) * 0.25, 0.0)
            root.localScale = float3(BRAINROT_SCALE)
        } elif (it.state == 1) {
            root.localScale = float3(BRAINROT_SCALE, BRAINROT_SCALE * (1.0 + sin(t * 3.0 + phase) * 0.035), BRAINROT_SCALE)
            root.localRotation = quat4(0.0, 0.0, sin(t * 1.4 + phase) * 0.03)
            root.localPosition = float3(0.0)
        } else {
            let carryScale = min(BRAINROT_SCALE * 0.8, CARRY_MODEL_HEIGHT / brainrot_height(it.defId))
            root.localScale = float3(carryScale)
            root.localPosition = float3(0.0)
            root.localRotation = quat4(0.0, t * 3.0, 0.0)
        }
        labelRoot.localPosition = float3(0.0, brainrot_height(it.defId) * root.localScale.y + root.localPosition.y + ITEM_LABEL_CLEARANCE, 0.0)
    }
}
