/* eslint-disable no-undef */
/**
 * Firebase Cloud Messaging background service worker.
 *
 * This file MUST live at the web root (public/) so the browser
 * registers it with the broadest scope (/).
 *
 * It uses the Firebase compat SDK loaded via importScripts because
 * ES modules are not yet universally supported inside service workers.
 */

importScripts('https://www.gstatic.com/firebasejs/11.8.1/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/11.8.1/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyBRQymwI2gg0iiVvP86MNQGWV0HT5rZQvY',
  authDomain: 'tasks-1903.firebaseapp.com',
  projectId: 'tasks-1903',
  storageBucket: 'tasks-1903.firebasestorage.app',
  messagingSenderId: '1012303591315',
  appId: '1:1012303591315:web:4ca9c811a0b6d3465c5a66',
});

const messaging = firebase.messaging();

self.addEventListener('install', () => {
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  event.waitUntil(self.clients.claim());
});

/**
 * Handle background push messages (when the page is not focused / app is closed).
 * Firebase displays the notification automatically when a `notification` payload
 * is present. For `data`-only messages we build one manually below.
 */
messaging.onBackgroundMessage((payload) => {
  console.log('[firebase-messaging-sw] Background message received:', payload);

  // If the push already has a notification payload Firebase shows it automatically.
  if (payload.notification) return;

  // Data-only payloads: build a visible notification ourselves.
  const data = payload.data || {};
  const title = data.title || 'Steady Progress';
  const body = data.body || data.message || 'Yeni bir bildiriminiz var.';
  const tag = data.type ? `sp-${data.type}-${data.reminderId || data.habitId || ''}` : 'sp-generic';

  self.registration.showNotification(title, {
    body,
    icon: '/app-icon.png',
    badge: '/app-icon.png',
    tag,
    data,
  });
});

/**
 * When the user clicks a notification shown by this service worker,
 * focus the existing tab or open a new one.
 */
self.addEventListener('notificationclick', (event) => {
  event.notification.close();

  const data = event.notification.data || {};
  let targetUrl = '/';
  if (data.type === 'reminder') targetUrl = '/main/reminders';
  else if (data.type === 'habit') targetUrl = '/main/habits';
  else if (data.type === 'digest') targetUrl = '/main/tasks';

  event.waitUntil(
    self.clients
      .matchAll({ type: 'window', includeUncontrolled: true })
      .then((clientList) => {
        for (const client of clientList) {
          if (client.url && 'focus' in client) {
            client.navigate(targetUrl);
            return client.focus();
          }
        }
        if (self.clients.openWindow) {
          return self.clients.openWindow(targetUrl);
        }
      }),
  );
});
