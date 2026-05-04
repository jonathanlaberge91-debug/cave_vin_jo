// This service worker immediately unregisters itself and clears all caches
self.addEventListener('install', function() { self.skipWaiting(); });
self.addEventListener('activate', function(e) {
  e.waitUntil(
    caches.keys().then(function(names) {
      return Promise.all(names.map(function(n) { return caches.delete(n); }));
    }).then(function() { return self.clients.claim(); })
    .then(function() { return self.registration.unregister(); })
  );
});
