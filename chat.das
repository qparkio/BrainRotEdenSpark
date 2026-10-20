require engine.core
require engine.networking
require engine.ui.fast_ui
require constants
require game_state
require net_commands
require ui_assets
require chat_text
require chat_input


def private chat_box(parent : NodeId; name : string; size, position : float2; color : float4) : NodeId {
    let node = create_node(NodeData(name = name, parent = parent))
    add_component(node, new UIImage(color = color, size = size))
    set_frame_size(node, size)
    set_frame_pos(node, position)
    add_anchor(node, float2(0))
    set_frame_pivot(node, float2(0))
    return node
}


def private chat_text_node(parent : NodeId; value : string; position : float2; fontSize : float; anchored : bool = true) : NodeId {
    let node = text(value)
    node.set_parent(parent, AddChildStrategy.KeepLocalTransform)
    node?.UIText.fontId = chat_font()
    node?.UIText.fontSize = fontSize
    node?.UIText.color = COL_WHITE
    node?.UIText.effect = TextEffect.None
    node?.UIText.effectColor = float4(0, 0, 0, 1)
    node?.UIText.effectThickness = 1.0
    node?.UIText.horAlignment = TextHorAlignment.Left
    node?.UIText.vertAlignment = TextVertAlignment.Top
    node?.UIText.wordWrapping = false
    node?.UIText.autoResizeFrame = true
    set_frame_pos(node, position)
    if (anchored) {
        add_anchor(node, float2(0))
    }
    set_frame_pivot(node, float2(0))
    return node
}


def public close_chat_input() {
    if (chatInputNode.isAlive && get_ui_focused_node() == chatInputNode) {
        set_ui_focus_node(null)
    }
    chatTyping = false
}


def private on_chat_focus(evt : UIFocusEvent) {
    chatTyping = evt.eventType == UIFocusEventType.FocusIn
}


class ChatView : Component {
    private panel : NodeId
    private body : NodeId
    private scroll : NodeId
    private history : NodeId
    private header : NodeId
    private toggleButton : NodeId
    private notice : NodeId
    private input : NodeId
    private send : NodeId
    private lines : array<string>
    private receivedAt : array<float>
    private collapsed : bool = false
    private unread : int = 0
    private scrollPending : int = 0
    private noticeUntil : float = 0.0
    private sendReadyAt : float = 0.0

    def show_notice(message : string) {
        notice?.UIText.text = message
        noticeUntil = get_time() + CHAT_NOTICE_SECONDS
    }

    def rebuild_history() {
        var display = ""
        for (line in lines) {
            display = empty(display) ? line : "{display}\n{line}"
        }
        history?.UIText.text = display
        scrollPending = 2
    }

    def append(author, message : string) {
        lines |> push("{author}: {message}")
        receivedAt |> push(get_time())
        if (length(lines) > CHAT_HISTORY_COUNT) {
            erase(lines, 0)
            erase(receivedAt, 0)
        }
        rebuild_history()
        if (collapsed) {
            unread++
        }
    }

    def focus_input() {
        if (!inWorld || modalOpen || !has_network()) {
            return
        }
        collapsed = false
        unread = 0
        body.isActive = true
        input.isActive = true
        send.isActive = true
        set_frame_size(panel, CHAT_PANEL_SIZE)
        set_ui_focus_node(get_component(input, type<ChatInput>))
        chatTyping = get_ui_focused_node() == input
        show_mouse_cursor(true)
    }

    def toggle() {
        close_chat_input()
        collapsed = !collapsed
        if (!collapsed) {
            unread = 0
            scrollPending = 2
        }
    }

    def submit() {
        if (!inWorld || modalOpen || !has_network()) {
            return
        }
        let message = clean_chat_text(get_component(input, type<ChatInput>).text)
        if (empty(message)) {
            show_notice("Type a message, up to {CHAT_MAX_CHARACTERS} characters.")
            return
        }
        if (get_time() < sendReadyAt) {
            show_notice("Please wait a moment before sending again.")
            return
        }
        sendReadyAt = get_time() + CHAT_SEND_INTERVAL
        broadcast_net_command(ChatSend(message = message))
        get_component(input, type<ChatInput>).set_text("")
        close_chat_input()
    }

    def override on_initialize {
        chatTyping = false
        panel = chat_box(nodeId, "chatPanel", CHAT_PANEL_SIZE, CHAT_PANEL_POSITION, CHAT_PANEL_COLOR)
        chatPanelNode = panel
        toggleButton = chat_box(panel, "chatToggle", float2(CHAT_PANEL_SIZE.x, 30), float2(0), float4(0.18, 0.21, 0.28, 0.92))
        add_component(toggleButton, new UIButton(onClick = @() { toggle() }))
        header = chat_text_node(toggleButton, "Chat:", float2(12, 2), 21.0)
        body = chat_box(panel, "chatBody", float2(CHAT_PANEL_SIZE.x, CHAT_PANEL_SIZE.y - 30), float2(0, 30), float4(0))
        scroll = chat_box(body, "chatScroll", float2(CHAT_PANEL_SIZE.x - 24, 96), float2(12, 4), COL_WHITE)
        add_component(scroll, new UIMask(showMaskSource = false))
        // UIScrollArea owns this frame's position. An anchor would reset it each frame.
        history = chat_text_node(scroll, "", float2(0), CHAT_FONT_SIZE, false)
        history.name = "chatHistory"
        history?.UIText.wordWrapping = true
        set_frame_size(history, float2(CHAT_PANEL_SIZE.x - 32, 0))
        add_component(scroll, new UIScrollArea(content = get_component(history, type<UIFrame>), maskArea = get_component(scroll, type<UIMask>), scrollDirection = ScrollDirection.Vertical, enableOverscroll = false))
        notice = chat_text_node(body, "Enter — type / send a message", float2(12, 101), 15.0)
        notice?.UIText.color = float4(0.65, 0.84, 1.0, 1.0)
        input = chat_box(body, "chatInput", float2(CHAT_PANEL_SIZE.x - 106, 34), float2(12, 120), float4(0.07, 0.09, 0.13, 0.95))
        let field = chat_text_node(input, "", float2(8, 5), 19.0)
        field?.UIText.wordWrapping = false
        set_frame_size(field, float2(CHAT_PANEL_SIZE.x - 124, 24))
        field?.UIText.autoResizeFrame = false
        add_component(input, new UIMask(showMaskSource = true))
        add_component(input, new ChatInput(field = field))
        add_component(input, new UIButton(onClick = @() { focus_input() }))
        chatInputNode = input
        add_ui_event_listener(input, UIFocusEventType.FocusIn, @@on_chat_focus)
        add_ui_event_listener(input, UIFocusEventType.FocusOut, @@on_chat_focus)
        send = chat_box(body, "chatSend", float2(76, 34), float2(CHAT_PANEL_SIZE.x - 88, 120), float4(0.25, 0.55, 1.0, 0.95))
        add_component(send, new UIButton(onClick = @() { submit() }))
        chat_text_node(send, "SEND", float2(10, 5), 19.0)
        panel.isActive = inWorld
    }

    def override on_update {
        panel.isActive = inWorld && !modalOpen
        if (!inWorld || modalOpen) {
            close_chat_input()
            return
        }
        chatTyping = get_ui_focused_node() == input
        var removed = false
        while (length(receivedAt) > 0 && get_time() - receivedAt[0] >= CHAT_MESSAGE_LIFETIME) {
            erase(lines, 0)
            erase(receivedAt, 0)
            removed = true
        }
        if (removed) {
            rebuild_history()
        }
        if (is_action_just_pressed("chatEnter", ModifierMatchMode.Weak)) {
            if (chatTyping) {
                submit()
            } else {
                focus_input()
            }
        }
        if (chatTyping && is_action_just_pressed("closeWindow", ModifierMatchMode.Weak)) {
            close_chat_input()
        }
        body.isActive = !collapsed
        let hovered = is_mouse_inside_frame(get_component(panel, type<UIFrame>))
        let expanded = chatTyping || hovered || noticeUntil > 0.0
        set_frame_size(panel, collapsed ? float2(CHAT_PANEL_SIZE.x, 30) : (expanded ? CHAT_PANEL_SIZE : float2(CHAT_PANEL_SIZE.x, CHAT_IDLE_HEIGHT)))
        input.isActive = expanded
        send.isActive = expanded
        notice.isActive = true
        panel?.UIImage.color = expanded ? CHAT_FOCUSED_COLOR : float4(0)
        toggleButton?.UIImage.color = expanded ? float4(0.18, 0.21, 0.28, 0.92) : float4(0)
        header?.UIText.text = collapsed && unread > 0 ? "Chat: ({unread})" : "Chat:"
        if (noticeUntil > 0.0 && get_time() >= noticeUntil) {
            noticeUntil = 0.0
            notice?.UIText.text = "Enter — type / send a message"
        }
        if (scrollPending > 0 && !collapsed) {
            scrollPending--
            scroll?.UIScrollArea.scrollToBottom()
        }
    }

    def override on_destroy {
        close_chat_input()
        chatInputNode = NodeId()
        chatPanelNode = NodeId()
    }
}


def public spawn_chat_view(parent : NodeId) {
    let node = create_node(NodeData(name = "chat", parent = parent))
    set_frame_size(node, get_component(parent, type<UIFrame>).size)
    add_anchor(node, float2(0), float2(1))
    add_component(node, new ChatView())
}


[net_command_handler]
def on_chat_message(cmd : ChatMessage) {
    var chat = find_component(type<ChatView>)
    if (chat != null) {
        chat.append(cmd.author, cmd.message)
    }
}


[net_command_handler]
def on_chat_notice(cmd : ChatNotice) {
    var chat = find_component(type<ChatView>)
    if (chat != null) {
        chat.show_notice(cmd.message)
    }
}
