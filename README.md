# Pano 📋

macOS için Swift ve SwiftUI ile geliştirilmiş, ultra hafif, hızlı ve modern pano (clipboard) yöneticisi. Maccy'den ilham alınarak tasarlanmıştır.

![macOS 13+](https://img.shields.io/badge/macOS-13.0%2B-blue)
![Swift 6](https://img.shields.io/badge/Swift-6.0-orange)
![License](https://img.shields.io/badge/license-MIT-green)

---

## ✨ Özellikler

- 📌 **Menü Çubuğu Entegrasyonu**: Dock'u ve Cmd+Tab menüsünü kirletmeden arka planda bir menü çubuğu ajanı (`LSUIElement`) olarak çalışır.
- ⚡ **Çift Global Kısayol**: Dilediğiniz her an **`⇧⌘C`** (`Shift + Command + C`) veya **`⇧⌘V`** (`Shift + Command + V`) kısayoluyla imlecinizin bulunduğu yerde açılır.
- 🖼️ **Canlı İmleç Takipli Görsel Önizleme**: Bir görsel öğesinin üzerine geldiğinizde görselin en-boy oranına göre dinamik boyutta bir önizleme kartı açılır ve fare imlecinizi canlı olarak takip eder. İmleç öğe kutusunun dışına çıktığında otomatik olarak kapanır.
- ⌨️ **Tam Klavye Desteği**:
  - **`↓` / `↑`**: Öğeler arasında gezinir, liste seçimi otomatik kaydırır.
  - **`Enter`**: Seçili öğeyi panoya kopyalar ve pencereyi kapatır.
  - **`Delete` / `Backspace` (`⌫`)**: Seçili öğeyi listeden anında siler. Arama yaparken `⌘⌫` veya `⌥⌫` ile silinebilir.
  - **`⌘1` - `⌘9`**: İlk 9 öğeyi tek tuşla seçip kopyalar.
  - **`ESC`**: Pencereyi kapatır.
- 🔍 **Anında Arama**: Pencere açıldığı anda arama kutusu odaklanır, yazdıkça gerçek zamanlı filtreler.
- 📌 **Sabitleme**: Önemli kopyaları listenin en başında sabitleyin.
- 🗑️ **Satır İçi (Inline) Temizleme**: Pencereyi kapatmadan veya harici modal açmadan alt panelden "Sabitlenenler Hariç" veya "Tümünü Temizle" seçenekleri.
- ⚙️ **Ayarlar Menüsü**:
  - Mac açıldığında otomatik başlama (Launch at login).
  - Geçmiş hafızası limiti (50, 100, 150, 300, 500 öğe).
  - GitHub proje sayfasına doğrudan erişim.
- 🛡️ **Parola Yöneticisi Koruması**: 1Password ve sistem gizli veri türlerini (`org.nspasteboard.ConcealedType`) otomatik olarak filtreleyerek hassas bilgileri kaydetmez.
- 💾 **Kalıcı Depolama**: Geçmiş verileriniz yerel olarak `~/Library/Application Support/Pano/history.json` dosyasında JSON formatında güvenle saklanır.

---

## 🛠️ Kurulum & Derleme

Xcode ve Swift araçları yüklü bir Mac terminalinde:

```bash
# Projeyi klonlayın
git clone git@github.com:HEXRA0/Pano.git
cd Pano

# Derleyin ve paketleyin (.app)
chmod +x scripts/build_app.sh
./scripts/build_app.sh

# Uygulamayı başlatın
open Pano.app
```

---

## ⌨️ Kısayollar

| Kısayol | İşlev |
|---|---|
| `⇧⌘C` veya `⇧⌘V` | Pano'yu imleç konumunda aç / kapat |
| `↓` / `↑` | Listede gezin |
| `Enter` | Seçili öğeyi kopyala ve pencereyi kapat |
| `⌫` (Delete) | Seçili öğeyi sil (arama alanındayken `⌘⌫`) |
| `⌘1` .. `⌘9` | İlk 9 öğeyi doğrudan seç |
| `ESC` | Pano'yu kapat |

---

## 📄 Lisans

Bu proje [MIT](LICENSE) lisansı ile lisanslanmıştır.
