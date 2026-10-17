const CACHE_NAME = "blaban-shell-v20";
const CACHE_PREFIX = "blaban-shell-";
const BASE_URL = new URL("./", self.registration.scope);
const APP_SHELL = [
  BASE_URL.href,
  new URL("manifest.webmanifest", BASE_URL).href,
  new URL("icons/blaban-icon.svg", BASE_URL).href
];
const HOME_PATH = new URL("./", BASE_URL).pathname;

self.addEventListener("install", (event) => {
  event.waitUntil(caches.open(CACHE_NAME).then(cache => cache.addAll(APP_SHELL)).then(() => self.skipWaiting()));
});
self.addEventListener("activate", (event) => {
  event.waitUntil(caches.keys().then(keys => Promise.all(keys.filter(key => key.startsWith(CACHE_PREFIX) && key !== CACHE_NAME).map(key => caches.delete(key)))).then(() => self.clients.claim()));
});
self.addEventListener("fetch", (event) => {
  const request = event.request;
  const url = new URL(request.url);
  if (request.method !== "GET" || url.origin !== self.location.origin) return;
  if (url.pathname === "/admin.html" || url.pathname.endsWith("/admin.html") || url.pathname.includes("/rest/") || url.pathname.includes("/auth/")) return;
  if (request.mode === "navigate") {
    if (url.pathname !== HOME_PATH) return;
    event.respondWith(fetch(request).then(response => {
      if (response.ok) caches.open(CACHE_NAME).then(cache => cache.put(BASE_URL.href, response.clone()));
      return response;
    }).catch(async () => {
      const cached = await caches.match(BASE_URL.href);
      return cached || new Response("أنتِ غير متصلة بالإنترنت حاليًا. أعيدي الاتصال وحاولي مرة أخرى.", {status:503,headers:{"Content-Type":"text/plain; charset=utf-8"}});
    }));
    return;
  }
  if (APP_SHELL.includes(url.href)) event.respondWith(caches.match(request).then(cached => cached || fetch(request)));
});
