extends Node
## Autoload "Net": lobby + connection (ENet). Host is authoritative: it simulates the
## world; clients send inputs and draw snapshots. Steam lobbies can later replace the peer.

signal players_changed
signal connection_failed(reason: String)
signal joined

const PORT := 24680
const MAX_PLAYERS := 4

var players := {}       # peer id -> {"name", "look", "color"}
var online := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(func(): _fail("connection failed"))
	multiplayer.server_disconnected.connect(func(): _fail("host left"))


func my_info() -> Dictionary:
	return {"name": str(Game.settings.get("name", "Courier")), "look": Game.settings.look, "color": int(Game.settings.color)}


func host(port := PORT) -> int:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, MAX_PLAYERS - 1)
	if err != OK:
		# machines without IPv6 can't bind "*": fall back to IPv4 only
		peer = ENetMultiplayerPeer.new()
		peer.set_bind_ip("0.0.0.0")
		err = peer.create_server(port, MAX_PLAYERS - 1)
	if err != OK:
		print("NET host failed: ", error_string(err))
		return err
	multiplayer.multiplayer_peer = peer
	online = true
	players = {1: my_info()}
	players_changed.emit()
	return OK


func join(ip: String, port := PORT) -> int:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(ip, port)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	online = true
	return OK


func leave() -> void:
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	online = false
	players.clear()
	players_changed.emit()


func is_host() -> bool:
	return not online or multiplayer.is_server()


func my_id() -> int:
	return multiplayer.get_unique_id() if online else 1


## Stable order of players: host first, then by peer id. Index = scooter index.
func order() -> Array:
	var ids := players.keys()
	ids.sort()
	return ids


func my_index() -> int:
	return maxi(0, order().find(my_id()))


func _on_connected() -> void:
	print("NET connected to host as ", multiplayer.get_unique_id())
	register.rpc_id(1, my_info())
	joined.emit()


func _on_peer_connected(id: int) -> void:
	print("NET peer connected ", id)


func _on_peer_disconnected(id: int) -> void:
	if multiplayer.is_server():
		players.erase(id)
		sync_players.rpc(players)
		players_changed.emit()


func _fail(reason: String) -> void:
	print("NET fail: ", reason)
	leave()
	connection_failed.emit(reason)


@rpc("any_peer", "reliable")
func register(info: Dictionary) -> void:
	if not multiplayer.is_server():
		return
	var id := multiplayer.get_remote_sender_id()
	if players.size() >= MAX_PLAYERS:
		return
	# never trust the client's dictionary blindly: keep only known keys with sane types
	players[id] = {"name": str(info.get("name", "Courier")).substr(0, 16), "look": info.get("look", {}) if info.get("look") is Dictionary else {},
		"color": int(info.get("color", 0)) % 8}
	sync_players.rpc(players)
	players_changed.emit()


@rpc("authority", "reliable", "call_remote")
func sync_players(p: Dictionary) -> void:
	players = p
	players_changed.emit()
