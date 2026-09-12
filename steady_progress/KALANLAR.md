# Steady Progress geçişinde kalan işler

Son güncelleme: 9 Eylül 2026

Bu liste production geçişi tamamlanana kadar tek takip kaynağıdır. Tamamlanan işler listeden çıkarılır; kanıtlar `docs/PROGRESS.md` içinde tutulur.

## 1. Firebase ve oturum — High

- [ ] Firebase'de `com.steadyprogress.steady_progress.preview` Android uygulamasını ve preview imzasını tanımla.
- [ ] Preview `google-services.json` dosyasını al.
- [ ] Preview iOS bundle kimliğini Firebase'de tanımla ve `GoogleService-Info.plist` dosyasını al.
- [ ] React Native Firebase App, Auth, Firestore, Functions, Messaging ve Storage modüllerini elle yönetilen native projelere ekle; Prebuild çalıştırma.
- [ ] `DataGateway` için gerçek React Native Firebase uygulamasını yaz.
- [ ] Firebase Emulator Suite üzerinde test hesabı, Firestore rules ve callable akışlarını doğrula.
- [ ] Giriş, çıkış, kayıt ve e-posta doğrulama ekranlarını taşı.
- [ ] Mevcut Android Firebase Auth oturumunun uygulama güncellemesinden sonra korunmasını doğrula.

## 2. Backend — High

- [ ] `migration-patches/functions-widget-idempotency-and-important-channel.patch` yamasını backend kaynak ağacına uygula.
- [ ] Tekrarlanan `clientMutationId` çağrılarının yalnızca bir Task/Habit oluşturduğunu Emulator Suite'te doğrula.
- [ ] Eski Flutter çağrılarının `clientMutationId` olmadan çalışmaya devam ettiğini doğrula.
- [ ] `createTask`, `createHabit` ve `sendDueReminders` function'larını dağıt.
- [ ] Önemli FCM mesajlarının `channel_important_alarm_v1` ile gönderildiğini doğrula.

## 3. Tasks özellik eşliği — High

- [ ] Google Calendar senkronizasyonunu bağla.

## 4. Habits özellik eşliği — High

- [ ] Google Calendar senkronizasyonunu bağla.

## 5. Reminders özellik eşliği — High

- [ ] Gerçek Firebase Messaging bağlandıktan sonra FCM token kaydını etkinleştir.

## 6. Learning, Content ve Workout canlı veri kabulü — Medium

- [ ] Gerçek Firebase gateway bağlandıktan sonra oluşturma, tür, durum, puan, filtre, düzenleme ve silmeyi Emulator Suite'te doğrula.
- [ ] Content Planner oluşturma, platform, durum, yayın tarihi, düzenleme ve silme akışını Emulator Suite'te doğrula.
- [ ] Complete plan Content Planner erişim kuralını subscription katmanı taşındığında bağla.
- [ ] Workout oluşturma, tarih, egzersiz satırları ve ilişkili silme akışını gerçek Firebase gateway ile Emulator Suite'te doğrula.
- [ ] Complete plan Workout Tracker erişim kuralını subscription katmanı taşındığında bağla.

## 7. Henüz taşınmayan modüller

- [x] Avatar seçme ve Firebase Storage yükleme — İstemci katmanı tamamlandı (`avatar-storage.ts`, `ProfileScreen`).
- [x] Google Calendar, Drive, Docs ve Sheets entegrasyonları — İstemci katmanı tamamlandı (`google-integrations-repository.ts`, `GoogleIntegrationsScreen`).
- [x] Gerçek subscription belgesi, plan entitlement ve satın alma sonrası yenileme — İstemci katmanı tamamlandı (`subscription-status.ts`, `subscription-repository.ts`, `plans.ts`).
- [ ] Play Billing ve Stripe checkout — High (Mağaza ve ödeme entegrasyonu).
- [x] Onboarding, splash ve production tab/navigation yapısı — Tamamlandı (5-tab parity: Reminders(0), Today(1), Habits(2), Tasks(3), More(4); cold start -> Reminders; Onboarding slide'ları, ikonlar, dot pagination).

## 8. Widget'ın canlı uygulamaya bağlanması — High

- [ ] Backend dağıtımından sonra kimliği doğrulanmış oturumda yaşam döngüsü drain'ini etkinleştir.
- [ ] Hesap değişimi ve çıkışta kuyruk sahipliği politikasını uygula.
- [ ] Cold/warm widget rotalarını gerçek editörlerle doğrula.
- [ ] Production güncellemesinde mevcut widget örneklerinin ve ayarlarının korunduğunu doğrula.

## 9. Bildirim kabulü — High

- [ ] S25 sessiz modda önemli reminder'ın varsayılan bildirim tonunu alarm ses akışından çaldığını doğrula.
- [ ] Aynı koşulda normal reminder'ın telefonun sessiz davranışını izlediğini doğrula.
- [ ] Exact alarm özel erişimini ve Samsung pil optimizasyonu davranışını doğrula.
- [ ] Yerel alarm ile FCM'nin çift bildirim üretmediğini doğrula.
- [ ] iOS APNs yapılandırmasını tamamla.
- [ ] Apple kritik bildirim entitlement veya AlarmKit kararını ver ve uygula.
- [ ] Gerçek iPhone'da sessiz mod kabulünü yap.

## 10. Genel UI ve erişilebilirlik — Medium

- [x] Taşınan bütün ekranları ortak tema ve `src/components/ui` bileşenlerine geçir (`audit-design-system.mjs` hatasız geçiyor).
- [x] Ham textbox, label, buton, kart, modal ve yinelenen Add kontrollerini kaldır.
- [x] Liste sayfalarının bilgi sırasını ortak standarda getir.
- [x] Çoklu seçim (multi-selection) ve toplu silme modu: Habits, Tasks, Reminders ekranlarına eklendi.
- [x] Paylaşılan sheet bileşenleri (`detail-sheet-components.tsx`) Flutter ile eşlendi.
- [ ] Modal/dialogların hiçbir cihazda kamera veya durum çubuğu alanına çıkmadığını doğrula.
- [ ] S25'te Learning title, Habits klavye konumu, büyük yazı ve yatay ekran kabulünü yap.
- [ ] iPhone Dynamic Island, küçük ekran, büyük yazı ve VoiceOver kabulini yap.

## 11. Production güncellemesi ve yayın — High

- [ ] Preview ve production build yapılarını ayır.
- [ ] Production application ID, bundle ID ve imzalama yapılandırmasını bağla.
- [ ] Android uygulamasını kaldırmadan eşleşen imzayla güncelle.
- [ ] Güncellemeden sonra oturum, Firestore verileri, yerel tercihler ve widget yerleşimlerini doğrula.
- [ ] Android ve iOS regresyon matrisini tamamla.
- [ ] Tam Xcode ortamında iOS native build ve archive üret.
- [ ] Production APK/AAB ve iOS archive üret.
- [ ] Son kullanıcı kabulünden sonra mağaza yayın sürecini tamamla.
