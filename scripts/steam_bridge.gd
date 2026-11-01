extends Node
## Autoload "SteamBridge": optional Steam layer (GodotSteam GDExtension in addons/godotsteam).
## Everything is looked up at runtime, so the game runs fine without the addon or without Steam.
## Provides: friends-only lobby + invite overlay, joining via invite, P2P peer for Net, achievements.

signal lobby_ready(lobby_id: int)
signal join_failed(reason: String)

const APP_ID := 480          # Spacewar test app; replace with the real App ID after Steamworks setup
const ACHIEVEMENTS := ["FIRST_DELIVERY", "BALCONY_THROW", "SOUP_SURVIVOR", "WIPEOUT", "DAY_5", "DAY_10",
	"COMPETITIVE_WIN", "PERFECT_COOK", "TEAM_PASS"]

var steam: Object = null     # the "Steam" singleton when available
var available := false
var lobby_id := 0
var _pending_join := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not Engine.has_singleton("Steam"):
		return
	steam = Engine.get_singleton("Steam")
	var res = steam.call("steamInitEx", false, APP_ID, true)
	var ok: bool = res is Dictionary and int(res.get("status", 1)) == 0
	if not ok:
		print("Steam not running / init failed: ", res)
		steam = null
		return
	available = true
	steam.connect("lobby_created", _on_lobby_created)
	steam.connect("lobby_joined", _on_lobby_joined)
	steam.connect("join_requested", _on_join_requested)
	# launched from a friend's invite: "+connect_lobby <id>"
	var args := OS.get_cmdline_args()
	var i := args.find("+connect_lobby")
	if i >= 0 and i + 1 < args.size():
		_pending_join = int(args[i + 1])
		join_lobby.call_deferred(_pending_join)


func my_name() -> String:
	return str(steam.call("getPersonaName")) if available else ""


func peer_supported() -> bool:
	return available and ClassDB.class_exists("SteamMultiplayerPeer")


## Host: create a friends-only lobby; Net hosts on a Steam P2P peer once it exists.
func host_lobby() -> void:
	if available:
		steam.call("createLobby", 1, 4)   # 1 = LOBBY_TYPE_FRIENDS_ONLY


func invite_friends() -> void:
	if available and lobby_id != 0:
		steam.call("activateGameOverlayInviteDialog", lobby_id)


func join_lobby(id: int) -> void:
	if available:
		steam.call("joinLobby", id)


func leave_lobby() -> void:
	if available and lobby_id != 0:
		steam.call("leaveLobby", lobby_id)
	lobby_id = 0


func make_host_peer() -> MultiplayerPeer:
	var p = ClassDB.instantiate("SteamMultiplayerPeer")
	p.call("create_host", 0)
	return p


func make_client_peer(host_steam_id: int) -> MultiplayerPeer:
	var p = ClassDB.instantiate("SteamMultiplayerPeer")
	p.call("create_client", host_steam_id, 0)
	return p


func achieve(name: String) -> void:
	if available and name in ACHIEVEMENTS:
		steam.call("setAchievement", name)
		steam.call("storeStats")


func _on_lobby_created(result: int, id: int) -> void:
	if result != 1:   # 1 = k_EResultOK
		join_failed.emit("lobby create failed (%d)" % result)
		return
	lobby_id = id
	steam.call("setLobbyData", id, "game", "tipover")
	steam.call("setLobbyJoinable", id, true)
	lobby_ready.emit(id)


func _on_lobby_joined(id: int, _permissions: int, _locked: bool, response: int) -> void:
	if response != 1:
		join_failed.emit("lobby join failed (%d)" % response)
		return
	lobby_id = id
	var owner: int = steam.call("getLobbyOwner", id)
	if owner == steam.call("getSteamID"):
		return   # we are the host; Net already hosts
	Net.join_steam(owner)


func _on_join_requested(id: int, _friend: int) -> void:
	join_lobby(id)
