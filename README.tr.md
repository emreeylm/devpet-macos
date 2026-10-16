# DevPet — macOS için Claude Code ve Codex Kullanım Limiti Takibi

**Claude Code ve OpenAI Codex kalan kullanım haklarını masaüstünde gösteren, piksel maskotlu yerel bir Mac uygulaması.** Beş saatlik ve haftalık limitlerini gör, yenilenme süresini takip et; maskotsuz Minimal görünüm, Yalnız maskot veya Geniş panel arasında geçiş yap.

[Mac için indir](https://github.com/emreeylm/devpet-macos/releases/latest) · [English](README.md) · [Bağlantı rehberi](Docs/INTEGRATIONS.md)

![DevPet: Claude Code ve Codex kalan kullanım yüzdelerini ve yenilenme sürelerini gösteren Mac masaüstü aracı](Docs/images/devpet-usage-widget.png)

*Ekran görüntülerindeki değerler örnek veridir; gerçek bir hesaba ait değildir.*

Limit bildirimleri: Ayarlar → Davranış bölümünden %25/%15 uyarılarını, kullanım hakkı bitişini ve doğrulanmış kota yenilenmesini açabilirsiniz. Eşikler ayarlanabilir; aynı uyarı kota dönemi başına bir kez gönderilir. Minimal, Yalnız maskot ve Geniş görünümler ekran konumlarını ayrı hatırlar; monitör çıkarılırsa görünür ekrana döner.

## Neler yapar?

- **Claude Code ve Codex tek yerde:** İkisini birlikte veya yalnızca birini göster.
- **Kalan kota ve yenilenme:** Beş saatlik / haftalık kalan yüzdeleri ve sağlayıcıdan gelen beş saatlik sıfırlanma sayacını takip et. Tam tarih ve saat için sayacın üzerine gel.
- **Her zaman üstte:** Pencereyi sürükleyip istediğin yere koy. Menü çubuğundan gizle, geri getir veya görünümü değiştir.
- **12 piksel maskot:** Kedi, köpek, tilki, panda, tavşan, ayı, baykuş, kurbağa, penguen, rakun, kapibara ve kurt. Her birinin özel bardağı var.
- **Kotaya göre çalışma:** Beş saatlik hak %50 üstündeyken hızlı, %15–50 arasındayken yavaş yazma; %15 altındayken uyku. Haftalık limit animasyona karışmaz.
- **Kişiselleştirme:** Sekiz tema, özel vurgu rengi, açık/koyu görünüm, şeffaf arka plan, %50–250 boyut ve opaklık ayarı.
- **Mac'e yerel:** SwiftUI ve AppKit, Apple Silicon + Intel, isteğe bağlı oturum açılışında başlatma ve bildirimler. Türkçe/İngilizce arayüz.

## Üç görünüm

| Görünüm | İçerik |
| --- | --- |
| **Minimal** | Maskot ve bardak olmadan küçük Claude/Codex limit kartları |
| **Yalnız maskot** | Piksel pet, sabit bardak ve kalan limitler |
| **Geniş** | Sağlayıcı bölümleri ayrı ayrı açılıp kapanan, yeniden boyutlandırılabilir panel |

**Ayarlar → Pencere → Görünüm modu** yolundan, menü çubuğundan veya küçük pencereye sağ tıklayarak değiştir. Minimal pencerenin herhangi bir yerinden tutup taşıyabilirsin.

![Maskotsuz Minimal kota penceresi](Docs/images/devpet-minimal.png)

## Kurulum

**Gereksinimler:** macOS 14 Sonoma veya üstü. Uygulama Apple Silicon ve Intel için evrensel derlemedir. Gerçek kota verisi için desteklenen, giriş yapılmış bir Claude Code veya Codex oturumu gerekir. Örnek modu hesapsız deneyebilirsin.

1. [Son sürümden](https://github.com/emreeylm/devpet-macos/releases/latest) **DevPet.dmg** dosyasını indir.
2. Açıp **DevPet.app** uygulamasını **Applications / Uygulamalar** klasörüne sürükle ve başlat.
3. **Ayarlar → Sağlayıcılar** bölümünde bağlantıyı kur veya önce **Örnek modu** aç.
4. **Ayarlar → Pencere** bölümünden görünümü seç.

Mevcut indirmeler ad-hoc imzalıdır; **Apple noter onayı yoktur**. macOS güvenlik uyarısı gösterebilir. İstersen kaynaktan derle; Gatekeeper'ı devre dışı bırakma. Ayrıntılar: [sürüm rehberi](Docs/RELEASING.md).

### Codex bağlantısı

Codex CLI'a ChatGPT hesabınla `codex login` üzerinden giriş yap. DevPet yaygın kurulum yollarını ve Codex.app içindeki CLI'ı bulabilir; istersen ayarlardan çalıştırılabilir dosya yolunu belirt. Yerel app-server protokolündeki kota verisini okur; model konuşması başlatmaz ve token dosyalarını okumaz. API anahtarıyla kullanılan hesaplar abonelik kotası sunmayabilir.

### Claude Code bağlantısı

**Ayarlar → Sağlayıcılar** bölümündeki `statusLine` yapılandırmasını mevcut Claude ayarlarına elle birleştir. DevPet ayar dosyanı değiştirmez. Zaten bir statusline kullanıyorsan [bağlantı rehberindeki](Docs/INTEGRATIONS.md) sarmalayıcı yöntemini kullan.

Claude verisi etkin oturumdan gelir. Oturum boşta dururken uygulama kendi başına yeni kota çekemez; eski gözlemler güncelmiş gibi gösterilmez.

## Gizlilik

DevPet hesabı, analiz SDK'sı veya DevPet'e ait sunucu yoktur. Ayarlar Mac'inde kalır. Kodun, istemlerin, konuşmaların, kimlik bilgilerin ve oturum dökümlerin toplanmaz. Claude köprüsü yalnızca temizlenmiş kota yüzdeleri ve zaman damgaları saklar; Codex kendi kimlik doğrulamasını ve ağ bağlantısını yönetir.

[Gizlilik açıklaması](PRIVACY.md) · [Sağlayıcı verisi ve sorun giderme](Docs/INTEGRATIONS.md)

## Kaynaktan derleme

Güncel Xcode, komut satırı araçları ve proje üretimi için Python 3 gerekir.

```sh
git clone https://github.com/emreeylm/devpet-macos.git
cd devpet-macos
swift test
Scripts/build.sh
open dist/DevPet.app
```

Alternatif olarak `DevPet.xcodeproj` dosyasını Xcode'da açıp **DevPet → My Mac** ile çalıştır. Yeni Swift dosyaları eklediğinde `python3 Scripts/generate-project.py` komutunu kullan.

```sh
Scripts/dmg.sh
Scripts/validate.sh
```

## Sık sorulanlar

**DevPet kullanım hakkını artırır veya limiti sıfırlar mı?** Hayır. Sağlayıcıların verdiği kota ve yenilenme bilgisini gösterir; hesabını veya planını değiştiremez.

**Claude'da neden veri yok?** Statusline kurulmalı ve desteklenen etkin oturum kota alanlarını göndermeli. Eksik, süresi dolmuş veya eski veri kullanılabilir sayılmaz. Ayrıntılar bağlantı rehberinde.

**Bu bir macOS masaüstü widget'ı mı?** Menü çubuğunda yaşayan, masaüstünün üzerinde açılan bir pencere. WidgetKit / Bildirim Merkezi aracı değildir.

**24 ve 32 inç monitörlerde net mi?** İnç yerine çözünürlük ve piksel yoğunluğu belirleyicidir. Yazılar etkin ekran ölçeğinde çizilir; piksel çizimlerinin kenarları bulanıklaştırılmadan ölçeklenir. Tüm fiziksel ekran/tam ekran/Intel birleşimleri denenmiş değildir.

**Çizimler nasıl hazırlandı?** Bu proje için üretilmiş, uygulamanın içinde gelen piksel görselleridir. Kullanım sırasında uzaktan görsel indirilmez. Kahve içme animasyonu yoktur; yalnızca klavyede yazma hareketi vardır.

## Destek ve katkı

[Hata bildir veya özellik öner](https://github.com/emreeylm/devpet-macos/issues). macOS sürümünü, görünümü ve sorunu yeniden üretme adımlarını ekle; token, özel hesap bilgisi veya konuşma içeriği paylaşma. [Katkı rehberi](CONTRIBUTING.md).

Geliştirici: [Yunus Emre Yılmaz](https://github.com/emreeylm). [MIT lisansı](LICENSE).

DevPet bağımsız bir projedir; Anthropic veya OpenAI ile bağlantılı değildir ve bu şirketler tarafından onaylanmış değildir.
