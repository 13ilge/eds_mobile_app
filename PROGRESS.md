# EDS Mobile App — Sosyal & Abonelik Özellikleri İlerleme Planı

> Oluşturulma: **29 Temmuz 2026**
> Son güncelleme: **4 Ağustos 2026**
> Durum: **Planlama aşaması**

---

## Teknoloji Kararları

| Karar | Seçim | Gerekçe |
|---|---|---|
| Backend | **Firebase** (Auth + Firestore + Cloud Functions) | Flutter SDK'sı olgun, ücretsiz kota yeterli, realtime sync ile sosyal özellikler kolay |
| Kimlik Doğrulama | **E-posta/Şifre + Google Sign-In** | Firebase Auth ile native destek |
| Ödeme/Abonelik | **RevenueCat** | Google Play + App Store tek SDK, webhook/analytics dahil |
| Üyelik Modeli | **Free + Pro** (2 katman) | Basit, anlaşılır fiyatlandırma |
| State Management | **Riverpod** (`flutter_riverpod`) | Auth ve abonelik stream'lerini reaktif dinleme, compile-time güvenliği, test edilebilirlik |

> [!IMPORTANT]
> **Abonelik Tek Gerçek Kaynağı (Single Source of Truth)**: Pro durumu her zaman **RevenueCat `CustomerInfo.entitlements`** üzerinden kontrol edilir, Firestore `isPro` alanından değil. Firestore'daki `isPro` yalnızca Cloud Functions (sunucu tarafı) için RevenueCat Webhook'ları ile güncellenir. Kullanıcı App Store/Play Store'dan aboneliği iptal ettiğinde Firestore otomatik güncellenmez — bu yüzden istemci tarafında asla Firestore'a güvenilmez.

> [!WARNING]
> **Firestore Maliyet Optimizasyonu**: `community_points` koleksiyonu GeoHash + sayfalama (pagination) kullanmalıdır. Free kullanıcılar her açılışta binlerce nokta çekerse fatura patlar. Sadece kullanıcının 50 km çapındaki noktalar yüklenmelidir.

---

## Üyelik Katmanları

| Özellik | Free | Pro |
|---|:---:|:---:|
| GPS takip (mevcut tüm özellikler) | ✅ | ✅ |
| Sınırsız yerel EDS noktası kaydetme | ✅ | ✅ |
| Topluluk EDS noktalarını görme (salt okunur) | ✅ | ✅ |
| Reklamsız deneyim | ✅ | ✅ |
| Arkadaş ekleme | ❌ | ✅ (sınırsız) |
| EDS noktalarını arkadaşlara gönderme | ❌ | ✅ |
| Arkadaşlardan gelen EDS noktalarını alma | ❌ | ✅ |
| Topluluk havuzuna EDS noktası paylaşma | ❌ | ✅ |

---

## Faz Planı

### Faz 0 — Altyapı Kurulumu
> Tüm sonraki fazların bağımlılığı

- [x] Firebase projesi oluştur (Firestore, Auth, Cloud Functions)
- [x] `firebase_core`, `firebase_auth`, `cloud_firestore` paketlerini `pubspec.yaml`'a ekle
- [x] `google_sign_in` paketini ekle
- [x] `flutter_riverpod` paketini ekle
- [x] Android `google-services.json` + iOS `GoogleService-Info.plist` yapılandır
- [x] Firebase güvenlik kurallarını (Firestore Rules) yaz
- [x] Riverpod altyapısını kur:
  - [x] `main.dart`'ta `ProviderScope` ile uygulamayı sar
  - [x] `lib/providers/` klasörü oluştur
  - [x] `auth_provider.dart` — Firebase Auth `authStateChanges()` stream'ini dinleyen `StreamProvider`
  - [x] `subscription_provider.dart` — RevenueCat `CustomerInfo` stream'ini dinleyen `StreamProvider`
  - [x] `user_profile_provider.dart` — Firestore kullanıcı profilini dinleyen `StreamProvider`
- [x] `lib/models/user_profile.dart` modeli oluştur

> **Not — Mevcut singleton servisler**: `AudioService`, `EdsStorageService`, `EdsGeofenceService` gibi mevcut singletonlar olduğu gibi kalır (GPS/offline katmanı). Riverpod yalnızca yeni ağ-bağımlı servisler (auth, subscription, friends, sharing) ve bunların UI'a reaktif yansıması için kullanılır.

#### Firestore Veri Yapısı (Tasarım)

```
users/{uid}
  ├── displayName: string
  ├── email: string
  ├── photoUrl: string?
  ├── isPro: boolean              ⚠️ SADECE sunucu tarafı (Cloud Functions) için!
  │                                  RevenueCat Webhook ile güncellenir.
  │                                  İstemci tarafında ASLA bu alana bakma,
  │                                  her zaman RevenueCat CustomerInfo.entitlements kullan.
  ├── createdAt: timestamp
  └── friendCount: number

friendships/{id}
  ├── fromUid: string
  ├── toUid: string
  ├── status: "pending" | "accepted" | "rejected"
  ├── createdAt: timestamp
  └── participants: [uid1, uid2]  // array-contains sorgusu için

shared_points/{id}
  ├── ownerUid: string
  ├── ownerName: string
  ├── targetUid: string | null     // null = topluluk paylaşımı
  ├── edsPoint: map (EdsPoint JSON)
  ├── createdAt: timestamp
  └── isPublic: boolean

community_points/{id}
  ├── ownerUid: string
  ├── ownerName: string
  ├── edsPoint: map (EdsPoint JSON)
  ├── upvotes: number
  ├── createdAt: timestamp
  ├── region: string               // "malatya", "elazig" vb.
  └── geoHash: string              // GeoHash kodu (konum bazlı sorgulama için)
```

> **GeoHash Açıklaması**: `community_points` koleksiyonunda her nokta için `geoHash` alanı eklenir. Sorgular `geoHash` prefix'ine göre yapılır (ör. belirli bir precision seviyesinde ~50 km çap). Bu sayede tüm noktalar yerine sadece kullanıcının yakınındaki noktalar okunur ve Firestore okuma maliyeti ~%99 düşer. `geoflutterfire_plus` veya manuel GeoHash encode kullanılabilir.

---

### Faz 1 — Kimlik Doğrulama (Auth)
> Kullanıcıların giriş yapabilmesi

- [x] Giriş/Kayıt ekranı oluştur (`lib/views/auth_view.dart`)
  - [x] E-posta/Şifre ile kayıt
  - [x] E-posta/Şifre ile giriş
  - [x] Google ile giriş
  - [ ] Şifremi unuttum akışı
- [x] Profil ekranı oluştur (`lib/views/profile_view.dart`)
  - [x] Kullanıcı adı, e-posta gösterimi
  - [x] Çıkış yap butonu
  - [x] Hesap silme
- [x] Auth state'e göre yönlendirme (giriş yapmamışsa → auth ekranı)
- [x] `main.dart`'ta Firebase başlatma (`Firebase.initializeApp()`)
- [x] Drawer menüsüne profil/giriş linki ekle
- [x] Firestore'da kullanıcı profili oluşturma (ilk giriş)

---

### Faz 2 — Abonelik Sistemi (RevenueCat + Riverpod)
> Pro üyelik satın alma ve reaktif yönetimi

- [x] RevenueCat hesabı ve proje oluştur
- [x] `purchases_flutter` paketini ekle
- [x] RevenueCat'te "pro" entitlement tanımla
- [x] `lib/services/subscription_service.dart` oluştur
  - [x] RevenueCat SDK başlatma (`Purchases.configure` + Firebase UID'yi `appUserID` olarak set et)
  - [x] Satın alma akışını başlatma (`Purchases.purchase`)
  - [x] Abonelik geri yükleme (`restorePurchases`)
  - [x] Abonelik yönetimi / URL yönlendirmesi (`url_launcher` ile)
- [x] `lib/providers/subscription_provider.dart` oluştur
  - [x] `StateNotifierProvider<CustomerInfoNotifier>` — RevenueCat listener'ını Riverpod'a bağla
  - [x] `isProProvider` — `CustomerInfo.entitlements.active["pro"]` kontrolü yapan türetilmiş provider
  - [x] Pro satın alındığı anda UI'daki tüm kilitler otomatik kalkar (stream reaktif)
- [x] Abonelik ekranı/sayfası (`lib/views/paywall_view.dart`)
  - [x] Free vs Pro karşılaştırma özellikleri
  - [x] Dinamik paket (Aylık/Yıllık) seçenekleri
  - [x] Satın al butonu
  - [x] Aboneliği geri yükleme
- [x] Google Play Console'da (Sandbox) ürün tanımlama
- [x] Pro-gated özellikler için `isProProvider` kontrolü (şimdilik sadece UI yönlendirmelerinde)
- [x] Drawer menüsüne "Pro'ya Yükselt" linki ekle (Free kullanıcılar için)
- [x] Profil sayfasına "Aboneliği Yönet / İptal Et" butonu ekle (Pro kullanıcılar için)
- [ ] **RevenueCat Webhook → Cloud Function** (Sonraki fazlarda veritabanı kilitleri için yapılacak):
  - [ ] Cloud Function: RevenueCat webhook'larını dinle
  - [ ] Webhook olaylarında (`RENEWAL`, `CANCELLATION`, `EXPIRATION` vb.) Firestore `users/{uid}/isPro` güncelle
  - [ ] Bu Firestore alanı **sadece** Firestore Security Rules ve Cloud Functions tarafından kullanılır (istemci asla okumaz)

---

### Faz 3 — Arkadaşlık Sistemi
> Kullanıcılar arası bağlantı kurma

- [x] `lib/services/friend_service.dart` oluştur
  - [x] Arkadaşlık isteği gönderme
  - [x] Arkadaşlık isteği kabul/reddetme
  - [x] Arkadaş listesini çekme (Firestore realtime)
  - [x] Arkadaş silme
  - [x] E-posta ile kullanıcı arama
- [x] `lib/providers/friends_provider.dart` oluştur
  - [x] `StreamProvider<List<Friendship>>` — arkadaş listesi realtime
  - [x] `StreamProvider<List<Friendship>>` — bekleyen istekler realtime
- [x] `lib/models/friendship.dart` modeli oluştur
- [x] Arkadaş listesi ekranı (`lib/views/friends_view.dart`)
  - [x] Arkadaş listesi
  - [x] Bekleyen istekler (gelen/giden)
  - [x] Arkadaş ekleme (arama) dialog'u
  - [x] Arkadaş silme (onaylı)
- [x] Pro kontrolü: `isProProvider` ile gate — Free kullanıcıya Pro'ya geçiş ekranı göster
- [x] Drawer menüsüne "Arkadaşlarım" linki ekle
- [ ] Cloud Function: Arkadaşlık isteği bildirimi (opsiyonel, FCM ile)

---

### Faz 4 — EDS Noktası Paylaşımı
> Arkadaşlara ve topluluk havuzuna EDS noktası gönderme

- [ ] `lib/services/sharing_service.dart` oluştur
  - [ ] Arkadaşa EDS noktası gönderme
  - [ ] Gelen paylaşımları listeleme (realtime stream)
  - [ ] Gelen EDS noktasını yerel listeye ekleme (import + geofence reload)
  - [ ] Topluluk havuzuna paylaşma (Pro — `isProProvider` ile gate)
  - [ ] Topluluk havuzundan okuma — **GeoHash + sayfalama** ile:
    - [ ] `geoflutterfire_plus` paketini ekle VEYA manuel GeoHash encode/decode
    - [ ] Kullanıcının mevcut konumundan GeoHash hesapla
    - [ ] GeoHash prefix sorgusu ile ~50 km çaptaki noktaları çek
    - [ ] Sayfalama: İlk 20 nokta yükle, "daha fazla" ile devam et
    - [ ] Bölge bazlı filtreleme (kullanıcı şehir seçebilir)
- [ ] `lib/providers/sharing_provider.dart` oluştur
  - [ ] `StreamProvider<List<SharedPoint>>` — gelen paylaşımlar realtime
  - [ ] `FutureProvider` — topluluk noktaları (sayfalı)
- [ ] `lib/models/shared_point.dart` modeli oluştur
- [ ] `saved_eds_view.dart` güncelle:
  - [ ] Her EDS noktası satırına "Paylaş" butonu ekle
  - [ ] Paylaşım hedefi seçim dialog'u (arkadaş seç / topluluğa paylaş)
- [ ] Gelen paylaşımlar ekranı (`lib/views/inbox_view.dart`)
  - [ ] Gelen EDS noktası listesi
  - [ ] "Kabul et" → yerel listeye ekle + geofence reload
  - [ ] "Reddet" → Firestore'dan sil
- [ ] Topluluk keşfet ekranı (`lib/views/community_view.dart`)
  - [ ] Konum bazlı filtreleme (GeoHash sorgusu)
  - [ ] Bölge/şehir seçimi dropdown
  - [ ] Oylama (upvote) sistemi
  - [ ] "Ekle" butonu → yerel listeye import
  - [ ] Sayfalama (infinite scroll veya "daha fazla" butonu)
- [ ] Pro kontrolü: Paylaşma ve alma sadece Pro; topluluk görüntüleme Free'ye açık
- [ ] Drawer menüsüne "Gelen Kutusu" ve "Topluluk" linkleri ekle

---

### Faz 5 — Bildirimler & Polishing
> Kullanıcı deneyimini tamamlama

- [ ] Firebase Cloud Messaging (FCM) entegrasyonu
  - [ ] Arkadaşlık isteği bildirimi
  - [ ] Yeni EDS noktası paylaşıldı bildirimi
- [ ] Uygulama içi bildirim badge'leri (gelen istek sayısı, yeni paylaşım)
- [ ] Offline desteği: Firestore cache + bağlantı yokken graceful fallback
- [ ] Hata durumları: Ağ yok, auth süresi dolmuş, abonelik doğrulama hatası
- [ ] Yükleme durumları (shimmer/skeleton)
- [ ] Tüm yeni ekranlar için Türkçe UI metinleri kontrolü

---

## Etkilenen Mevcut Dosyalar

| Dosya | Değişiklik |
|---|---|
| `pubspec.yaml` | Firebase, google_sign_in, purchases_flutter, flutter_riverpod, geoflutterfire_plus paketleri |
| `lib/main.dart` | `Firebase.initializeApp()`, `ProviderScope` sarmalama, auth state yönlendirme |
| `lib/views/dashboard_view.dart` | Drawer menüsüne yeni linkler, Pro badge, `ConsumerStatefulWidget`'a geçiş |
| `lib/views/saved_eds_view.dart` | Paylaş butonu, `isProProvider` ile Pro gate |
| `lib/services/eds_storage_service.dart` | Firestore sync opsiyonu (gelecekte) |
| `lib/theme/design_tokens.dart` | Yeni renkler/stiller (Pro badge, auth ekranları) |
| `android/app/build.gradle` | Google Services plugin |
| `android/app/src/main/AndroidManifest.xml` | Internet permission (mevcut), FCM meta-data |

---

## Yeni Dosyalar (Tahmini)

### Models
- `lib/models/user_profile.dart`
- `lib/models/friendship.dart`
- `lib/models/shared_point.dart`

### Services
- `lib/services/auth_service.dart`
- `lib/services/subscription_service.dart`
- `lib/services/friend_service.dart`
- `lib/services/sharing_service.dart`

### Providers (Riverpod)
- `lib/providers/auth_provider.dart`
- `lib/providers/subscription_provider.dart` (`isProProvider` dahil)
- `lib/providers/user_profile_provider.dart`
- `lib/providers/friends_provider.dart`
- `lib/providers/sharing_provider.dart`

### Views
- `lib/views/auth_view.dart`
- `lib/views/profile_view.dart`
- `lib/views/subscription_view.dart`
- `lib/views/friends_view.dart`
- `lib/views/inbox_view.dart`
- `lib/views/community_view.dart`

### Widgets
- `lib/widgets/pro_badge.dart`
- `lib/widgets/friend_card.dart`
- `lib/widgets/shared_point_card.dart`
- `lib/widgets/subscription_card.dart`

### Cloud Functions
- `functions/src/revenuecatWebhook.ts` — RevenueCat webhook → Firestore `isPro` güncelleme

---

## Riskler & Dikkat Noktaları

- **⚠️ isPro Tuzağı**: İstemci tarafında Pro kontrolü için **asla** Firestore `users/{uid}/isPro` okunmaz. Her zaman `ref.watch(isProProvider)` kullan (RevenueCat `CustomerInfo.entitlements.active["pro"]` üzerinden). Firestore'daki `isPro` sadece Cloud Functions ve Firestore Security Rules tarafından kullanılır.
- **⚠️ Firestore Okuma Maliyeti**: `community_points` koleksiyonu **asla** `.get()` ile tamamı çekilmez. GeoHash prefix sorgusu + `limit()` ile sayfalanmalıdır. Aksi takdirde Free kullanıcı büyüme stratejisi maliyet felaketine dönüşür.
- **Firestore güvenlik kuralları kritik**: Kullanıcılar sadece kendi verilerine yazabilmeli, arkadaş durumunu manipüle edememeli. Cloud Functions ile server-side doğrulama şart.
- **RevenueCat + Firebase Auth entegrasyonu**: `Purchases.logIn(firebaseUid)` ile RevenueCat'e Firebase UID'yi bağla. Giriş yapıldığında çağrılmalı, çıkışta `Purchases.logOut()`.
- **Mevcut katman yapısı korunmalı**: Widgets → Services arası doğrudan import yok, Views orchestrate eder.
- **Mevcut singleton'lar korunur**: `AudioService`, `EdsStorageService`, `EdsGeofenceService` singletonları değişmez. Riverpod yalnızca yeni ağ-bağımlı katman için kullanılır.
- **EdsPoint modeli değişmeyecek**: Paylaşım Firestore'da `toJson()` formatını kullanacak, model yapısı aynı kalacak.
- **Offline-first felsefe**: Mevcut uygulama tamamen offline çalışıyor. Yeni özellikler ağ gerektirse de, mevcut GPS/EDS takip özelliği ağ olmadan çalışmaya devam etmeli.
- **Reaktif UI**: Pro satın alındığında, arkadaşlık isteği geldiğinde veya EDS noktası paylaşıldığında, uygulama kapatılıp açılmadan UI anında güncellenmelidir. Bu Riverpod stream provider'ları ile sağlanır.
