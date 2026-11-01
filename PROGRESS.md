# PROGRESS

Saatlik tetikleyici: `trig_01YGVX4aggfGhdgvnmukKuyB` (her saat :08'de bu oturumu uyandırır; PLAN bitince kapatılacak).

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
**Build:** `builds/TipOver-windows-v0.1.zip`. Ayrıca GitHub Actions her push'ta .exe üretir (Actions sekmesi > son çalışma > Artifacts).

### KULLANICI BEKLENİYOR
Prototipi oyna ve his hakkında yaz (adımlar README.md'de). Özellikle: (1) scooter sürmek eğlenceli mi, (2) çorba çok mu kolay/zor dökülüyor, (3) kule çok mu çabuk devriliyor, (4) 1. gün kirası (50$) kolay mı.

### Sıradaki
Buhar efekti, fareyle denge, kapıda müşteri tepkisi, iki scooter bölünmüş ekran, kaza tekrarı.
