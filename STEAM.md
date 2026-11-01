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
3. Steamworks > Başarımlar bölümüne şu API adlarıyla başarım ekle:
   FIRST_DELIVERY, BALCONY_THROW, SOUP_SURVIVOR, WIPEOUT, DAY_5, DAY_10, COMPETITIVE_WIN, PERFECT_COOK
4. Steamworks > Remote Play: "Remote Play Together" açık olsun (yerel 2 kişilik modlar internetten oynanır).

## Nasıl çalışır
- Ev sahibi STEAM'DE KUR → arkadaş-özel lobi açılır → ARKADAŞ DAVET ET ile Steam davet penceresi.
- Arkadaş daveti kabul eder → oyun açılır (`+connect_lobby`) → lobiye girer → ev sahibine Steam P2P ile bağlanır (port açmaya gerek yok).
- Başarımlar oyun içi olaylarda otomatik verilir.

Not: Bu kısım Steam istemcisi ve eklenti olmadan test edilemedi; ilk Steam testinde sorun çıkarsa bana logu gönder.
