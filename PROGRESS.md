# PROGRESS

Saatlik tetikleyici: `trig_01YGVX4aggfGhdgvnmukKuyB` — 1 Kasım 12:42 UTC itibarıyla KAPALI (geriye sadece kullanıcıya bağlı işler kaldı). Kullanıcı geri bildirim verince yeniden açılabilir.

## Test komutları
- Birim testleri: `godot --headless --path . -s tests/run_tests.gd`
- Fizik hissi ölçümü: `godot --headless --path . --fixed-fps 60 res://tests/sim_drive.tscn`
- Bot bir vardiya oynar: `godot --headless --path . --fixed-fps 60 res://tests/bot_shift.tscn -- --days=3`
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
