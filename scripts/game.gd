extends Node
## Autoload "Game": input map, settings, save data, UI strings.

const SAVE_PATH := "user://save.json"

var settings := {"lang": "", "shake": 1.0, "volume": 0.8, "music": 0.6, "fullscreen": false}
var save := {"best_day": 0, "runs": 0, "unlock_level": 0, "rep": 0, "daily_best": {}}

const UI := {
	"en": {
		"play": "START SHIFT", "daily": "DAILY RUN", "coop": "CO-OP: DRIVER + PASSENGER", "split": "2 SCOOTERS (SPLIT SCREEN)", "hint_split": "P1: WASD, SPACE throw, F pick up · P2: ARROWS, ENTER throw, RShift pick up",
		"settings": "SETTINGS", "quit": "QUIT", "day": "DAY", "rent": "RENT", "money": "CASH",
		"time": "TIME", "pickup": "Pick up at", "deliver": "Deliver to", "orders": "ORDERS",
		"no_orders": "Waiting for orders...", "fired": "YOU'RE FIRED!", "paid": "RENT PAID",
		"garage": "GARAGE", "next_day": "NEXT DAY", "reroll": "REROLL", "buy": "BUY",
		"owned": "OWNED", "menu": "MAIN MENU", "resume": "RESUME", "retry": "NEW RUN",
		"shift_over": "SHIFT OVER", "earned": "Earned today", "best_reviews": "TODAY'S BEST REVIEWS",
		"save_card": "F12 / Select: save screenshot", "saved": "Saved to", "chaos": "TODAY'S CHAOS",
		"quirk_yeet": "THROW IT!", "quirk_vip": "VIP", "quirk_impatient": "IMPATIENT",
		"quirk_picky": "WANTS IT HOT", "quirk_rooftop": "ROOFTOP", "lang": "LANGUAGE",
		"shake": "CAMERA SHAKE", "volume": "SOUND", "music": "MUSIC", "fullscreen": "FULLSCREEN", "back": "BACK",
		"stats": "Deliveries %d · Crashes %d · Throws %d", "best": "Best day: %d",
		"hint": "WASD drive · Arrows balance · SPACE throw · F pick up · H horn · R reset",
		"hint_coop": "P1: WASD drive, H horn · P2: Arrows balance, ENTER throw, RShift pick up",
		"crash": "WIPEOUT!", "fell": "FELL!", "spill": "SPILL!", "delivered": "DELIVERED",
		"miss": "MISSED!", "unlock": "NEW FOOD UNLOCKED: %s", "capacity": "Rack full!",
		"rent_due": "Rent due tonight: $%d", "credits": "Made with Godot Engine (MIT). All art and audio generated in-house.",
	},
	"tr": {
		"play": "VARDİYAYA BAŞLA", "daily": "GÜNLÜK KOŞU", "coop": "CO-OP: SÜRÜCÜ + YOLCU", "split": "2 SCOOTER (BÖLÜNMÜŞ EKRAN)", "hint_split": "1.O: WASD, BOŞLUK fırlat, F al · 2.O: OKLAR, ENTER fırlat, Sağ Shift al",
		"settings": "AYARLAR", "quit": "ÇIKIŞ", "day": "GÜN", "rent": "KİRA", "money": "PARA",
		"time": "SÜRE", "pickup": "Al:", "deliver": "Teslim:", "orders": "SİPARİŞLER",
		"no_orders": "Sipariş bekleniyor...", "fired": "KOVULDUN!", "paid": "KİRA ÖDENDİ",
		"garage": "GARAJ", "next_day": "SONRAKİ GÜN", "reroll": "YENİLE", "buy": "AL",
		"owned": "SENDE", "menu": "ANA MENÜ", "resume": "DEVAM", "retry": "YENİ KOŞU",
		"shift_over": "VARDİYA BİTTİ", "earned": "Bugün kazanılan", "best_reviews": "GÜNÜN EN İYİ YORUMLARI",
		"save_card": "F12 / Select: ekran görüntüsü kaydet", "saved": "Kaydedildi:", "chaos": "BUGÜNÜN KAOSU",
		"quirk_yeet": "FIRLAT!", "quirk_vip": "VIP", "quirk_impatient": "SABIRSIZ",
		"quirk_picky": "SICAK İSTİYOR", "quirk_rooftop": "ÇATI KATI", "lang": "DİL",
		"shake": "KAMERA SARSINTISI", "volume": "SES", "music": "MÜZİK", "fullscreen": "TAM EKRAN", "back": "GERİ",
		"stats": "Teslimat %d · Kaza %d · Atış %d", "best": "En iyi gün: %d",
		"hint": "WASD sür · Oklar denge · BOŞLUK fırlat · F al · H korna · R kalk",
		"hint_coop": "1.O: WASD sür, H korna · 2.O: Oklar denge, ENTER fırlat, Sağ Shift al",
		"crash": "KAZA!", "fell": "DÜŞTÜ!", "spill": "DÖKÜLDÜ!", "delivered": "TESLİM",
		"miss": "ISKA!", "unlock": "YENİ YEMEK AÇILDI: %s", "capacity": "Raf dolu!",
		"rent_due": "Bu gece kira: %d$", "credits": "Godot Engine (MIT) ile yapıldı. Tüm görsel ve sesler bize ait.",
	},
}

const UPGRADE_TEXT := {
	"en": {
		"thermo": ["Thermo Bag", "Food cools 40% slower."],
		"shocks": ["Grandma's Shocks", "Bumps hurt 60% less. A bit slower."],
		"tape": ["Duct Tape", "Each item survives one fall. Stackable."],
		"rocket": ["Rocket Motor", "+30% speed, +40% accel. Soup HATES it."],
		"rack": ["Tall Rack", "+1 item capacity. Stack wobbles more."],
		"lid": ["Lids", "Liquids spill much less."],
		"gyro": ["Gyroscope", "The stack calms itself down."],
		"magnet": ["Sticky Gloves", "Pick up dropped food from further away."],
		"arm": ["Golden Arm", "Throws are more accurate and pay 2.5x."],
		"mustache": ["Fake Mustache", "Customers like you. +15% tips, +1 star."],
		"horn": ["Train Horn", "Your horn pushes cars and props away. Rude."],
		"grease": ["Greasy Tires", "Drift everywhere. +25% tips for the show."],
		"bungee": ["Bungee Cords", "Stack wobbles less, but you can balance less."],
		"oven": ["Pizza Stone", "'Hot' bonus starts earlier (65 instead of 80)."],
	},
	"tr": {
		"thermo": ["Termos Çanta", "Yemek %40 daha yavaş soğur."],
		"shocks": ["Babaanne Amortisörü", "Tümsekler %60 daha az zarar. Biraz yavaş."],
		"tape": ["Koli Bandı", "Her yemek bir düşüşten kurtulur. Üst üste alınır."],
		"rocket": ["Roket Motor", "+%30 hız, +%40 ivme. Çorba bundan NEFRET eder."],
		"rack": ["Uzun Raf", "+1 yemek kapasitesi. Kule daha çok sallanır."],
		"lid": ["Kapaklar", "Sıvılar çok daha az dökülür."],
		"gyro": ["Jiroskop", "Kule kendi kendine sakinleşir."],
		"magnet": ["Yapışkan Eldiven", "Düşen yemeği daha uzaktan alırsın."],
		"arm": ["Altın Kol", "Atışlar daha isabetli ve 2.5 kat öder."],
		"mustache": ["Takma Bıyık", "Müşteriler seni sever. +%15 bahşiş, +1 yıldız."],
		"horn": ["Tren Kornası", "Korna arabaları ve eşyaları iter. Kaba."],
		"grease": ["Yağlı Lastik", "Her yerde drift. Şov için +%25 bahşiş."],
		"bungee": ["Lastik Ahtapot", "Kule az sallanır ama sen de az dengelersin."],
		"oven": ["Taş Fırın Kutusu", "'Sıcak' bonusu daha erken başlar (80 yerine 65)."],
	},
}

const CHAOS_TEXT := {
	"en": {"rain": ["Rain", "Slippery roads, food cools fast."], "wind": ["Windy", "Gusts shake the stack."],
		"heatwave": ["Heatwave", "Ice cream melts 2x. Hot food stays hot."], "bumps": ["Speed Bump Day", "The city installed bumps. Everywhere."],
		"traffic": ["Rush Hour", "Twice the cars."], "dogs": ["Loose Dogs", "Dogs chase scooters. Obviously."],
		"pigeons": ["Hungry Pigeons", "They steal from the top of your stack."], "fog": ["Fog", "Can't see far."]},
	"tr": {"rain": ["Yağmur", "Yollar kaygan, yemek hızlı soğur."], "wind": ["Rüzgâr", "Esinti kuleyi sallar."],
		"heatwave": ["Sıcak Dalgası", "Dondurma 2 kat erir. Sıcak yemek sıcak kalır."], "bumps": ["Tümsek Günü", "Belediye her yere tümsek yaptı."],
		"traffic": ["Trafik Saati", "İki kat araba."], "dogs": ["Başıboş Köpekler", "Köpekler scooter kovalar. Tabii ki."],
		"pigeons": ["Aç Güvercinler", "Kulenin tepesinden yemek çalarlar."], "fog": ["Sis", "Uzağı göremezsin."]},
}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load()
	if settings.lang == "":
		settings.lang = "tr" if OS.get_locale_language() == "tr" else "en"
	_setup_input()
	apply_settings()


func t(key: String) -> String:
	var d: Dictionary = UI.get(settings.lang, UI.en)
	return d.get(key, UI.en.get(key, key))


func lang() -> String:
	return settings.lang


func upgrade_text(u: String) -> Array:
	return UPGRADE_TEXT.get(settings.lang, UPGRADE_TEXT.en)[u]


func chaos_text(c: String) -> Array:
	return CHAOS_TEXT.get(settings.lang, CHAOS_TEXT.en)[c]


func food_name(k: String) -> String:
	return Reviews.FOOD_NAMES.get(settings.lang, Reviews.FOOD_NAMES.en)[k]


func apply_settings() -> void:
	var bus := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(0.001, settings.volume)))
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if settings.fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)


func _load() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if data is Dictionary:
		if data.has("settings"):
			settings.merge(data.settings, true)
		if data.has("save"):
			save.merge(data.save, true)


func write_save() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"settings": settings, "save": save}))


func _key(code: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = code
	return e


func _joy_btn(b: JoyButton, device := -1) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.button_index = b
	e.device = device
	return e


func _joy_axis(a: JoyAxis, v: float, device := -1) -> InputEventJoypadMotion:
	var e := InputEventJoypadMotion.new()
	e.axis = a
	e.axis_value = v
	e.device = device
	return e


func _add(action: String, events: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.2)
	for e in events:
		InputMap.action_add_event(action, e)


## Solo: one player does everything. p1_* = driver, p2_* = passenger (co-op).
## In solo mode the scooter reads both sets, so either works.
func _setup_input() -> void:
	_add("p1_throttle", [_key(KEY_W), _joy_axis(JOY_AXIS_TRIGGER_RIGHT, 1.0, 0)])
	_add("p1_brake", [_key(KEY_S), _joy_axis(JOY_AXIS_TRIGGER_LEFT, 1.0, 0)])
	_add("p1_left", [_key(KEY_A), _joy_axis(JOY_AXIS_LEFT_X, -1.0, 0)])
	_add("p1_right", [_key(KEY_D), _joy_axis(JOY_AXIS_LEFT_X, 1.0, 0)])
	_add("p1_horn", [_key(KEY_H), _joy_btn(JOY_BUTTON_B, 0)])
	_add("p1_reset", [_key(KEY_R), _joy_btn(JOY_BUTTON_Y, 0)])
	_add("solo_throw", [_key(KEY_SPACE), _joy_btn(JOY_BUTTON_A, 0)])
	_add("solo_pickup", [_key(KEY_F), _joy_btn(JOY_BUTTON_X, 0)])
	_add("solo_bal_left", [_joy_axis(JOY_AXIS_RIGHT_X, -1.0, 0)])
	_add("solo_bal_right", [_joy_axis(JOY_AXIS_RIGHT_X, 1.0, 0)])
	_add("solo_bal_fwd", [_joy_axis(JOY_AXIS_RIGHT_Y, -1.0, 0)])
	_add("solo_bal_back", [_joy_axis(JOY_AXIS_RIGHT_Y, 1.0, 0)])
	_add("p2_bal_left", [_key(KEY_LEFT), _joy_axis(JOY_AXIS_LEFT_X, -1.0, 1)])
	_add("p2_bal_right", [_key(KEY_RIGHT), _joy_axis(JOY_AXIS_LEFT_X, 1.0, 1)])
	_add("p2_bal_fwd", [_key(KEY_UP), _joy_axis(JOY_AXIS_LEFT_Y, -1.0, 1)])
	_add("p2_bal_back", [_key(KEY_DOWN), _joy_axis(JOY_AXIS_LEFT_Y, 1.0, 1)])
	_add("p2_throw", [_key(KEY_ENTER), _key(KEY_KP_0), _joy_btn(JOY_BUTTON_A, 1)])
	_add("p2_pickup", [_key(KEY_SHIFT), _key(KEY_KP_ENTER), _joy_btn(JOY_BUTTON_X, 1)])
	# split screen: second scooter on arrows / gamepad 1
	_add("p2d_throttle", [_key(KEY_UP), _joy_axis(JOY_AXIS_TRIGGER_RIGHT, 1.0, 1)])
	_add("p2d_brake", [_key(KEY_DOWN), _joy_axis(JOY_AXIS_TRIGGER_LEFT, 1.0, 1)])
	_add("p2d_left", [_key(KEY_LEFT), _joy_axis(JOY_AXIS_LEFT_X, -1.0, 1)])
	_add("p2d_right", [_key(KEY_RIGHT), _joy_axis(JOY_AXIS_LEFT_X, 1.0, 1)])
	_add("p2d_horn", [_key(KEY_CTRL), _joy_btn(JOY_BUTTON_B, 1)])
	_add("p2d_reset", [_key(KEY_BACKSPACE), _joy_btn(JOY_BUTTON_Y, 1)])
	_add("p2s_bal_left", [_joy_axis(JOY_AXIS_RIGHT_X, -1.0, 1)])
	_add("p2s_bal_right", [_joy_axis(JOY_AXIS_RIGHT_X, 1.0, 1)])
	_add("p2s_bal_fwd", [_joy_axis(JOY_AXIS_RIGHT_Y, -1.0, 1)])
	_add("p2s_bal_back", [_joy_axis(JOY_AXIS_RIGHT_Y, 1.0, 1)])
	_add("pause", [_key(KEY_ESCAPE), _joy_btn(JOY_BUTTON_START)])
	_add("screenshot", [_key(KEY_F12), _joy_btn(JOY_BUTTON_BACK)])
	_add("ui_accept_pad", [_joy_btn(JOY_BUTTON_A)])


## Saves a PNG of the current frame. Returns the absolute path.
func screenshot() -> String:
	var img := get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute("user://screenshots")
	var path := "user://screenshots/tipover_%s.png" % Time.get_datetime_string_from_system().replace(":", "-")
	img.save_png(path)
	return ProjectSettings.globalize_path(path)
