# Veri ve oturum geçişi

## Seçilen istemci

Android ve iOS için hedef Firebase istemcisi React Native Firebase'in modüler API'sidir. Yerel Firebase SDK'larını kullandığı için Firestore çevrimdışı davranışı, FCM, Crashlytics ve mevcut Android Firebase Auth oturumunu koruma deneyi için uygun seçenektir. Web uygulaması bu mobil geçişin parçası değildir.

Paketler, preview kimliğine ait Firebase yapılandırması olmadan eklenmeyecek. Mevcut `google-services.json` yalnızca `com.steadyprogress.steady_progress` paketini içeriyor; preview paketine bağlamak Google oturumunu doğru şekilde yapılandırmaz ve sentetik prototipi üretim verisine açar. iOS için mevcut projede Firebase yapılandırması bulunmuyor.

Üretim bağlantısından önce gerekenler:

1. Firebase projesinde `com.steadyprogress.steady_progress.preview` Android istemcisi ve preview imzası için ayrı yapılandırma oluştur.
2. iOS preview bundle kimliği için Firebase uygulaması ve `GoogleService-Info.plist` oluştur.
3. React Native Firebase App, Auth, Firestore, Functions, Messaging ve Storage modüllerini elle yönetilen native projelere ekle; Prebuild çalıştırma.
4. Emulator Suite üzerinde yalnızca test kullanıcılarıyla callable ve Firestore akışlarını doğrula.
5. Üretim kimliğine geçiş paketinde eski Android Firebase Auth oturumunun yerel SDK tarafından okunup okunmadığını gerçek güncelleme testiyle ölç.

## Taşınan veri sözleşmeleri

`src/features` altında Tasks, Habits, Reminders ve Learning belge ayrıştırıcıları Flutter varsayımlarıyla eşleştirildi.

- Eski task belgesinde `allDay` yoksa `true`.
- Task priority/status bozuksa `medium`/`todo`.
- Habit seri hesabı bugün boşsa dünden devam eder; tamamlanmamış log sayılmaz.
- Habit log kimliği ve tarih metni `habitId_yyyy-MM-dd` sözleşmesini korur.
- İlaç anahtar sözcüğü taşıyan normal reminder `important` olur; açıkça `low` seçildiyse korunur.
- Learning rating 0–5 aralığına alınır; eski takeaway listesi güvenli metne çevrilir.

## Widget işlem sırası

`WidgetSyncCoordinator` yalnızca doğrulanmış kullanıcı kimliğiyle çalışır ve aynı anda tek drain yürütür.

1. Ekleme kuyruğunun tamamı katı biçimde ayrıştırılır.
2. Hızlı eklemeler `PendingAdd.id` idempotency anahtarıyla gerçek kayda çevrilir.
3. Geçici `add:<millis>` satırına yapılmış toggle yeni sunucu kimliğine uygulanır.
4. Yalnızca başarılı işlemler `id + kind + at` üçlüsüyle yerel kuyruktan çıkarılır.
5. Ağ veya yetki hatası alan işlem sonraki uygulama dönüşünde yeniden denenir.

Cloud Functions tarafındaki geriye uyumlu değişiklik `migration-patches/functions-widget-idempotency-and-important-channel.patch` içinde hazırdır. Yama `createTask` ve `createHabit` için isteğe bağlı `clientMutationId` kabul eder ve aynı kullanıcı/işlem için aynı gerçek belgeyi döndürür. Ayrı backend kopyasında uygulanıp TypeScript derlemesinden geçirilmiştir; üretim drain'i açılmadan önce dağıtılmalıdır.

## Koleksiyonlar

Ana yollar değişmez: `users/{uid}/tasks`, `habits`, `habit_logs`, `reminders`, `learning_items` ve diğer modül koleksiyonları. Task ve Habit oluşturma doğrudan Firestore'a yazılmaz; sırasıyla `createTask` ve `createHabit` callable işlevlerinden geçer. Düzenleme, tamamlama ve silme mevcut güvenlik kuralı sözleşmesine göre yapılır.
