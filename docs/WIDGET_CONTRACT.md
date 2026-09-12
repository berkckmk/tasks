# Android widget bağlantı sözleşmesi — v1

Kaynak: Flutter `HomeWidgetService`, `HomeWidgetSync`, `home_widget_providers.dart`; Kotlin `MainActivity`, `WidgetDataStore`, `WidgetPendingAdds`, `WidgetPendingToggles`.

## Değişmeyecek sınır

Widget Kotlin/XML/RemoteViews ile çizilmeye devam eder. Ana uygulama React Native olabilir; widget ana uygulamanın UI ağacına taşınmaz. Orijinal widget sınıf ve kaynak isimleri korunur. Android `namespace` eski paketle aynı kalır; yalnızca prototipin `applicationId` değeri `.preview` ile ayrılır.

| Eski MethodChannel işlemi | Yeni yerel modül işlemi | Anlam |
|---|---|---|
| `updateWidget` | `updateWidget(snapshot)` | Snapshot sakla, yerleştirilmiş widget'ları yenile |
| `clearWidget` | `clearWidget()` | Veri + iki işlem kuyruğunu temizle, ayarları koru |
| `readPendingToggles` | `readPendingToggles()` | JSON metni olarak bekleyen tamamlamaları getir |
| `readPendingAdds` | `readPendingAdds()` | JSON metni olarak hızlı eklemeleri getir |
| `clearPendingToggles` | `clearPendingToggles(ids)` | Eski kimlik bazlı temizleme; üretim kullanımı eşzamanlılık incelemesine bağlı |
| `clearPendingAdds` | `clearPendingAdds(ids)` | Onaylanan eklemeleri ve geçici satırları temizle |

Prototip ayrıca salt okunur `readSnapshot` ve widget yönlendirmesi için `takePendingRoute` işlemlerini sunar. Veri okuma çağrılarındaki bir native hata boş/başarılı sonuç gibi gösterilmez.

## Snapshot

```json
{
  "habitsDone": 1,
  "habitsTotal": 2,
  "tasksDone": 0,
  "tasksTotal": 2,
  "bestStreak": 7,
  "items": "{\"habits\":[],\"tasks\":[],\"reminders\":[]}"
}
```

Her satır: `{id, kind, label, done?, time?}`. `kind`: `habit | task | reminder`. Eksik `done` false; eksik `time` boş metin. `items` Kotlin'in beklediği gibi JSON metnidir. Sayaçlar tamsayıdır.

Flutter snapshot seçicisi üç koleksiyon yüklenmeden gönderim yapmaz. Her listede en fazla 12 satır gönderir. Bugünün ve tamamlanmamış gecikmiş hatırlatıcılarını dahil eder; gelecek günün hatırlatıcısını dahil etmez. Görev ve alışkanlık listeleri mevcut provider kapsamından gelir. Saatler istemcide formatlanır; sıralama tamamlanma ve saat metnine göre yapılır. Bu davranışlar yeni seçici yazılırken testlerle korunacaktır.

## İşlem kuyrukları

- Tamamlama: `{id, kind, done, at}`; `at` Unix milisaniye.
- Ekleme: `{id, kind, label, startAt, endAt, allDay, at}`; `id` yerel `add:` kimliğidir.
- `startAt/endAt = 0` tarih yok anlamına gelir; eski kayıtlar için `allDay = true`.
- Eklemede alanlar yeniden yorumlanmaz: reminder tarih+saat, task tarih aralığı/isteğe bağlı saat, habit isteğe bağlı saat davranışı korunur.
- Kuyruk okuma onay değildir. Preview host halen kuyrukları silmez veya buluta yazmaz.
- Üretim coordinator'ı kimliği doğrulanmış kullanıcı olmadan çalışmaz, eklemeleri toggle'lardan önce uygular ve yalnızca başarılı işlemleri `id + kind + at` ile onaylar.
- Reminder eklemeleri kararlı belge kimliği kullanır. Task/Habit eklemeleri `PendingAdd.id` değerini callable function'a `clientMutationId` olarak taşır. Bu alanı tekilleştiren backend yaması production'a dağıtılmadan gerçek kuyruk drain'i etkinleştirilmeyecektir.

## Kalıcı depolar ve Android bileşenleri

- `steady_progress_widget`: sayaçlar, `hasData`, `items`.
- `steady_progress_widget_config`: widget kimliğine bağlı kapsam/görünüm ayarları.
- `steady_progress_widget_pending`: tamamlama `queue`.
- `steady_progress_widget_pending_adds`: ekleme `queue`.
- Widget sınıfları `com.steadyprogress.steady_progress.widget` paketinde kalır.
- `SteadyProgressWidgetProvider`, `WidgetItemsService`, `WidgetToggleWorker`, ayar/kapsam/hızlı ekleme activity'leri korunur.
- `steady_progress_route`: `/reminders`, `/reminders/<id>/edit`, `/tasks/<id>/edit`, `/habits/<id>/edit`.

Yeni uygulama köprüsü kayıt hedefini alır; prototip bu hedefi açıkça bir doğrulama ekranında gösterir. Gerçek düzenleyiciler daha sonraki ekran taşıma aşamasında bağlanır. Cold start ve `onNewIntent` ayrı kontrol edilir.

## Kabul

Kaynak bütünlüğü kontrolü + sözleşme testleri + Android derleme yalnızca teknik ön koşullardır. Gerçek S25 görsel/işlev testi ve mevcut uygulama üzerinde güncelleme testi geçmeden geçiş kabul edilmiş sayılmaz.
