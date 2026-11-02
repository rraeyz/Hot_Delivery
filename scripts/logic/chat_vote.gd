class_name ChatVote
extends RefCounted
## Twitch chat vote: parses IRC lines and counts "1".."n" votes, one per viewer (last vote wins).
## Pure logic so it is unit-tested; the socket lives in twitch_chat.gd.

var options: Array = []
var votes := {}            # user -> option index


## ":nick!nick@nick.tmi.twitch.tv PRIVMSG #chan :hello" -> {"user": "nick", "text": "hello"}; {} otherwise.
static func parse(line: String) -> Dictionary:
	if line.begins_with("@"):   # tags prefix
		var sp := line.find(" ")
		if sp < 0:
			return {}
		line = line.substr(sp + 1)
	var i := line.find(" PRIVMSG #")
	if not line.begins_with(":") or i < 0:
		return {}
	var bang := line.find("!")
	var user := line.substr(1, (bang if bang > 0 and bang < i else i) - 1).to_lower()
	var c := line.find(" :", i)
	if c < 0:
		return {}
	return {"user": user, "text": line.substr(c + 2).strip_edges()}


func start(opts: Array) -> void:
	options = opts
	votes.clear()


func add(user: String, text: String) -> void:
	if options.is_empty() or text.is_empty():
		return
	var n := text.unicode_at(0) - 48   # first character "1".."9"
	if n >= 1 and n <= options.size():
		votes[user] = n - 1


func counts() -> Array:
	var c := []
	c.resize(options.size())
	c.fill(0)
	for u in votes:
		c[votes[u]] += 1
	return c


## Winning option; ties and no votes go to the earliest listed option among the best.
func winner() -> String:
	if options.is_empty():
		return ""
	var c := counts()
	return options[c.find(c.max())]
