require engine.core
require components
require constants
require brainrot_data
require game_state


class LeaderboardView : Component {
    private nextUpdate : float = 0.0

    def override on_update {
        nextUpdate -= get_delta_time()
        if (nextUpdate > 0.0) {
            return
        }
        nextUpdate = 0.4
        var players : array<PlayerAvatar?>
        for (player in find_components(type<PlayerAvatar>)) {
            players |> push(player)
        }
        var cashOrder : array<int>
        var stealOrder : array<int>
        for (i in range(length(players))) {
            cashOrder |> push(i)
            stealOrder |> push(i)
        }
        for (i in range(length(players))) {
            for (j in range(i + 1, length(players))) {
                if (players[cashOrder[j]].cash > players[cashOrder[i]].cash) {
                    let temp = cashOrder[i]
                    cashOrder[i] = cashOrder[j]
                    cashOrder[j] = temp
                }
                if (players[stealOrder[j]].steals > players[stealOrder[i]].steals) {
                    let temp = stealOrder[i]
                    stealOrder[i] = stealOrder[j]
                    stealOrder[j] = temp
                }
            }
        }
        for (i in range(MAX_PLAYERS)) {
            var cashText = ""
            var stealText = ""
            if (i < length(players)) {
                let rich = players[cashOrder[i]]
                let thief = players[stealOrder[i]]
                cashText = "{i + 1}. {rich.playerName}  {format_cash(rich.cash)}"
                stealText = "{i + 1}. {thief.playerName}  {thief.steals}"
            }
            cashBoardRows[i]?.UIText.text = cashText
            stealsBoardRows[i]?.UIText.text = stealText
        }
    }
}


def public spawn_leaderboard_view() {
    let node = create_node(NodeData(name = "leaderboardController", parent = mapRoot))
    add_component(node, new LeaderboardView())
}
