import fs from 'node:fs';
import path from 'node:path';

const indexPath = path.resolve('dist/index.html');

if (fs.existsSync(indexPath)) {
  let html = fs.readFileSync(indexPath, 'utf-8');

  const pwaTags = `
    <title>Steady Progress</title>
    <meta name="description" content="Kişisel gelişim, görevler, alışkanlıklar ve hatırlatıcılar" />
    <link rel="manifest" href="/manifest.json" />
    <link rel="apple-touch-icon" href="/app-icon.png" />
    <meta name="theme-color" content="#1A1918" />
    <meta name="apple-mobile-web-app-capable" content="yes" />
    <meta name="apple-mobile-web-app-status-bar-style" content="black-translucent" />
    <meta name="apple-mobile-web-app-title" content="Steady Progress" />
`;

  if (!html.includes('manifest.json')) {
    html = html.replace('</head>', `${pwaTags}</head>`);
    fs.writeFileSync(indexPath, html, 'utf-8');
    console.log('Injected PWA and macOS Dock manifest tags into dist/index.html');
  }
}
