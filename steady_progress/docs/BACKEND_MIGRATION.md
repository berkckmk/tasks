# Backend geçiş paketi

`migration-patches/functions-widget-idempotency-and-important-channel.patch`, mevcut Flutter istemcileriyle uyumlu iki sunucu değişikliği taşır:

- `createTask` ve `createHabit`, isteğe bağlı `clientMutationId` kabul eder. Alan yoksa eski rastgele belge kimliği akışı aynen sürer. Alan varsa kullanıcı koleksiyonunda kararlı bir belge kimliği kullanılır ve aynı widget işleminin tekrar gönderilmesi ikinci kayıt oluşturmaz.
- Önemli reminder push mesajları Android'deki sürümlü `channel_important_alarm_v1` kanalına gönderilir. Kanal yerel uygulamada sistemin varsayılan bildirim sesini `USAGE_ALARM` ile açar.

## Güvenli uygulama sırası

1. Yamayı üretim kaynak ağacına uygula ve Functions TypeScript derlemesini çalıştır.
2. Önce `createTask`, `createHabit` ve `sendDueReminders` function'larını dağıt.
3. Dağıtım tamamlandıktan sonra React Native istemcisinde gerçek Firebase bağlantısını ve widget kuyruk boşaltmayı etkinleştir.
4. S25'te çevrimdışı/yeniden deneme senaryosunda tek kayıt oluştuğunu doğrula.
5. S25 sessizdeyken önemli bir reminder'ı ve normal bir reminder'ı ayrı ayrı doğrula. Önemli olan sistemin varsayılan bildirim sesiyle çalmalı; normal olan telefonun sessiz davranışını izlemeli.

Eski `channel_important` değiştirilmez. Android notification channel özellikleri oluşturulduktan sonra değiştirilemediği için yeni kanal kimliği zorunludur. Eski Flutter sürümü `clientMutationId` göndermediğinden callable değişikliği geriye uyumludur.

## Yerel doğrulama

Orijinal proje prototip sırasında salt okunur tutulur. Yama şu iki komutla ayrı bir çalışma kopyasında doğrulanmalıdır:

```sh
git apply --check /path/to/functions-widget-idempotency-and-important-channel.patch
npm --prefix functions run build
```

Bu paket bir dağıtım işlemi değildir. Production dağıtımı ve FCM gönderimi gerçek backend ortamında ayrı kabul adımıdır.
