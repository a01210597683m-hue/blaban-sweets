const CACHE_NAME = "blaban-shell-v3";
const CACHE_PREFIX = "blaban-shell-";
const APP_SHELL = ["/", "/manifest.webmanifest", "/icons/blaban-icon.svg", "/icons/blaban-icon-192.png", "/icons/blaban-icon-512.png"];

self.addEventListener("install", (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME)
      .then((cache) => cache.addAll(APP_SHELL))
      .then(() => self.skipWaiting())
  );
});

self.addEventListener("activate", (event) => {
  event.waitUntil(
    caches.keys()
      .then((keys) => Promise.all(keys.filter((key) => key.startsWith(CACHE_PREFIX) && key !== CACHE_NAME).map((key) => caches.delete(key))))
      .then(() => self.clients.claim())
  );
});

self.addEventListener("fetch", (event) => {
  const request = event.request;
  const url = new URL(request.url);

  if (request.method !== "GET" || url.origin !== self.location.origin) return;
  if (url.pathname === "/admin.html" || url.pathname.startsWith("/rest/") || url.pathname.startsWith("/auth/")) return;

  if (request.mode === "navigate") {
    if (url.pathname !== "/") return;
    event.respondWith(
      fetch(request).then((response) => {
        if (response.ok && url.pathname !== "/admin.html") {
          const copy = response.clone();
          caches.open(CACHE_NAME).then((cache) => cache.put("/", copy));
        }
        return response;
      }).catch(async () => {
        const cached = await caches.match("/");
        if (cached) return cached;
        return new Response("أنتِ غير متصلة بالإنترنت حاليًا. أعيدي الاتصال وحاولي مرة أخرى.", {
          status: 503,
          headers: { "Content-Type": "text/plain; charset=utf-8" }
        });
      })
    );
    return;
  }

  if (APP_SHELL.includes(url.pathname)) {
    event.respondWith(
      caches.match(request).then((cached) => cached || fetch(request))
    );
  }
});