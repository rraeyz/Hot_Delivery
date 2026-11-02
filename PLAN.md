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
- [ ] (isteğe bağlı) Bot ile menü arka planı
- [x] Felaket tekrarı (en büyük kaza ağır çekim)
- [x] Efektler: buhar, çorba lekesi, parçacıklar, ekran sarsıntısı
- [x] Mahalleler: Çarşı, Sahil (4. gün rekoru açar), Şehir Merkezi (7. gün) — yokuş yerine rampa/yükseklik farkı
- [x] Kozmetikler: 8 scooter rengi, her 2 günlük rekorda biri açılır
- [x] Her 3. gün düğün pastası "boss" siparişi
- [x] Sıkışınca otomatik kurtarma (R de aynı)
- [ ] Denge geçişi (para hızı, kira eğrisi) — KULLANICI geri bildirimi bekleniyor
- [x] Steam mağaza metinleri (STORE.md) + oyundan ekran görüntüleri (marketing/)
- [ ] GodotSteam (başarımlar) — Steamworks hesabı + App ID bekleniyor

## Kullanıcının yapacakları (sırası gelince PROGRESS.md'de "KULLANICI BEKLENİYOR" yazar)
- [ ] Prototipi oyna, his hakkında 3 cümle yaz
- [ ] İsmi seç
- [ ] Steamworks hesabı + 100$ (Steam sayfası için)
- [ ] Arkadaşla co-op testi

---
# İKİNCİ TUR (kullanıcı isteği, 1 Kasım 2026)
İstekler: 2 kişiden fazla oyuncu, online; Normal (co-op) + Rekabetçi mod (PlateUp gibi: her bölüm yeni zorluk, kazanılan parayla işi kolaylaştıran şeyler); grafik seviyesi yükselmeli (Vulkan); karakter özelleştirme; yemek yapma fikrine öneri.

**Karar (yemek yapma):** Tam yemek pişirme EKLEMİYORUZ — Overcooked/PlateUp kopyasına döner ve kapsamı ikiye katlar; bizim farkımız scooter + yemek kulesi. Onun yerine 3-4 kişilik oyunda hafif bir **"Mutfak/Paketleme" rolü**: restoranda bir oyuncu siparişi hazırlar (çorbayı kepçeyle doldurur — fazla dolu kase daha kolay dökülür, pizzayı fırından zamanında alır, kuleyi doğru sırayla dizer) ve kuryeye verir. Böylece restoran ↔ kurye takım oyunu oluşur ama oyunun kalbi teslimat kalır.

## Aşama 5 — Görsel yenileme (Vulkan / Forward+)
- [x] Forward+ görüntüleyici (Vulkan yoksa otomatik OpenGL'e düşer), AgX/ACES ton, SSAO, SSIL, glow, volumetrik sis, kaliteli gölgeler
- [x] Grafik kalitesi ayarı (Düşük = eski görünüm, Orta, Yüksek)
- [x] Prosedürel dokular: asfalt (gürültü + normal), kaldırım taşı, bina cephesi (pencere çerçevesi, kat bantları, kapı/vitrin), çatı detayları
- [x] Sokak detayları: kaldırım kenarı, yaya geçidi, sokak lambası, ağaç, bank, tabela, park etmiş arabalar
- [x] Daha iyi araç ve scooter modelleri (yuvarlatılmış şekiller), far ışıkları
- [x] Gün saati (sabah / öğle / gün batımı / gece — gece lambalar yanar) her vardiyada değişir

## Aşama 6 — Karakter özelleştirme
- [x] Yeni kurye modeli (kafa, gövde, kollar, bacaklar, eller; basit animasyon: el sallama, düşme)
- [x] Özelleştirme ekranı: ten rengi, ceket rengi, kask tipi (klasik/kedi kulağı/korsan/şef şapkası…), kask rengi, aksesuar (gözlük/bıyık/atkı), scooter rengi
- [x] Ayarlar kayıt dosyasında; online oyunda diğer oyunculara gönderilir

## Aşama 7 — Online çok oyunculu (1-4 kişi)
- [x] Ağ mimarisi: ev sahibi yetkili (host simüle eder, istemciler girdi yollar), Godot ENet ile
- [x] Senkronizasyon: scooter'lar, yemek kulesi, düşen yemekler, siparişler, para, olaylar; ara karelerde yumuşatma
- [x] Lobi ekranı: Oluştur / IP ile katıl / LAN; oyuncu listesi, hazır, karakter görünümü
- [x] Otomatik test: iki ekransız Godot süreci localhost üzerinden bağlanıp vardiya oynar
- [x] Her oyuncu kendi scooter'ında; isteyen "yolcu" olarak birinin arkasına biner (sürücü + yolcu online)
- [ ] Steam lobileri (GodotSteam, App ID 480 ile geliştirme) — KULLANICI: Steamworks hesabı sonrası gerçek App ID

## Aşama 8 — Modlar
- [x] **Normal (co-op, 1-4):** ortak kasa, kira; kira kaçırılırsa 1 uyarı hakkı
- [x] **Rekabetçi (2-4):** her oyuncu/ekip kendi şirketi ve kasası; aynı siparişler için yarış; her bölüm sonunda yeni **zorluk kartı** kalıcı eklenir (yağmur hep var, müşteriler sabırsız, köprü kapalı, köpek sürüsü…); bölümler arası herkes kendi parasıyla dükkândan yükseltme alır; 7 bölüm sonunda en zengin kazanır (bölüm sonunda kirayı ödeyemeyen elenir)
- [x] Rekabetçi oyuncular arası etkileşim: korna ile itme, başkasının düşen yemeğini çalma (bahşişi düşük), yolu kesme
- [x] Mod seçim ekranı + kurallar ekranı

## Aşama 9 — Mutfak/Paketleme rolü
- [x] Mutfak paneli: siparişi seç, ibreyi yeşil bölgede durdur (yemeğe göre hız); iyi zamanlama = daha sıcak/sağlam yemek
- [x] Aşçı rolü (online): siparişler hazırlanmadan alınamaz (gri ışık 'HAZIRLANIYOR'); aşçı yoksa otomatik hazır

## Aşama 9b — Üçüncü tur istekleri (1 Kasım akşam)
- [x] Yazı tipi Nunito (OFL), büyük ve gölgeli arayüz; menü sadeleştirildi (Aynı Ekran alt menüsü)
- [x] Diller: İspanyolca, Almanca, Fransızca, Portekizce, Rusça (+ Türkçe, İngilizce)
- [x] Görsel adım 2: bulutlu/yıldızlı gökyüzü, SDFGI (Yüksek), SSR, ekran kartına göre otomatik kalite, çatı detayları, parlak yuvarlak scooter
- [x] Takımlar (A/B): rekabetçide takım kasası/dükkânı; 1v1, 2v2, aşçı+kurye takımları; aşçının yaptığı sipariş 12 sn takıma ayrılır; aşçı yoksa 15 sn'de otomatik hazır
- [x] ~~Takım arkadaşına yemek pası~~ — kullanıcı istemedi, kaldırıldı
- [x] İşaretleşme: 1-4 tuşları / d-pad (YARDIM! BURAYA! HAHA! ACELE ET!), scooter üstünde isim etiketleri
- [x] Steam kodu: lobi + arkadaş daveti + P2P + başarımlar (scripts/steam_bridge.gd, STEAM.md)
- [x] Vardiya içi rastgele şehir olayları (40-70 sn'de bir): mutlu saat, acil VIP sipariş, ani sağanak, yol çalışması, düğün konvoyu
- [ ] KULLANICI: GodotSteam eklentisini projeye eklemeye onay ver / ekle (STEAM.md adım 1) — sonra Steam testleri

## Aşama 10 — Sürekli geliştirme (liste bitince buradan devam)
- [x] İlk vardiya eğitimi (ok + kısa ipuçları: "restorana git", "yavaşla", "balkona fırlat")
- [x] Köpek ve güvercinler en yakın scooter'ı hedeflesin (çok oyunculu)
- [x] Bölünmüş ekranda 2. oyuncunun denge göstergesi + tekrar (replay)
- [x] Online'da tekrar: ev sahibi günün en büyük kazasını (tüm scooter'lar) herkese yollar
- [x] Yeni olay: düğün konvoyu (raporda vardı) — korna çalan araba dizisi yolu kapatır
- [x] Yeni olay: bozuk asansör — 30 sn boyunca kapıda teslim için 4 kat merdiven (dur ve bekle) ya da balkona fırlat (bot testi: `--elevator`)
- [x] Rekabetçi denge: 2 bot simülasyonu (tests/comp_sim.tscn) — skorlar yakın, kartlar teslimatı azaltıyor
- [x] Yorumlar için daha fazla dil (ES, DE, PT-BR, RU) — dünya pazarı
- [x] Erişilebilirlik: renk körü dostu işaretler, tuş atama ekranı
- [x] Performans: occlusion culling (her binada kutu oklüder) + parçalı ve vertex-renkli mesh birleştirme (3000 → ~300 çizim nesnesi), tests/perf_count.tscn
- [x] Steam başarımları: 15 başarım kodda bağlı (online dahil), ad/açıklama tablosu STEAM.md'de — GodotSteam gelince otomatik çalışır
- [x] Yeni yemekler: dev JÖLE (çok sallanır ama kırılmaz, 7. gün açılır) ve 4'lü KAHVE tepsisi (en ufak frende döker, 8. gün açılır)
- [x] Yeni olay: ŞEHİR MARATONU — 16 koşucu bir caddeden akar, çarpınca takla atarlar (online aynı paket)
- [x] Yeni yükseltmeler: Şemsiyeli Şapka (yağmur/sağanak etkisiz), Köpek Ödülü (köpek ısırmaz, güvercin gelmez)
- [ ] Yeni yemekler / olaylar / yükseltmeler, oyuncu geri bildirimine göre denge, hata düzeltme
