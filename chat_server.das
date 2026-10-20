require engine.core
require engine.networking
require components
require constants
require net_commands
require chat_text


// Local to the authoritative avatar, removed automatically when its player leaves.
class ChatSender : Component {
    private readyAt : float = 0.0

    def accept_at(now : float) : bool {
        if (now < readyAt) {
            return false
        }
        readyAt = now + CHAT_SEND_INTERVAL
        return true
    }
}


[net_command_handler]
def on_chat_send(cmd : ChatSend; connection : ConnectionId) {
    for (player in find_components(type<PlayerAvatar>)) {
        if (get_node_owner(player.nodeId) != connection) {
            continue
        }
        var sender = get_component(player.nodeId, type<ChatSender>)
        if (sender == null) {
            return
        }
        if (!sender.accept_at(get_time())) {
            broadcast_net_command(ChatNotice(message = "Please wait a moment before sending again."), connection)
            return
        }
        let message = clean_chat_text(cmd.message)
        if (empty(message)) {
            broadcast_net_command(ChatNotice(message = "Use 1 to {CHAT_MAX_CHARACTERS} characters."), connection)
            return
        }
        // Author comes from this connection's avatar, never from the request.
        broadcast_net_command(ChatMessage(author = player.playerName, message = message))
        return
    }
}
