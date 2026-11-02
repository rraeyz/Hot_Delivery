# Steam kurulumu (adım adım)

Kod hazır: `scripts/steam_bridge.gd` Steam varsa lobi, arkadaş daveti, P2P bağlantı ve başarımları açar; Steam yoksa oyun IP ile çalışmaya devam eder.

## 1) GodotSteam eklentisini projeye ekle (KULLANICI — onay gerekli)
Ben bulut ortamında dışarıdan gelen derlenmiş dosyaları (dll/so) projeye koyamadım (güvenlik kuralı). Sen yap:
1. https://codeberg.org/godotsteam/godotsteam/releases adresine git, **v4.23.2-gde** sürümünden `godotsteam-4.23.2-gdextension-plugin-4.4.zip` dosyasını indir (MIT lisansı, ücretsiz).
2. Zip'in içindeki `godotsteam/addons/godotsteam` klasörünü, projede `addons/godotsteam` olacak şekilde kopyala.
3. Godot'u aç; "Steam" tekili otomatik yüklenir. Steam açıkken oyunu başlat: ONLINE ekranında **STEAM'DE KUR** düğmesi çıkar.
4. İstersen bana "GodotSteam'i sen ekle" de; izin verirsen ben de ekleyip commit ederim.

## 2) Steamworks
1. https://partner.steamgames.com — Steam Direct ücreti 100$ (tek masraf).
2. Uygulama oluşturunca **App ID** alırsın. `scripts/steam_bridge.gd` içindeki `APP_ID := 480` satırını o sayıyla değiştir (480 = Valve'ın test uygulaması "Spacewar").
3. Steamworks > Başarımlar (Stats & Achievements) bölümüne aşağıdaki 15 başarımı **API adı birebir aynı** olacak şekilde ekle (ad ve açıklamayı kopyala-yapıştır; simgeler: 256×256 PNG, kilitli hâli gri):

| API adı | Ad (EN) | Açıklama (EN) | Ad (TR) |
|---|---|---|---|
| FIRST_DELIVERY | Still Warm-ish | Deliver your first order. | Hâlâ Ilık Sayılır |
| BALCONY_THROW | Air Mail | Throw food onto a balcony and land it. | Uçak Postası |
| SOUP_SURVIVOR | Not a Drop | Deliver soup with more than 90% left in the bowl. | Bir Damla Bile |
| WIPEOUT | Flying Courier | Crash your scooter. Everyone does. | Uçan Kurye |
| DAY_5 | Rent Paid (x5) | Survive to day 5. | Kira Ödendi (x5) |
| DAY_10 | Employee of the Month | Survive to day 10. | Ayın Elemanı |
| COMPETITIVE_WIN | King of the City | Win a competitive match. | Şehrin Kralı |
| PERFECT_COOK | Chef's Kiss | Hit the perfect zone while cooking. | Şefin Öpücüğü |
| STAIRS_SKIP | Who Needs Elevators | During a broken-elevator event, deliver by throwing. | Asansöre Ne Gerek |
| BARISTA | Barista on Wheels | Deliver coffee with more than 90% left. | Tekerlekli Barista |
| JELLY | Wobble Wobble | Deliver a giant jelly. | Lıkır Lıkır |
| WEDDING_CAKE | Something Borrowed | Deliver the wedding cake. | Gelin Pastası |
| TOWER_5 | Leaning Tower | Carry 5 items at once. | Pisa Kulesi |
| BOWLING | Strike! | Knock over 5 pedestrians in one shift. | Strike! |
| ONLINE_SHIFT | Team Effort | Finish an online shift. | Ekip İşi |
4. Steamworks > Remote Play: "Remote Play Together" açık olsun (yerel 2 kişilik modlar internetten oynanır).

## Nasıl çalışır
- Ev sahibi STEAM'DE KUR → arkadaş-özel lobi açılır → ARKADAŞ DAVET ET ile Steam davet penceresi.
- Arkadaş daveti kabul eder → oyun açılır (`+connect_lobby`) → lobiye girer → ev sahibine Steam P2P ile bağlanır (port açmaya gerek yok).
- Başarımlar oyun içi olaylarda otomatik verilir. Online oyunda ev sahibi, başarımı kazanan oyuncunun kendi oyununa yollar (her oyuncu kendi Steam hesabında açar).

Not: Bu kısım Steam istemcisi ve eklenti olmadan test edilemedi; ilk Steam testinde sorun çıkarsa bana logu gönder.
