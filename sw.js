/* Offline support: the app shell is cached, and the page itself is fetched fresh when online
   so updates show up right away. Account requests (Supabase) are never cached. */
const CACHE = 'samaa-v4';
const SHELL = ['./', 'index.html', 'config.js', 'manifest.webmanifest', 'icons/icon-192.png', 'icons/icon-512.png', 'vendor/supabase.js', 'vendor/fonts.css', 'privacy.html', 'terms.html'];

self.addEventListener('install', e => {
  e.waitUntil(caches.open(CACHE).then(c => c.addAll(SHELL)).then(() => self.skipWaiting()));
});

self.addEventListener('activate', e => {
  e.waitUntil(caches.keys()
    .then(keys => Promise.all(keys.filter(k => k !== CACHE).map(k => caches.delete(k))))
    .then(() => self.clients.claim()));
});

self.addEventListener('fetch', e => {
  const req = e.request;
  if (req.method !== 'GET') return;
  const url = new URL(req.url);
  const sameOrigin = url.origin === self.location.origin;
  if (!sameOrigin) return;

  if (req.mode === 'navigate' || url.pathname.endsWith('.html') || url.pathname.endsWith('config.js')){
    // network first, so a new version is picked up immediately
    e.respondWith(fetch(req).then(res => {
      const copy = res.clone(); caches.open(CACHE).then(c => c.put(req, copy));
      return res;
    }).catch(() => caches.match(req).then(r => r || caches.match('index.html'))));
    return;
  }
  // everything else: cache first, then network
  e.respondWith(caches.match(req).then(hit => hit || fetch(req).then(res => {
    if (res.ok || res.type === 'opaque'){ const copy = res.clone(); caches.open(CACHE).then(c => c.put(req, copy)); }
    return res;
  })));
});
