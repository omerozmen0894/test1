# Wrap Maze - Store Hazirlik Notlari

## App Store

- Uygulama adi: Wrap Maze
- Bundle ID: `com.wrapmaze.game`
- Firebase iOS app olusturuldu: `1:105292792236:ios:9d36b9c6400ec50de83a09`
- `ios/Runner/GoogleService-Info.plist` projeye eklendi.
- `lib/firebase_options.dart` iOS icin guncellendi.
- iOS build son adimi macOS + Xcode gerektirir.
- App Store Connect metinleri: `store_release/ios/APP_STORE_CONNECT_TR.md`
- iOS kaynak paketi: `store_release/ios/wrap-maze-ios-source.zip`

## Xcode ile yukleme

1. Mac uzerinde bu kaynak paketini ac.
2. Terminalde proje klasorunde `flutter pub get` calistir.
3. `ios/Runner.xcworkspace` dosyasini Xcode ile ac.
4. Runner target icinde Team olarak Apple Developer hesabini sec.
5. Signing otomatik degilse `com.wrapmaze.game` icin App Store provisioning profile sec.
6. Product > Archive ile archive al.
7. Organizer icinde Distribute App > App Store Connect > Upload sec.
8. Build App Store Connect'te islendikten sonra surume ekle ve review'a gonder.

## App Store Connect'te doldurulacaklar

- Gizlilik politikasi URL'si
- Destek URL'si
- Ekran goruntuleri
- App Privacy formu
- Yas derecelendirme anketi
- Fiyat/ulke secimi
- Reklam ve satin alma kullanimina gore ek beyanlar

## Google Play

- Paket adi: `com.wrapmaze.game`
- Play Console icin AAB: `store_release/android/wrap-maze-playstore.aab`
- Firebase Android app ve `google-services.json` paket adi ile uyumlu olmalidir.
- Android release imzasi `android/key.properties` ile ayarlanir.

## Yayin oncesi kalite listesi

- Gercek uygulama ikonu ve splash ekran son kontrol
- En az 6 ekran goruntusu
- Gizlilik politikasi ve destek sayfasi yayinda
- Firebase rules production icin yayinda
- Login, sifre sifirlama, e-posta degistirme, leaderboard testleri
- Bolum ilerleme ve sonsuz mod testleri
- Reklam aktif edilecekse gercek AdMob app id ve App Privacy guncellemesi
