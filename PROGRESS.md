# PROGRESS

Saatlik tetikleyici: `trig_01YGVX4aggfGhdgvnmukKuyB` — AÇIK (her saat :08'de). Kullanıcı günlerce açık kalmasını istedi; kapatma.

## Test komutları
- Birim testleri: `godot --headless --path . -s tests/run_tests.gd`
- Fizik hissi ölçümü: `godot --headless --path . --fixed-fps 60 res://tests/sim_drive.tscn`
- Bot bir vardiya oynar: `godot --headless --path . --fixed-fps 60 res://tests/bot_shift.tscn -- --days=3` (`--len=60` kısa vardiya, `--elevator` bozuk asansör)
- Online: `tests/net_test.sh 15` (`RIDE=1` / `COOK=1`); tekrar testi: host'a `--len=8 --crash=3`
- Performans: `godot --headless --path . res://tests/perf_count.tscn`
- Görsel test (Xvfb): `xvfb-run -a godot --path . --rendering-driver opengl3 --fixed-fps 30 -- --autotest --out=/tmp/shots --secs=20 --every=4`
- Windows çıktısı: `godot --headless --path . --export-release "Windows Desktop" build/windows/TipOver.exe` (şablonlar ~/.local/share/godot/export_templates/4.6.2.stable)

## Oturum 1 — 1 Kasım 2026
**Çalışıyor:** tek kişilik oyunun tamamı oynanabilir: menü → vardiya (3.5 dk) → gün sonu özeti (en komik 3 yorum) → kira → garaj (3 yükseltme kartı) → sonraki gün → kovulma → yeni koşu. 7 yemek, 8 şehir kaosu, 5 müşteri huyu, trafik, köpek, güvercin, balkon atışı, yerden toplama, kaza + uçan kurye, TR/EN, ayarlar, günlük koşu, kalıcı yemek açılımları, sentez ses ve müzik.
**Testler:** 270 birim kontrolü, fizik hissi ölçümü (6 manevra), bot 3 gün oynayıp kirayı ödüyor (günde 6-8 teslimat, ~200$).
**Bilinen eksikler:** iki scooter (bölünmüş ekran) yok; kaza tekrarı yok; buhar efekti yok; denge (kira eğrisi) sadece bota göre ayarlı.
**Build:** `builds/TipOver-windows-v0.2.zip`. Ayrıca GitHub Actions her push'ta .exe üretir (Actions sekmesi > son çalışma > Artifacts).

## Oturum 1 (devam) — 1 Kasım 2026 öğleden sonra
**Eklendi:** buhar (sıcak yemek), fareyle denge, kapıda müşteri tepkisi, günün felaketi ağır çekim tekrarı, iki scooter bölünmüş ekran, 3 mahalle (Çarşı/Sahil/Şehir Merkezi), her 3. gün düğün pastası, 8 scooter rengi, kontroller ekranı, sıkışınca otomatik kurtarma, STORE.md, VIDEOS.md.
**Düzeltildi:** scooter rampaya sıkışınca hiç kurtulamıyordu (bot testi yakaladı).
**Testler:** 276 birim kontrolü + fizik ölçümü + bot 3 mahallede vardiya oynuyor (6-9 teslimat).
**Build:** `builds/TipOver-windows-v0.2.zip`.
**Bozuk/eksik:** bölünmüş ekranda tekrar yok ve 2. oyuncunun denge göstergesi yok; köpek/güvercin sadece 1. scooter'ı hedefliyor; kira eğrisi gerçek oyuncuyla test edilmedi.

### KULLANICI BEKLENİYOR
Prototipi oyna ve his hakkında yaz (adımlar README.md'de). Özellikle: (1) scooter sürmek eğlenceli mi, (2) çorba çok mu kolay/zor dökülüyor, (3) kule çok mu çabuk devriliyor, (4) 1. gün kirası (50$) kolay mı.

### Sıradaki
Kullanıcı geri bildirimine göre his/denge ayarı; Steam sayfası için kapak görseli ve ekran görüntüleri; GodotSteam başarımları (Steam hesabı açılınca).


## Oturum 2 — 1 Kasım 2026 akşam (kullanıcının ikinci tur istekleri)
**Eklendi:**
- Grafik: Vulkan/Forward+ (Vulkan yoksa otomatik OpenGL), ACES ton, SSAO/SSIL, hafif hacimsel sis, prosedürel asfalt/kaldırım/bina dokuları, sokak lambaları, gün saati (sabah/öğle/gün batımı/gece — gece pencereler ve lambalar yanar), scooter farı, Grafik ayarı (Düşük/Orta/Yüksek).
- Karakter: yeni kurye modeli, KARAKTER ekranı (ten, ceket, 8 kask, kask rengi, 6 aksesuar, rastgele).
- Online 1-4 oyuncu: ONLINE menüsü (Kur / IP ile Katıl), ev sahibi yetkili; istemci girdisi + 20 Hz anlık görüntü; bölüm sonları senkron. CI'de iki süreçli localhost testi.
- Modlar: Normal (co-op, bir kere kira kaçırma hakkı) ve Rekabetçi (2-4 kişi; herkesin kendi kasası/dükkânı; her bölüm yeni zorluk kartı birikir; 7 bölüm; kazanan). Yerel: menüde "KAPIŞMA: 2 SCOOTER"; online: lobide Mod düğmesi.
**Testler:** 300 birim kontrolü, fizik ölçümü, bot vardiyası, online host+istemci testi (normal ve rekabetçi).
**Build:** `builds/TipOver-windows-v0.6.zip`.
**Sonradan eklendi (aynı oturum):** online YOLCU rolü (birinin arkasına binip kuleyi dengele/fırlat), online AŞÇI rolü (mutfak paneli: ibreyi yeşilde durdur; iyi pişirme = sıcak/sağlam yemek; aşçı varken siparişler hazırlanmadan alınamaz), yuvarlak arabalar, park etmiş arabalar, yaya geçitleri. Build v0.4.
**Eksik / bilinen:** Steam lobileri yok (IP ile bağlanılıyor — internetten oynamak için ev sahibinin 24680 UDP portunu açması ya da ZeroTier/Radmin VPN gibi bir LAN programı gerekir); bölünmüş ekranda tekrar yok.

### KULLANICI BEKLENİYOR (fırsat olunca)
1. v0.3'ü indir, KARAKTER ekranında kendini yap, bir vardiya oyna.
2. Bir arkadaşla online dene: biri ONLINE > KUR, diğeri ONLINE > IP yaz > KATIL. Aynı evde aynı Wi-Fi'da IP yeterli; farklı evlerde ücretsiz "Radmin VPN" ile ikiniz de aynı ağa girin ve oradaki IP'yi yazın.
3. Gördüğün sorunları yaz.

### Sıradaki
Online yolcu rolü, park etmiş arabalar/yaya geçitleri, daha iyi araç modelleri, Mutfak/Paketleme rolü (Aşama 9), Steam lobileri (Steamworks sonrası).

## Oturum 3 — 1 Kasım 2026 gece (üçüncü tur istekleri)
**Eklendi:** Nunito yazı tipi + büyük/gölgeli arayüz, sadeleşen menü; 7 dil (TR, EN, ES, DE, FR, PT, RU) — arayüz, yorumlar, yükseltmeler, olaylar; görsel adım 2 (bulutlu/yıldızlı gök, SDFGI + SSR yüksek ayarda, ekran kartına göre otomatik kalite, çatı detayları, parlak yuvarlak scooter); takımlar A/B (1v1, 2v2, aşçı+kurye takımları, takım kasası/dükkânı, aşçının siparişi takıma ayrılır); takım arkadaşına yemek pası; 1-4 tuşlarıyla bağırma + isim etiketleri; vardiya içi rastgele olaylar (mutlu saat, acil VIP, sağanak, yol çalışması, konvoy); Steam kodu (lobi, davet, P2P, başarımlar) — eklenti olmadan pasif.
**Testler:** 400 birim kontrolü, fizik, pas testi, bot, online (normal/yolcu/aşçı/rekabetçi/aşçılı rekabetçi).
**Build:** `builds/TipOver-windows-v0.6.zip` (Steam eklentisi YOK — IP ile online çalışır).

### KULLANICI BEKLENİYOR
1. **GodotSteam eklentisi:** Bulutta dışarıdan gelen derlenmiş dosyaları ekleyemedim (güvenlik kuralı). Ya STEAM.md adım 1'i sen yap, ya da bana "GodotSteam'i sen ekle, onaylıyorum" yaz.
2. Fırsat bulunca v0.5'i oyna.

## Oturum 4 — 1 Kasım 2026 gece (geri bildirim düzeltmeleri)
- Arayüz küçültüldü (yazılar, sipariş paneli, butonlar, yorum kartları, açılır yazılar) — kullanıcı "çok büyük" dedi.
- Scooter'dan scooter'a yemek pası kaldırıldı (kullanıcı istemedi).
- Yayalar ve kapıdaki müşteriler artık ayakta ve insan boyunda (~1,75 m).
- Eklendi (aynı gece): yaya trafiği, rastgele şehir olayları, erişilebilirlik (tuş atama, renk körü), bölünmüş ekranda tekrar + 2. denge göstergesi, uzak silüet + deniz + çim, rekabetçi bot simülasyonu.
- Build: `builds/TipOver-windows-v0.6.zip`.
- Yarım kalan: statik mesh birleştirme (performans) — ilk deneme çok yavaştı, geri alındı; sonra tekrar denenecek.

## Oturum 5 — 1 Kasım 2026 gece (performans + yeni içerik)
- Occlusion culling: her binada kutu oklüder; şehir 3×3 parçaya bölünüp birleştiriliyor, düz renkli malzemeler tek vertex-renkli mesh oluyor. Çizim nesnesi ~3000 → ~300. (Oklüderin kendi katkısı küçük: %3-6; asıl kazanç birleştirmeden.)
- Yeni olay: BOZUK ASANSÖR — 30 sn boyunca kapıda teslim için 4 kat merdiven beklemesi, ya da balkona fırlat.
- Online tekrar: günün en büyük kazası (tüm scooter'larla) herkesin ekranında oynuyor; tekrar yazıları 7 dilde.
- Online testteki ara sıra çıkan yanlış "FAIL" düzeltildi (oyuncu önce çıkınca).
- Build: `builds/TipOver-windows-v0.7.zip`.
