class_name TwitchChat
extends Node
## Reads a Twitch channel's chat anonymously (no login, read-only) over Twitch's IRC WebSocket.
## Emits every chat message; World turns them into event votes.

signal message(user: String, text: String)

const URL := "wss://irc-ws.chat.twitch.tv:443"

var channel := ""
var ws := WebSocketPeer.new()
var joined := false
var _retry := 0.0


func _init(ch: String) -> void:
	channel = ch.strip_edges().to_lower().trim_prefix("#")


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_connect()


func _connect() -> void:
	joined = false
	if ws.connect_to_url(URL) != OK:
		_retry = 10.0


func _process(dt: float) -> void:
	if _retry > 0.0:
		_retry -= dt
		if _retry <= 0.0:
			ws = WebSocketPeer.new()
			_connect()
		return
	ws.poll()
	match ws.get_ready_state():
		WebSocketPeer.STATE_OPEN:
			if not joined:
				joined = true
				ws.send_text("NICK justinfan%d" % randi_range(10000, 99999))   # anonymous read-only login
				ws.send_text("JOIN #" + channel)
			while ws.get_available_packet_count() > 0:
				for line in ws.get_packet().get_string_from_utf8().split("\r\n", false):
					if line.begins_with("PING"):
						ws.send_text("PONG" + line.substr(4))
						continue
					var m := ChatVote.parse(line)
					if not m.is_empty():
						message.emit(m.user, m.text)
		WebSocketPeer.STATE_CLOSED:
			_retry = 10.0   # dropped: try again shortly
