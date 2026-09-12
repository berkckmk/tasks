import type { ContentPlatform } from './content-item';

export type ContentTemplate = {
  id: string;
  title: string;
  description: string;
  platform: ContentPlatform;
  defaultPlatforms: ContentPlatform[];
  suggestedTag: string;
};

export const contentTemplates: Record<ContentPlatform, ContentTemplate[]> = {
  Instagram: [
    {
      id: 'ig-carousel-guide',
      title: '3 Adımda Sorun Çözme Carouseli',
      description: 'Kaydedilme oranını artıran adım adım eğitici rehber formatı.',
      platform: 'Instagram',
      defaultPlatforms: ['Instagram'],
      suggestedTag: 'Carousel',
    },
    {
      id: 'ig-reels-hook',
      title: 'Reels: "Bunu Biliyor Muydun?" Kancası',
      description: 'İlk 3 saniye kancası + hızlı çözüm + yoruma yönlendiren CTA.',
      platform: 'Instagram',
      defaultPlatforms: ['Instagram', 'TikTok'],
      suggestedTag: 'Reels',
    },
    {
      id: 'ig-story-qa',
      title: 'Story Soru & Cevap Günü',
      description: 'Takipçi etkileşimini ve profil ziyaretini artıran interaktif soru formatı.',
      platform: 'Instagram',
      defaultPlatforms: ['Instagram'],
      suggestedTag: 'Story',
    },
    {
      id: 'ig-behind-scenes',
      title: 'Kamera Arkası & Haftalık İlerleme',
      description: 'Süreç ve yapım aşamasını gösteren samimi topluluk içeriği.',
      platform: 'Instagram',
      defaultPlatforms: ['Instagram'],
      suggestedTag: 'Post',
    },
  ],
  X: [
    {
      id: 'x-thread-breakdown',
      title: '1/8 Değer Odaklı Bilgi Dizisi (Thread)',
      description: 'Dikkat çekici kanca tweet + 6 pratik madde + kaynak ve RT CTA.',
      platform: 'X',
      defaultPlatforms: ['X'],
      suggestedTag: 'Thread',
    },
    {
      id: 'x-unpopular-opinion',
      title: 'Sektörel Karşıt Görüş (Unpopular Opinion)',
      description: 'Tartışma ve alıntı tweet (Quote) etkileşimi başlatan cesur perspektif.',
      platform: 'X',
      defaultPlatforms: ['X'],
      suggestedTag: 'Tweet',
    },
    {
      id: 'x-weekly-learnings',
      title: 'Bu Hafta Öğrendiğim 3 Önemli Şey',
      description: 'Kısa, net ve uygulanabilir deneyim paylaşımı listesi.',
      platform: 'X',
      defaultPlatforms: ['X'],
      suggestedTag: 'Liste',
    },
    {
      id: 'x-curated-tools',
      title: 'İşinizi Kolaylaştıracak 5 Araç',
      description: 'Yer imlerine kaydettiren faydalı araç ve kaynak derlemesi.',
      platform: 'X',
      defaultPlatforms: ['X'],
      suggestedTag: 'Kaynak',
    },
  ],
  TikTok: [
    {
      id: 'tt-mistake-vs-solution',
      title: 'En Çok Yapılan 3 Hata vs Doğrusu',
      description: 'Dinamik kurgulu ve hızlı tempolu problem-çözüm videosu.',
      platform: 'TikTok',
      defaultPlatforms: ['TikTok', 'Instagram'],
      suggestedTag: 'Trend',
    },
    {
      id: 'tt-day-in-life',
      title: 'Benimle Bir Gün / Çalışma Rutinim',
      description: 'Samimi vlog, çalışma ortamı ve arkadaki gerçek süreç.',
      platform: 'TikTok',
      defaultPlatforms: ['TikTok'],
      suggestedTag: 'Vlog',
    },
    {
      id: 'tt-30s-hack',
      title: '30 Saniyede Pratik İpucu & Taktik',
      description: 'Giriş uzatmadan direkt sonuca ulaştıran dikey video kurgusu.',
      platform: 'TikTok',
      defaultPlatforms: ['TikTok', 'YouTube'],
      suggestedTag: 'Taktik',
    },
    {
      id: 'tt-reply-comment',
      title: 'Takipçi Yorumuna Yanıt Videosu',
      description: 'Gelen soruyu ekrana sabitleyip yanıtlayan otorite oluşturucu video.',
      platform: 'TikTok',
      defaultPlatforms: ['TikTok'],
      suggestedTag: 'Soru-Cevap',
    },
  ],
  Facebook: [
    {
      id: 'fb-community-discussion',
      title: 'Grup & Topluluk Tartışma Gönderisi',
      description: 'Yorumlarda uzun deneyim paylaşımlarını tetikleyen soru metni.',
      platform: 'Facebook',
      defaultPlatforms: ['Facebook'],
      suggestedTag: 'Topluluk',
    },
    {
      id: 'fb-in-depth-case-study',
      title: 'Detaylı Vaka Analizi & Başarı Hikayesi',
      description: 'Görsellerle desteklenen öncesi/sonrası ve başarı adımları.',
      platform: 'Facebook',
      defaultPlatforms: ['Facebook'],
      suggestedTag: 'Vaka',
    },
    {
      id: 'fb-event-announcement',
      title: 'Etkinlik / Canlı Yayın Duyurusu',
      description: 'Tarih, saat ve katılma nedenlerini net özetleyen duyuru formatı.',
      platform: 'Facebook',
      defaultPlatforms: ['Facebook'],
      suggestedTag: 'Etkinlik',
    },
    {
      id: 'fb-article-summary',
      title: 'Haftalık Makale & Rehber Özeti',
      description: 'Bağlantı ve özet içeren uzun form paylaşım.',
      platform: 'Facebook',
      defaultPlatforms: ['Facebook'],
      suggestedTag: 'Makale',
    },
  ],
  YouTube: [
    {
      id: 'yt-step-by-step-tutorial',
      title: 'Kapsamlı A\'dan Z\'ye Eğitim Videosu',
      description: 'Giriş, bölümler (timestamps), ekran kaydı ve sonuç bölümü içeren video.',
      platform: 'YouTube',
      defaultPlatforms: ['YouTube'],
      suggestedTag: 'Uzun Video',
    },
    {
      id: 'yt-shorts-viral',
      title: 'YouTube Shorts: 60 Saniyede Çözüm',
      description: 'Hızlı kanca, altyazılı görsel anlatım ve abone olma çağrısı.',
      platform: 'YouTube',
      defaultPlatforms: ['YouTube', 'TikTok', 'Instagram'],
      suggestedTag: 'Shorts',
    },
    {
      id: 'yt-top5-comparison',
      title: 'Top 5 Karşılaştırma & Tavsiye',
      description: 'Artılar/eksiler tablosu ve kişisel deneyim içeren inceleme videosu.',
      platform: 'YouTube',
      defaultPlatforms: ['YouTube'],
      suggestedTag: 'İnceleme',
    },
    {
      id: 'yt-live-stream',
      title: 'Canlı Yayın & Soru-Cevap Oturumu',
      description: 'Toplulukla canlı etkileşim, sohbet soruları ve canlı gösterim.',
      platform: 'YouTube',
      defaultPlatforms: ['YouTube'],
      suggestedTag: 'Canlı',
    },
  ],
  Other: [
    {
      id: 'other-newsletter',
      title: 'Haftalık E-Bülten / Newsletter Sayısı',
      description: 'Öne çıkan gelişmeler, derinlemesine bir fikir ve özel öneriler.',
      platform: 'Other',
      defaultPlatforms: ['Other'],
      suggestedTag: 'Bülten',
    },
    {
      id: 'other-blog-deep-dive',
      title: 'Blog: SEO Odaklı Derinlemesine Rehber',
      description: 'H1-H3 başlık hiyerarşisi, anahtar kelimeler ve uygulanabilir adımlar.',
      platform: 'Other',
      defaultPlatforms: ['Other'],
      suggestedTag: 'Blog',
    },
    {
      id: 'other-podcast-episode',
      title: 'Podcast Bölümü: Konuklu Söyleşi Planı',
      description: 'Bölüm teması, soru akışı, açılış-kapanış notları ve alıntılar.',
      platform: 'Other',
      defaultPlatforms: ['Other'],
      suggestedTag: 'Podcast',
    },
    {
      id: 'other-launch-announcement',
      title: 'Yeni Ürün / Özellik Lansman Duyurusu',
      description: 'Tüm kanallara uyarlanabilen çoklu lansman duyurusu ve CTA metni.',
      platform: 'Other',
      defaultPlatforms: ['Other', 'Instagram', 'X'],
      suggestedTag: 'Lansman',
    },
  ],
};
