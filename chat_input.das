require engine.core
require daslib/utf8_utils
require constants
require game_state


// Text characters use the engine's Unicode events; game controls stay in action sets.
class ChatInput : UIComponent {
    text : string
    field : NodeId
    private caret : int = 0
    private selectAll : bool = false
    private pendingSurrogate : uint = 0u

    def set_text(value : string) {
        text = value
        caret = utf8_length(value)
        selectAll = false
        pendingSurrogate = 0u
    }

    def character(codepoint : uint) {
        if (codepoint >= 0xd800u && codepoint <= 0xdbffu) {
            pendingSurrogate = codepoint
            return
        }
        var ch = codepoint
        if (codepoint >= 0xdc00u && codepoint <= 0xdfffu && pendingSurrogate != 0u) {
            ch = utf16_to_utf32(pendingSurrogate, codepoint)
        }
        pendingSurrogate = 0u
        if (ch < 32u || ch == 127u || ch > 0x10ffffu || (ch >= 0xd800u && ch <= 0xdfffu) || ch == 0x2028u || ch == 0x2029u) {
            return
        }
        var points <- utf8_decode(selectAll ? "" : text)
        caret = selectAll ? 0 : clamp(caret, 0, length(points))
        selectAll = false
        if (length(points) >= CHAT_MAX_CHARACTERS) {
            return
        }
        var at = length(points)
        resize(points, at + 1)
        while (at > caret) {
            points[at] = points[at - 1]
            at--
        }
        points[caret] = ch
        caret++
        var inscope encoded <- utf8_encode(points)
        text = string(encoded)
    }

    def keyboard(event : RawKeyboardInputEvent) {
        let control = event.shifts.LCtrl || event.shifts.RCtrl
        if (control && event.buttonIdx == KeyCode.A) {
            selectAll = true
            return
        }
        var points <- utf8_decode(text)
        caret = clamp(caret, 0, length(points))
        if (event.buttonIdx == KeyCode.Back || event.buttonIdx == KeyCode.Delete) {
            if (selectAll) {
                clear(points)
                caret = 0
            } elif (event.buttonIdx == KeyCode.Back && caret > 0) {
                erase(points, caret - 1)
                caret--
            } elif (event.buttonIdx == KeyCode.Delete && caret < length(points)) {
                erase(points, caret)
            }
            selectAll = false
            var inscope encoded <- utf8_encode(points)
            text = string(encoded)
        } elif (event.buttonIdx == KeyCode.Left) {
            caret = max(0, caret - 1)
            selectAll = false
        } elif (event.buttonIdx == KeyCode.Right) {
            caret = min(length(points), caret + 1)
            selectAll = false
        } elif (event.buttonIdx == KeyCode.Home) {
            caret = 0
            selectAll = false
        } elif (event.buttonIdx == KeyCode.End) {
            caret = length(points)
            selectAll = false
        } elif (!control && event.buttonIdx != KeyCode.Return && event.buttonIdx != KeyCode.NumpadEnter) {
            character(event.charCode)
        }
    }

    def override on_update {
        let focused = get_ui_focused_node() == nodeId
        if (focused) {
            for (cmd in get_input_command_buffer()) {
                if (cmd is RawKeyboardInputEvent) {
                    let event = cmd as RawKeyboardInputEvent
                    if (event.kind == RawKeyboardInputEventKind.KeyDown) {
                        keyboard(event)
                    }
                }
            }
        }
        let points <- utf8_decode(text)
        caret = clamp(caret, 0, length(points))
        var visible : array<uint>
        let start = max(0, caret - CHAT_INPUT_VISIBLE_CHARACTERS)
        for (i in range(start, min(length(points), start + CHAT_INPUT_VISIBLE_CHARACTERS))) {
            if (focused && i == caret) {
                push(visible, 124u)
            }
            push(visible, points[i])
        }
        if (focused && caret == length(points)) {
            push(visible, 124u)
        }
        var inscope encoded <- utf8_encode(visible)
        field?.UIText.text = !focused && empty(text) ? "Press Enter to chat..." : string(encoded)
        field?.UIText.color = selectAll ? float4(0.45, 0.8, 1.0, 1.0) : COL_WHITE
    }
}
