extends Node
## Autoload "Game": input map, settings, save data, UI strings.

const SAVE_PATH := "user://save.json"

var settings := {"look": {"skin": 0, "jacket": 0, "helmet": 0, "helmet_color": 1, "accessory": 0}, "quality": 2, "color": 0, "lang": "", "shake": 1.0, "volume": 0.8, "music": 0.6, "fullscreen": false}
var save := {"best_day": 0, "runs": 0, "unlock_level": 0, "rep": 0, "daily_best": {}}

const UI := {
	"en": {
		"play": "START SHIFT", "daily": "DAILY RUN", "coop": "CO-OP: DRIVER + PASSENGER", "split": "2 SCOOTERS (SPLIT SCREEN)", "big_order": "BIG ORDER: WEDDING CAKE!", "controls": "CONTROLS", "color": "SCOOTER COLOR", "quality": "GRAPHICS", "character": "CHARACTER", "skin": "Skin", "jacket": "Jacket", "helmet": "Helmet", "helmet_color": "Helmet color", "accessory": "Accessory", "random": "RANDOM", "round": "ROUND", "role": "ROLE", "driver": "DRIVER", "passenger": "PASSENGER (balance + throw)", "steam_host": "HOST ON STEAM (invite friends)", "steam_tip": "Friends join from the Steam overlay or your invite. No IP needed.", "invite": "INVITE FRIENDS", "team": "TEAM", "pass": "PASS!", "caught": "CAUGHT!", "emote_0": "HELP!", "emote_1": "OVER HERE!", "emote_2": "HAHA!", "emote_3": "HURRY!", "tagline": "Keep it hot. Keep it in the bowl.", "couch": "SAME SCREEN (2 PLAYERS)", "couch_tip": "Second player: arrow keys + ENTER + Right Shift, or a second gamepad.", "convoy_alert": "WEDDING CONVOY! HONK HONK!", "tut_0": "Follow the green arrow to the ORANGE beam (restaurant). Slow down there to load food.", "tut_1": "Now the GREEN beam is your customer. Stop next to it. Brake gently: soup sloshes!", "tut_2": "Your tower is leaning! Push the other way with the ARROW keys (or mouse).", "tut_3": "Pro move: near the customer, press SPACE to throw the top food onto the yellow balcony ring. 2x tip!", "hint_cook": "Pick an order in the KITCHEN, then stop the needle in the green zone (SPACE)", "hint_ride": "Arrows / mouse: balance the tower · SPACE: throw the top food · F: pick up", "r_drive": "DRIVER", "r_ride": "PASSENGER (balance + throw)", "r_cook": "COOK (prepares orders)", "cooking": "COOKING...", "kitchen": "KITCHEN", "cook_it": "COOK", "stop": "STOP! (SPACE)", "perfect_cook": "PERFECT!", "versus": "VERSUS: 2 SCOOTERS", "mode": "MODE", "m_normal": "NORMAL (CO-OP)", "m_competitive": "COMPETITIVE", "new_card": "NEW DIFFICULTY CARD", "winner": "WINS THE CITY!", "warned": "Rent missed! The boss lets it slide ONCE. Savings gone.", "next_round": "NEXT ROUND", "leaderboard": "LEADERBOARD", "your_shop": "YOUR SHOP", "online": "ONLINE (1-4 PLAYERS)", "your_name": "Your name", "host": "HOST", "join": "JOIN", "players": "PLAYERS", "start": "START", "waiting_host": "Waiting for the host...", "leave": "LEAVE", "disconnected": "Disconnected", "online_tip": "Host: share your IP (same Wi-Fi, or port 24680 forwarded / a LAN tool). Steam invites come with the Steam release.", "q0": "LOW", "q1": "MEDIUM", "q2": "HIGH", "district": "District", "bazaar": "Bazaar", "beach": "Beach", "downtown": "Downtown", "locked": "locked", "hint_split": "P1: WASD, SPACE throw, F pick up · P2: ARROWS, ENTER throw, RShift pick up",
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
		"hint": "WASD drive · Arrows balance · SPACE throw · F pick up · H horn · R reset · 1-4 shout",
		"hint_coop": "P1: WASD drive, H horn · P2: Arrows balance, ENTER throw, RShift pick up",
		"crash": "WIPEOUT!", "fell": "FELL!", "spill": "SPILL!", "delivered": "DELIVERED",
		"miss": "MISSED!", "unlock": "NEW FOOD UNLOCKED: %s", "capacity": "Rack full!",
		"rent_due": "Rent due tonight: $%d", "credits": "Made with Godot Engine (MIT). All art and audio generated in-house.",
	},
	"tr": {
		"play": "VARDİYAYA BAŞLA", "daily": "GÜNLÜK KOŞU", "coop": "CO-OP: SÜRÜCÜ + YOLCU", "split": "2 SCOOTER (BÖLÜNMÜŞ EKRAN)", "big_order": "BÜYÜK SİPARİŞ: DÜĞÜN PASTASI!", "controls": "KONTROLLER", "color": "SCOOTER RENGİ", "quality": "GRAFİK", "character": "KARAKTER", "skin": "Ten", "jacket": "Ceket", "helmet": "Kask", "helmet_color": "Kask rengi", "accessory": "Aksesuar", "random": "RASTGELE", "round": "BÖLÜM", "role": "ROL", "driver": "SÜRÜCÜ", "passenger": "YOLCU (denge + fırlatma)", "steam_host": "STEAM'DE KUR (arkadaş davet et)", "steam_tip": "Arkadaşların Steam arayüzünden ya da davetinle katılır. IP gerekmez.", "invite": "ARKADAŞ DAVET ET", "team": "TAKIM", "pass": "PAS!", "caught": "YAKALADI!", "emote_0": "YARDIM!", "emote_1": "BURAYA!", "emote_2": "HAHA!", "emote_3": "ACELE ET!", "tagline": "Sıcak kalsın. Kasede kalsın.", "couch": "AYNI EKRAN (2 KİŞİ)", "couch_tip": "İkinci oyuncu: ok tuşları + ENTER + Sağ Shift ya da ikinci gamepad.", "convoy_alert": "DÜĞÜN KONVOYU! DIIT DIIT!", "tut_0": "Yeşil oku takip et, TURUNCU ışığa (restoran) git. Orada yavaşla, yemek yüklenir.", "tut_1": "Şimdi YEŞİL ışık müşterin. Yanında dur. Yavaş fren yap: çorba çalkalanıyor!", "tut_2": "Kule eğiliyor! OK tuşlarıyla (ya da fareyle) ters yöne it.", "tut_3": "Usta hareketi: müşterinin yanında BOŞLUK ile en üstteki yemeği balkondaki sarı halkaya fırlat. 2 kat bahşiş!", "hint_cook": "MUTFAK'ta sipariş seç, ibreyi yeşil bölgede durdur (BOŞLUK)", "hint_ride": "Oklar / fare: kuleyi dengele · BOŞLUK: üstteki yemeği fırlat · F: yerden al", "r_drive": "SÜRÜCÜ", "r_ride": "YOLCU (denge + fırlatma)", "r_cook": "AŞÇI (siparişleri hazırlar)", "cooking": "HAZIRLANIYOR...", "kitchen": "MUTFAK", "cook_it": "PİŞİR", "stop": "DUR! (BOŞLUK)", "perfect_cook": "MÜKEMMEL!", "versus": "KAPIŞMA: 2 SCOOTER", "mode": "MOD", "m_normal": "NORMAL (CO-OP)", "m_competitive": "REKABETÇİ", "new_card": "YENİ ZORLUK KARTI", "winner": "ŞEHRİN KRALI OLDU!", "warned": "Kira ödenmedi! Patron BİR kere göz yumuyor. Birikimin gitti.", "next_round": "SONRAKİ BÖLÜM", "leaderboard": "SKOR TABLOSU", "your_shop": "SENİN DÜKKANIN", "online": "ONLINE (1-4 OYUNCU)", "your_name": "Adın", "host": "KUR", "join": "KATIL", "players": "OYUNCULAR", "start": "BAŞLAT", "waiting_host": "Ev sahibi bekleniyor...", "leave": "AYRIL", "disconnected": "Bağlantı koptu", "online_tip": "Kuran kişi IP adresini paylaşır (aynı Wi-Fi ya da 24680 portu açık / LAN programı). Steam davetleri Steam sürümüyle gelecek.", "q0": "DÜŞÜK", "q1": "ORTA", "q2": "YÜKSEK", "district": "Mahalle", "bazaar": "Çarşı", "beach": "Sahil", "downtown": "Şehir Merkezi", "locked": "kilitli", "hint_split": "1.O: WASD, BOŞLUK fırlat, F al · 2.O: OKLAR, ENTER fırlat, Sağ Shift al",
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
		"hint": "WASD sür · Oklar denge · BOŞLUK fırlat · F al · H korna · R kalk · 1-4 bağır",
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

const CARD_TEXT := {
	"en": {"impatient": ["Impatient City", "Order timers are 30% shorter."], "fragile": ["Fragile Food", "Bumps hurt 50% more."],
		"no_doorbell": ["Broken Doorbells", "Hand deliveries pay half. Throw!"], "cold_kitchen": ["Cold Kitchen", "Food cools 60% faster."],
		"greedy": ["Greedy Racks", "+1 capacity, but towers wobble 25% more."]},
	"tr": {"impatient": ["Sabırsız Şehir", "Sipariş süreleri %30 kısa."], "fragile": ["Hassas Yemek", "Tümsekler %50 daha çok zarar verir."],
		"no_doorbell": ["Bozuk Ziller", "Elden teslim yarı öder. Fırlat!"], "cold_kitchen": ["Soğuk Mutfak", "Yemek %60 hızlı soğur."],
		"greedy": ["Açgözlü Raflar", "+1 kapasite ama kule %25 daha çok sallanır."]},
}


func card_text(c: String) -> Array:
	if c in RunState.CHAOS:
		return chaos_text(c)
	return CARD_TEXT.get(settings.lang, I18n.CARDS.get(settings.lang, CARD_TEXT.en)).get(c, CARD_TEXT.en[c])


const CHAOS_TEXT := {
	"en": {"rain": ["Rain", "Slippery roads, food cools fast."], "wind": ["Windy", "Gusts shake the stack."],
		"heatwave": ["Heatwave", "Ice cream melts 2x. Hot food stays hot."], "bumps": ["Speed Bump Day", "The city installed bumps. Everywhere."],
		"traffic": ["Rush Hour", "Twice the cars."], "dogs": ["Loose Dogs", "Dogs chase scooters. Obviously."],
		"pigeons": ["Hungry Pigeons", "They steal from the top of your stack."], "fog": ["Fog", "Can't see far."], "convoy": ["Wedding Season", "Honking wedding convoys block the streets."]},
	"tr": {"rain": ["Yağmur", "Yollar kaygan, yemek hızlı soğur."], "wind": ["Rüzgâr", "Esinti kuleyi sallar."],
		"heatwave": ["Sıcak Dalgası", "Dondurma 2 kat erir. Sıcak yemek sıcak kalır."], "bumps": ["Tümsek Günü", "Belediye her yere tümsek yaptı."],
		"traffic": ["Trafik Saati", "İki kat araba."], "dogs": ["Başıboş Köpekler", "Köpekler scooter kovalar. Tabii ki."],
		"pigeons": ["Aç Güvercinler", "Kulenin tepesinden yemek çalarlar."], "fog": ["Sis", "Uzağı göremezsin."], "convoy": ["Düğün Sezonu", "Korna çalan düğün konvoyları yolları kapatır."]},
}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load()
	if settings.lang == "" or not settings.lang in I18n.LANGS:
		var os_lang := OS.get_locale_language()
		settings.lang = os_lang if os_lang in I18n.LANGS else "en"
	if not settings.has("quality_auto"):
		settings.quality_auto = true
		settings.quality = _guess_quality()
	_setup_input()
	apply_settings()


const SCOOTER_COLORS := ["#ff6b35", "#4361ee", "#2a9d8f", "#e63946", "#ffbe0b", "#8338ec", "#ff70a6", "#222222"]


## Colors unlock as you survive more days.
func colors_unlocked() -> int:
	return mini(SCOOTER_COLORS.size(), 2 + int(save.best_day / 2.0))


func districts_unlocked() -> Array:
	var d := ["bazaar"]
	if int(save.best_day) >= 4:
		d.append("beach")
	if int(save.best_day) >= 7:
		d.append("downtown")
	return d


const TEAM_COLORS := ["#ff6b35", "#4361ee"]


func team_label(t: int) -> String:
	return Game.t("team") + " " + ["A", "B"][clampi(t, 0, 1)]


## "TEAM A (Ayşe, Mehmet)" online; P1/P2 locally.
func team_name(t: int) -> String:
	if not Net.online:
		return player_name(t)
	var names := []
	for id in Net.order():
		if Net.team_of(id) == t:
			names.append(str(Net.players[id].get("name", "?")))
	return "%s (%s)" % [team_label(t), ", ".join(names)]


## Display name of player index i (online: lobby name, local: P1/P2).
func player_name(i: int) -> String:
	if Net.online:
		var ids := Net.order()
		if i < ids.size():
			return str(Net.players[ids[i]].get("name", "P%d" % (i + 1)))
	return "P%d" % (i + 1)


## First launch: integrated / software GPUs get Medium, everything else High (SDFGI).
func _guess_quality() -> int:
	var gpu := RenderingServer.get_video_adapter_name().to_lower()
	if RenderingServer.get_current_rendering_method() != "forward_plus":
		return 0
	for weak in ["intel", "llvmpipe", "uhd", "iris", "mali", "adreno", "vega 8", "radeon graphics"]:
		if weak in gpu:
			return 1
	return 2


func t(key: String) -> String:
	var d: Dictionary = UI.get(settings.lang, I18n.UI.get(settings.lang, UI.en))
	return d.get(key, UI.en.get(key, key))


func lang() -> String:
	return settings.lang


func upgrade_text(u: String) -> Array:
	return UPGRADE_TEXT.get(settings.lang, I18n.UPGRADES.get(settings.lang, UPGRADE_TEXT.en)).get(u, UPGRADE_TEXT.en[u])


func chaos_text(c: String) -> Array:
	return CHAOS_TEXT.get(settings.lang, I18n.CHAOS.get(settings.lang, CHAOS_TEXT.en)).get(c, CHAOS_TEXT.en[c])


func food_name(k: String) -> String:
	return Reviews.food_names(settings.lang).get(k, k)


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
	var dpad := [JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_RIGHT, JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_DPAD_LEFT]
	for e in 4:
		_add("emote_%d" % e, [_key(KEY_1 + e), _joy_btn(dpad[e], 0)])
		_add("p2_emote_%d" % e, [_key(KEY_KP_1 + e), _joy_btn(dpad[e], 1)])
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
