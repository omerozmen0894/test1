# 🌀 Wrap Maze v3 — Tam Özellikli

> Tek elle oynanabilen labirent bulmaca oyunu — Tüm özellikler dahil

---

## ✨ Özellikler

| Kategori | Özellik | Durum |
|----------|---------|-------|
| Oyun | Wilson algoritması ile sonsuz level | ✅ |
| Oyun | Hint sistemi (DFS çözücü) | ✅ |
| Oyun | Ses efektleri (flame_audio) | ✅ |
| Oyun | Haptic feedback | ✅ |
| Oyun | Süre takibi | ✅ |
| Günlük | Günlük bölüm (tarih bazlı seed) | ✅ |
| Streak | Streak takibi + takvim görünümü | ✅ |
| Streak | 6 rozet (3, 7, 14, 30 gün + hafta/ay rekoru) | ✅ |
| Streak | Rozet kazanma bildirimi | ✅ |
| Çok Oyunculu | Oda oluşturma + 6 haneli kod | ✅ |
| Çok Oyunculu | Realtime ilerleme (Firebase RTDB) | ✅ |
| Çok Oyunculu | 3 saniyelik geri sayım | ✅ |
| Çok Oyunculu | Offline persistence (bağlantı kesilince) | ✅ |
| Editör | Grid boyutu seçimi (4–8) | ✅ |
| Editör | Duvar / Başlangıç / Bitiş araçları | ✅ |
| Editör | Çözülebilirlik doğrulaması | ✅ |
| Editör | Firebase'de yayınlama | ✅ |
| Editör | Yerel kayıt (Isar) | ✅ |
| Sıralama | Firebase global leaderboard | ✅ |
| Sıralama | Offline yerel sıralama (internet gerektirmez) | ✅ |
| Sıralama | Günlük sıralama | ✅ |
| IAP | Reklamları Kaldır (₺29,99) | ✅ |
| IAP | Premium Temalar (₺19,99) | ✅ |
| IAP | Premium Bundle (₺39,99) | ✅ |
| IAP | 5 İpucu Hakkı (₺9,99) | ✅ |
| IAP | 20 İpucu Hakkı (₺29,99) | ✅ |
| IAP | Satın Alım Geri Yükleme | ✅ |
| Tema | 6 tema (2 ücretsiz, 4 premium) | ✅ |
| Reklam | AdMob Interstitial (her 5 level) | ✅ |
| Reklam | AdMob Banner | ✅ |
| Reklam | AdMob Rewarded (hint için) | ✅ |
| Play Games | 6 başarım | ✅ |
| Play Games | 2 sıralama tablosu | ✅ |

---

## 📁 Proje Yapısı

```
lib/
├── main.dart
├── core/
│   ├── models/
│   │   ├── maze_model.dart           # Cell, MazeConfig, GameState
│   │   ├── theme_model.dart          # 6 tema
│   │   ├── streak_model.dart         # StreakData, BadgeInfo, Badge
│   │   └── multiplayer_model.dart    # Room, PlayerData
│   ├── maze_generator.dart           # Wilson + MazeSolver
│   ├── database/
│   │   └── progress_model.dart       # 6 Isar koleksiyonu
│   ├── providers/
│   │   ├── isar_provider.dart
│   │   └── settings_provider.dart
│   └── services/
│       ├── iap_service.dart          # In-app purchase
│       ├── offline_leaderboard_service.dart
│       ├── streak_service.dart
│       └── multiplayer_service.dart  # Firebase RTDB
└── features/
    ├── home/home_screen.dart          # 6 hızlı buton + premium banner
    ├── game/{game_screen, game_provider, maze_painter, gesture_handler}.dart
    ├── daily/daily_screen.dart
    ├── streak/streak_screen.dart      # Takvim + rozet grid
    ├── editor/editor_screen.dart      # Labirent editörü
    ├── multiplayer/multiplayer_screen.dart  # Lobi + oyun
    ├── leaderboard/{leaderboard_screen, offline_leaderboard_screen}.dart
    ├── iap/iap_screen.dart
    └── settings/settings_screen.dart
```

---

## 🚀 Kurulum

### 1. Bağımlılıklar
```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
```

### 2. Firebase
```bash
# FlutterFire CLI ile otomatik kurulum
dart pub global activate flutterfire_cli
flutterfire configure
```

Firestore, Realtime Database ve Auth'u etkinleştirin.

**Firestore kuralları:**
```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /leaderboard/{uid} {
      allow read;
      allow write: if request.auth != null && request.auth.uid == uid;
    }
    match /custom_levels/{docId} {
      allow read;
      allow create: if request.auth != null;
      allow update: if request.auth != null && request.auth.uid == resource.data.uid;
    }
  }
}
```

**Realtime Database kuralları:**
```json
{
  "rules": {
    "rooms": {
      "$roomCode": {
        ".read": "auth != null",
        ".write": "auth != null"
      }
    }
  }
}
```

### 3. Google Play Console

**In-App Products (Ürünler > Uygulama İçi Ürünler):**

| Ürün ID | Tip | Fiyat |
|---------|-----|-------|
| `wrap_maze_remove_ads` | Yönetilen Ürün | ₺29,99 |
| `wrap_maze_premium_themes` | Yönetilen Ürün | ₺19,99 |
| `wrap_maze_premium_bundle` | Yönetilen Ürün | ₺39,99 |
| `wrap_maze_hints_5` | Tüketilebilir | ₺9,99 |
| `wrap_maze_hints_20` | Tüketilebilir | ₺29,99 |

**Başarımlar:**
- İlk Kazanış, 10. Bölüm, 50. Bölüm, İpuçsuz Bitir, Hız Rekordu, 7 Günlük Seri

### 4. AdMob
`AndroidManifest.xml` içindeki test ID'yi gerçek App ID ile değiştirin:
```xml
<meta-data
    android:name="com.google.android.gms.ads.APPLICATION_ID"
    android:value="ca-app-pub-XXXX~YYYY"/>
```

### 5. Ses Dosyaları
`assets/audio/` klasörüne koyun:
- `move.mp3`, `win.mp3`, `undo.mp3`, `hint.mp3`, `tick.mp3`

Ücretsiz kaynak: https://freesound.org

---

## 📱 Play Store Build

```bash
flutter build appbundle --release
```

---

## 🎮 Yeni Özellik Detayları

### Streak Sistemi
- Her günlük bölüm tamamlandığında otomatik kaydedilir
- `StreakData.addToday()` ardışık günleri hesaplar
- 6 rozet: 3, 7, 14, 30 günlük seri + hafta/ay rekoru
- Takvim görünümü: son 28 gün renkli gösterilir

### Çok Oyunculu
- Firebase Realtime Database üzerinde çalışır
- Oda kodu: 6 haneli alfanümerik (`AB3X7Z`)
- Maksimum 4 oyuncu
- Gerçek zamanlı ilerleme çubuğu
- Offline persistence: bağlantı kesilince lokal devam

### Level Editörü
- 4×4 ile 8×8 arası grid
- Duvar, başlangıç, bitiş araçları
- BFS ile çözülebilirlik doğrulaması
- Firebase'e yayınlama + Isar'a yerel kayıt

### Yerel Sıralama
- Internet bağlantısı gerektirmez
- Isar veritabanında saklanır
- Aynı cihazdaki farklı kullanıcı adlarını destekler

### In-App Purchase
- `in_app_purchase` paketi (Google Play Billing v6)
- Tüketilebilir (hint hakkı) + yönetilen (kalıcı) ürünler
- Satın alım geri yükleme desteği
