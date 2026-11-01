# Tip Over (çalışma adı: Hot Delivery)

Berbat bir scooter'la, arkadaki yemek kulesini devirmeden ve soğutmadan teslim etmeye çalıştığın fizik komedisi.

- Plan: [PLAN.md](PLAN.md) · İlerleme: [PROGRESS.md](PROGRESS.md) · Lisanslar: [CREDITS.md](CREDITS.md)

## En kolay yol: hazır .exe (Windows)
1. GitHub'da bu dalda `builds/TipOver-windows-v0.2.zip` dosyasına tıkla > **Download** (sağ üstte indirme simgesi).
2. Zip'e sağ tıkla > **Tümünü ayıkla**.
3. `TipOver.exe`'ye çift tıkla. Windows "bilinmeyen yayıncı" derse: **Ek bilgi > Yine de çalıştır** (imzasız olduğu için normal).

## Godot ile açma (kodu değiştirmek için)
1. Godot 4.6 indir: https://godotengine.org/download (standart sürüm, .NET değil).
2. Bu repoyu indir: yeşil **Code** düğmesi > **Download ZIP** > klasöre çıkar.
3. Godot > **Import** > `project.godot` > **Import & Edit** > sağ üstte ▶ veya **F5**.

## Kontroller
| | Klavye | Gamepad |
|---|---|---|
| Sür | W/S gaz-fren, A/D direksiyon | RT/LT, sol çubuk |
| Kuleyi dengele | Ok tuşları | Sağ çubuk |
| Fırlat (en üstteki yemek) | Boşluk | A |
| Yerden al | F | X |
| Korna / Kalk | H / R | B / Y |
| Ekran görüntüsü | F12 | Select |

Co-op (sürücü + yolcu): 1. oyuncu WASD + H; 2. oyuncu oklar (denge), Enter (fırlat), Sağ Shift (al). Ya da iki gamepad.

**Nasıl oynanır:** turuncu ışık = restoran (yavaşla, yemek otomatik yüklenir). Yeşil ışık = müşteri (yanında dur ya da en üstteki yemeği balkondaki sarı halkaya fırlat → 2 kat bahşiş). Yeşil ok yolu gösterir. Alttaki daire kulenin ne kadar eğik olduğunu gösterir: kırmızıya dönerse oklarla ters yöne it.
