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


const ROLES := ["drive", "ride", "cook"]
var role := "drive"      # lobby choice: drive a scooter, ride on someone's back, or cook at the restaurants
var team := -1           # competitive team (0 = A, 1 = B); -1 = auto (alternate by join order)


func my_info() -> Dictionary:
	var nm := str(Game.settings.get("name", ""))
	if nm == "":
		nm = SteamBridge.my_name() if SteamBridge.available else "Courier"
	return {"name": nm, "look": Game.settings.look, "color": int(Game.settings.color),
		"role": role, "team": team}


## Players who drive their own scooter, in scooter order.
func drivers() -> Array:
	var d := order().filter(func(id): return players[id].get("role", "drive") == "drive")
	if d.is_empty() and players.size() > 0:
		d = [order()[0]]   # someone has to drive
	return d


## Team of a player: chosen in the lobby, otherwise alternating A/B by join order.
func team_of(id: int) -> int:
	if not players.has(id):
		return 0
	var t := int(players[id].get("team", -1))
	return t if t >= 0 else order().find(id) % 2


## Driver index a passenger rides with: a teammate's scooter if there is one, else round-robin.
func ride_target(id: int) -> int:
	var ds := drivers()
	for i in ds.size():
		if team_of(ds[i]) == team_of(id):
			return i
	var passengers := order().filter(func(p): return is_passenger(p))
	return maxi(0, passengers.find(id)) % maxi(1, ds.size())


func is_passenger(id: int) -> bool:
	return players.has(id) and not drivers().has(id) and players[id].get("role", "drive") == "ride"


func is_cook(id: int) -> bool:
	return players.has(id) and not drivers().has(id) and players[id].get("role", "drive") == "cook"


func cooks() -> Array:
	return order().filter(func(id): return is_cook(id))


func update_me() -> void:
	if multiplayer.is_server():
		players[1] = my_info()
		sync_players.rpc(players)
		players_changed.emit()
	elif online:
		register.rpc_id(1, my_info())


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


## Steam: host on a P2P peer (no IP / port forwarding) and open the friends invite overlay.
func host_steam() -> int:
	if not SteamBridge.peer_supported():
		return ERR_UNAVAILABLE
	multiplayer.multiplayer_peer = SteamBridge.make_host_peer()
	online = true
	players = {1: my_info()}
	players_changed.emit()
	SteamBridge.host_lobby()
	return OK


func join_steam(host_steam_id: int) -> void:
	if not SteamBridge.peer_supported():
		_fail("Steam P2P unavailable")
		return
	multiplayer.multiplayer_peer = SteamBridge.make_client_peer(host_steam_id)
	online = true


func join(ip: String, port := PORT) -> int:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(ip, port)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	online = true
	return OK


func leave() -> void:
	SteamBridge.leave_lobby()
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


func my_index_of(id: int) -> int:
	if is_passenger(id) or is_cook(id):
		return ride_target(id)
	return maxi(0, drivers().find(id))


func my_index() -> int:
	if is_passenger(my_id()):
		return ride_target(my_id())
	return maxi(0, drivers().find(my_id()))


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
		"color": int(info.get("color", 0)) % 8, "role": str(info.get("role", "drive")) if str(info.get("role", "drive")) in ROLES else "drive",
		"team": clampi(int(info.get("team", -1)), -1, 1)}
	sync_players.rpc(players)
	players_changed.emit()


@rpc("authority", "reliable", "call_remote")
func sync_players(p: Dictionary) -> void:
	players = p
	players_changed.emit()
