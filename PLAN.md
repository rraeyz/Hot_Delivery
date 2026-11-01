# PLAN — "Tip Over" (çalışma adı: Hot Delivery)

Her oturumun başında bu dosyayı ve PROGRESS.md'yi oku. Sıradaki `[ ]` görevi al, yap, test et, commit + push, `[x]` yap.

## Rapordan büyük değişiklikler (neden?)

1. **Yemek kulesi (Stack).** Siparişler kutuda saklanmıyor; scooter'ın arkasında üst üste bir kule olarak duruyor. Her yemek sallanıyor, en üsttekiler daha çok. Neden: izleyici 1 saniyede riski görüyor ("o kule devrilecek!") ve açgözlülük kararı doğuyor: 4 sipariş üst üste = kombo bahşiş ama devrilme riski.
2. **30 günlük kariyer yerine roguelite "kira" koşusu.** Her gün kısa bir vardiya (3–4 dk), gün sonunda kira hedefi. Tutturamazsan kovulursun, baştan başlarsın. Arada rastgele 3 yükseltme kartı (hepsinin komik bir yan etkisi var), her gün rastgele "şehir kaosu" ve müşteri huyları. Neden: aynı oyun hiç tekrar etmiyor; yayıncı "bir koşu daha" diyor, izleyici "ben daha ileri giderim" diyor. Koşular arası kalıcı açılımlar (yeni yemekler, mahalleler, kasklar) 2+ saatlik oturumu taşıyor.
3. **Çok oyunculu: önce yerel (aynı ekran) co-op.** Sürücü + yolcu aynı bilgisayarda (klavye + gamepad). Steam'in **Remote Play Together** özelliği yerel co-op oyunlarını internetten arkadaşla oynatıyor; ağ kodu yazmadan online co-op elde ediyoruz. Neden: en riskli ve en uzun teknik parça ortadan kalkıyor, oyun daha erken satılabilir. Gerçek online (Steam P2P) çıkıştan sonra.
4. **Şehir her koşuda rastgele üretiliyor** (ızgara sokaklar, rampalar, tümsekler, devrilebilen eşyalar). Neden: rota ezberlenmiyor, her video farklı.
5. **Günlük meydan okuma (Daily Run).** Herkes aynı gün aynı şehir + aynı kaosla oynar. Neden: yayıncılar ve izleyiciler skorlarını karşılaştırır, ücretsiz tekrar oynanabilirlik.
6. **Grafik ve ses: kendi ürettiğimiz.** Şehir/araç/yemek Godot'nun basit şekilleriyle (oyuncak gibi, parlak); sesler ve müzik kod/sentezle üretiliyor. Neden: lisans riski sıfır, indirme bağımlılığı yok. Sonra CC0 paketlerle (Kenney) güzelleştirilebilir.
7. **Motor: Godot 4.6, GL Compatibility görüntüleyici.** Neden: zayıf laptoplarda ve Steam Deck'te çalışsın.

## İsim önerileri (Steam mağaza aramasında 1 Kasım 2026'da tam eşleşme çıkmadı; marka tescili kontrol EDİLMEDİ)
1. **Tip Over** ← önerim (tip = bahşiş, tip over = devrilmek)
2. Soupersonic
3. Soup Runners
4. Still Hot!
5. Keep It Hot

## Aşama 0 — Kurulum
- [x] Godot 4.6.2 (bulutta, ekransız test için)
- [x] PLAN.md, PROGRESS.md, README.md, CREDITS.md
- [x] Godot projesi iskeleti + otomatik test koşucusu (`tests/run_tests.gd`)
- [x] GitHub Actions: her push'ta testleri çalıştır + Windows .exe üret (artifact)

## Aşama 1 — Prototip (his)
- [x] Saf mantık: yemek modeli (sıcaklık, sallanma, çorba çalkalanması, dökülme) + testler
- [x] Saf mantık: bahşiş + yıldız hesabı + testler
- [x] Scooter kontrolcüsü (RigidBody, ışın süspansiyonu, kayma, fren, korna)
- [x] Takip kamerası (yumuşak, sallantı ayarı)
- [x] Kısa test sokağı: rampa, tümsek, devrilebilen eşyalar
- [x] Yemek kulesi: pizza + çorba arkada sallanıyor, eşiği geçince düşüyor (fizik nesnesine dönüşüyor)
- [x] Yerden geri alma (E)
- [x] Kaza: kurye uçar, yemekler saçılır, 2 sn sonra kalkar
- [x] Ekran görüntüsüyle görsel kontrol (Xvfb) + his ayarı
- [x] Windows .exe (prototip: builds/TipOver-windows-v0.2.zip)
- [ ] KULLANICI testi: "sürmek eğlenceli mi?"

## Aşama 2 — Tek kişilik tam oyun
- [x] Rastgele şehir üretici (ızgara, binalar, restoranlar, müşteri evleri, balkonlar)
- [x] Sipariş sistemi (al → teslim et), yön oku, mesafe
- [x] Teslim: dur-ve-ver + balkon atışı (çifte bahşiş)
- [x] Müşteri yorum kartları (TR + EN, etiketlere göre komik cümleler)
- [x] Vardiya: süre, kira hedefi, gün sonu özeti, en komik 3 yorum, ekran görüntüsü kaydet (F12)
- [x] Garaj: rastgele 3 yükseltme kartı, yan etkiler, yeniden çek
- [x] Günlük şehir kaosu (yağmur, rüzgâr, köpek, güvercin, sıcak dalgası, tümsek günü, trafik)
- [x] Müşteri huyları (Fırlat!, VIP, Sabırsız, En üst kat)
- [x] Trafik arabaları
- [x] Ana menü, ayarlar (ses, kamera sallantısı, dil), duraklat menüsü
- [x] Kayıt sistemi + kalıcı açılımlar (yemekler, mahalleler, kasklar)
- [x] Daily Run (tarih tohumlu)
- [x] Yeni yemekler: hamburger kulesi, içecek, dondurma (eriyor), suşi, düğün pastası (boss)
- [x] Ses: motor, korna, sıçrama, kasa, müzik (sentez)
- [ ] Windows .exe + KULLANICI testi

## Aşama 3 — Çok oyunculu (yerel)
- [x] Sürücü + yolcu (aynı scooter, iki kontrolcü/klavye ikiye bölünmüş)
- [x] İki scooter (bölünmüş ekran)
- [x] Gamepad desteği ve kontrol ekranı
- [ ] KULLANICI: Remote Play Together ile arkadaşla test (Steam sayfası açıldıktan sonra)

## Aşama 4 — İçerik ve cila
- [x] Sıcak yemekte buhar efekti (buhar azaldıkça soğuyor)
- [x] Fareyle denge (tek kişilik)
- [x] Kapıda müşteri figürü + tepki (sevinç/öfke)
- [ ] Bot ile menü arka planı (attract mode)
- [x] Felaket tekrarı (en büyük kaza ağır çekim)
- [ ] Efektler: buhar, çorba lekesi, parçacıklar, ekran sarsıntısı
- [x] Mahalleler: Çarşı, Sahil (4. gün rekoru açar), Şehir Merkezi (7. gün) — yokuş yerine rampa/yükseklik farkı
- [x] Kozmetikler: 8 scooter rengi, her 2 günlük rekorda biri açılır
- [x] Her 3. gün düğün pastası "boss" siparişi
- [x] Sıkışınca otomatik kurtarma (R de aynı)
- [ ] Denge geçişi (para hızı, kira eğrisi)
- [ ] Steam mağaza metinleri + kapak/ekran görüntüleri (oyundan)
- [ ] GodotSteam (başarımlar) — isteğe bağlı

## Kullanıcının yapacakları (sırası gelince PROGRESS.md'de "KULLANICI BEKLENİYOR" yazar)
- [ ] Prototipi oyna, his hakkında 3 cümle yaz
- [ ] İsmi seç
- [ ] Steamworks hesabı + 100$ (Steam sayfası için)
- [ ] Arkadaşla co-op testi
