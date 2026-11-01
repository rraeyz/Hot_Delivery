class_name Reviews
extends RefCounted
## Funny customer review lines. {food} is replaced with the localized food name.

const FOOD_NAMES := {
	"en": {"pizza": "pizza", "soup": "soup", "burger": "burger", "drinks": "drinks",
		"icecream": "ice cream", "sushi": "sushi", "cake": "wedding cake", "jelly": "jelly", "coffee": "coffee"},
	"tr": {"pizza": "pizza", "soup": "çorba", "burger": "hamburger", "drinks": "içecekler",
		"icecream": "dondurma", "sushi": "suşi", "cake": "düğün pastası", "jelly": "jöle", "coffee": "kahve"},
}

const NAMES := ["Ayşe K.", "Mike T.", "Yuki S.", "Olu A.", "Sofia R.", "Mehmet D.", "Priya N.",
	"Lars E.", "Fatma Y.", "Diego M.", "Chloe B.", "Kemal Ö.", "Hana L.", "Igor P.", "Zeynep A.",
	"Grandma Rose", "Sami J.", "Lena W.", "Tom H.", "Aiko M.", "Burak T.", "Nina V.", "Carlos G.",
	"Elif S.", "Jamal R.", "Mei C.", "Oscar F.", "Selin E.", "Dave", "Anonymous Cat Owner"]

const LINES := {
	"en": {
		"destroyed": [
			"The {food} arrived. In a bag. In pieces. In a different dimension.",
			"I ordered {food}. I received a crime scene.",
			"My dog refused to eat it. My dog eats socks.",
			"I'm not even mad. I'm impressed. Zero stars would be generous.",
			"The courier handed me the box and said 'sorry' in four languages.",
			"Is this {food} or modern art? Either way, I can't eat it.",
		],
		"spilled": [
			"The {food} arrived. The bowl didn't.",
			"Half my {food} is on the scooter. The scooter looked happy.",
			"There was {food} on the receipt. Mostly on the receipt.",
			"I asked for {food}, not a {food} scented bowl.",
			"The courier was soaked. I think that was my {food}.",
			"The street now smells like {food}. 10/10 for the neighbors, 2/10 for me.",
		],
		"thrown_perfect": [
			"The {food} came through my balcony like a missile. Perfectly hot. I'm crying.",
			"I opened the window for fresh air and got dinner. Legend.",
			"Caught it with one hand. Best night of my life.",
			"That throw deserves an Olympic medal. And a tip. Here's both.",
			"It landed on the table. ON THE TABLE. Hire this person as a pilot.",
		],
		"thrown": [
			"Why did my {food} fly through the balcony? Not complaining. Just asking.",
			"Dinner arrived at 60 km/h. My cat has moved out.",
			"I heard 'CATCH!' and then I heard my lamp break.",
			"Delivered by air mail. Literally.",
			"My neighbor thinks I'm being attacked by pizza drones now.",
		],
		"crash_perfect": [
			"The courier crashed into my mailbox, did a backflip, and the {food} was PERFECT.",
			"I watched the courier fly over the fence. The {food}? Not a scratch. Unreal.",
			"He rolled down the street like a bowling ball but the {food} was still hot. Hero.",
		],
		"crash": [
			"I saw the crash from my window. Then I saw my {food} land on a car.",
			"The courier arrived limping and said 'you should see the other guy'. The other guy was a lamp post.",
			"My {food} has been through more than I have this year.",
			"The courier asked if I had a band-aid. I gave a tip instead.",
		],
		"dropped": [
			"Why does my {food} have a tire mark on it?",
			"Five second rule? This was a fifty second rule.",
			"Comes with free gravel. Didn't order gravel.",
			"I found a leaf in my {food}. A whole leaf. From a tree.",
			"The box said 'this side up'. It was not that side up.",
		],
		"melted": [
			"I ordered {food}, I got a smoothie.",
			"It's not {food} anymore, it's a puddle with a past.",
			"Arrived in liquid form. I had to drink it with a straw.",
			"The {food} was warmer than my ex.",
		],
		"cold": [
			"The {food} was colder than my landlord's heart.",
			"I had to microwave the {food}. And the courier.",
			"Cold {food}? In this economy?",
			"Room temperature {food}. The room was a fridge.",
			"It arrived at the exact temperature of disappointment.",
		],
		"late": [
			"I ordered this as a teenager.",
			"The {food} arrived. I had already moved out.",
			"Late, but the courier looked like they went through a war, so fine.",
			"I grew a beard waiting. I'm a woman.",
			"By the time it came, I had learned to cook.",
		],
		"perfect": [
			"Hot, fast, intact. Is this even legal?",
			"Perfect {food}. I'm suspicious. Who are you?",
			"Five stars. I'm framing the box.",
			"The courier smiled and the {food} was steaming. I believe in humanity again.",
			"Better than my mom's. Don't tell my mom.",
		],
		"fast": [
			"I hit 'order' and heard the doorbell. Witchcraft.",
			"Fast like a rocket, but the courier smelled like burnt tires.",
			"So fast I hadn't put my pants on yet. Sorry, courier.",
		],
		"ok": [
			"It was {food}. It was fine. Life goes on.",
			"Not bad. Not great. Very {food}.",
			"Three stars. The courier honked the whole way. Why.",
			"Edible. Survived. Like me.",
			"The {food} was okay but the courier waved like we were old friends.",
		],
	},
	"tr": {
		"destroyed": [
			"{food} geldi. Torbada. Parça parça. Başka bir boyuttan.",
			"{food} sipariş ettim, olay yeri teslim aldım.",
			"Köpeğim bile yemedi. Köpeğim çorap yiyor.",
			"Kızgın değilim, etkilendim. Sıfır yıldız bile cömert olur.",
			"Kurye kutuyu verip dört dilde özür diledi.",
			"Bu {food} mu, modern sanat mı? Hangisiyse yenmiyor.",
		],
		"spilled": [
			"{food} geldi. Kasesi gelmedi.",
			"{food} yarısı scooter'da kaldı. Scooter mutlu görünüyordu.",
			"Fişin üstünde {food} vardı. Çoğu fişin üstündeydi.",
			"{food} istedim, {food} kokulu boş kase geldi.",
			"Kurye sırılsıklamdı. Sanırım o benim {food} idi.",
			"Sokak artık {food} kokuyor. Komşulara 10/10, bana 2/10.",
		],
		"thrown_perfect": [
			"{food} balkondan füze gibi girdi. Dumanı tütüyordu. Ağlıyorum.",
			"Hava alayım diye pencereyi açtım, akşam yemeği geldi. Efsane.",
			"Tek elle yakaladım. Hayatımın en güzel gecesi.",
			"Bu atış olimpiyat madalyası hak ediyor. Bir de bahşiş. İkisi de senin.",
			"Masaya düştü. MASAYA. Bu kişiyi pilot yapın.",
		],
		"thrown": [
			"{food} neden balkondan uçarak girdi? Şikâyet etmiyorum, soruyorum.",
			"Yemek saatte 60 km hızla geldi. Kedim evi terk etti.",
			"'TUT!' diye bir ses duydum, sonra lambamın kırıldığını duydum.",
			"Hava yoluyla teslim edildi. Gerçekten.",
			"Komşum artık pizza dronlarının saldırısına uğradığımı düşünüyor.",
		],
		"crash_perfect": [
			"Kurye posta kutuma girdi, ters takla attı ve {food} KUSURSUZDU.",
			"Kuryenin çitin üstünden uçtuğunu gördüm. {food}? Tek çizik yok.",
			"Bowling topu gibi yuvarlandı ama {food} hâlâ sıcaktı. Kahraman.",
		],
		"crash": [
			"Kazayı pencereden gördüm. Sonra {food} bir arabanın üstüne düştü.",
			"Kurye topallayarak geldi, 'öbürünü görecektin' dedi. Öbürü bir direkti.",
			"Benim {food} bu yıl benden çok şey yaşadı.",
			"Kurye yara bandı var mı diye sordu. Bahşiş verdim.",
		],
		"dropped": [
			"{food} üstünde neden lastik izi var?",
			"Beş saniye kuralı mı? Bu elli saniye kuralıydı.",
			"Yanında bedava çakıl geldi. Çakıl sipariş etmedim.",
			"{food} içinden yaprak çıktı. Koca bir yaprak. Ağaçtan.",
			"Kutuda 'bu taraf yukarı' yazıyordu. O taraf yukarı değildi.",
		],
		"melted": [
			"{food} istedim, smoothie geldi.",
			"Artık {food} değil, geçmişi olan bir su birikintisi.",
			"Sıvı halde geldi. Pipetle içtim.",
			"{food} eski sevgilimden bile sıcaktı.",
		],
		"cold": [
			"{food} ev sahibimin kalbinden soğuktu.",
			"{food} mikrodalgaya koydum. Kuryeyi de.",
			"Soğuk {food}? Bu ekonomide?",
			"Oda sıcaklığında {food}. Oda buzdolabıydı.",
			"Tam olarak hayal kırıklığı sıcaklığında geldi.",
		],
		"late": [
			"Bunu ergenken sipariş etmiştim.",
			"{food} geldiğinde ben çoktan taşınmıştım.",
			"Geç geldi ama kurye savaştan çıkmış gibiydi, sorun değil.",
			"Beklerken sakal bıraktım. Kadınım.",
			"Gelene kadar yemek yapmayı öğrendim.",
		],
		"perfect": [
			"Sıcak, hızlı, sağlam. Bu yasal mı?",
			"Kusursuz {food}. Şüphelendim. Sen kimsin?",
			"Beş yıldız. Kutuyu çerçeveletiyorum.",
			"Kurye gülümsedi, {food} dumanı tütüyordu. İnsanlığa yeniden inandım.",
			"Annemin yaptığından iyi. Anneme söylemeyin.",
		],
		"fast": [
			"Sipariş'e bastım, kapı çaldı. Büyücülük.",
			"Roket gibi hızlıydı ama kurye yanık lastik kokuyordu.",
			"O kadar hızlıydı ki pantolonumu giyememiştim. Pardon kurye.",
		],
		"ok": [
			"{food} idi. Fena değildi. Hayat devam ediyor.",
			"Ne iyi ne kötü. Tam bir {food}.",
			"Üç yıldız. Kurye yol boyunca korna çaldı. Neden.",
			"Yenebilir. Hayatta kaldı. Benim gibi.",
			"{food} idare ederdi ama kurye eski dostmuşuz gibi el salladı.",
		],
	},
}


static func primary_tag(tags: Array) -> String:
	if "destroyed" in tags:
		return "destroyed"
	if "thrown" in tags:
		return "thrown_perfect" if "perfect" in tags else "thrown"
	if "spilled" in tags:
		return "spilled"
	if "crash" in tags:
		return "crash_perfect" if "perfect" in tags else "crash"
	for t in ["dropped", "melted", "cold", "late", "perfect", "fast"]:
		if t in tags:
			return t
	return "ok"


## Returns {name, line, tag}. rng makes it deterministic for tests and daily runs.
static func lines(lang: String) -> Dictionary:
	if LINES.has(lang):
		return LINES[lang]
	return I18n.REVIEWS.get(lang, LINES.en)


static func food_names(lang: String) -> Dictionary:
	if FOOD_NAMES.has(lang):
		return FOOD_NAMES[lang]
	return I18n.FOOD.get(lang, FOOD_NAMES.en)


static func make(kind: String, tags: Array, lang: String, rng: RandomNumberGenerator) -> Dictionary:
	var tag := primary_tag(tags)
	var pool: Array = lines(lang).get(tag, LINES.en[tag])
	var line: String = pool[rng.randi() % pool.size()]
	var food: String = food_names(lang).get(kind, kind)
	line = line.replace("{food}", food)
	line = line.substr(0, 1).to_upper() + line.substr(1)
	return {"name": NAMES[rng.randi() % NAMES.size()], "line": line, "tag": tag}


## How shareable/funny a review is, used to pick the shift's top 3 cards.
static func funny_score(tag: String, stars: int) -> int:
	var s := {"destroyed": 9, "thrown_perfect": 10, "thrown": 8, "spilled": 8, "crash_perfect": 10,
		"crash": 7, "dropped": 6, "melted": 6, "cold": 5, "late": 5, "perfect": 4, "fast": 3, "ok": 1}
	return int(s.get(tag, 1)) * 10 + (5 - stars if stars <= 2 else stars)
