self.addEventListener("install", () => {
  self.skipWaiting();
});

self.addEventListener("activate", (event) => {
  event.waitUntil(
    Promise.all([
      self.registration.unregister(),
      caches
        .keys()
        .then((keys) =>
          Promise.all(
            keys
              .filter((key) => /flutter|bubble|planner/i.test(key))
              .map((key) => caches.delete(key)),
          ),
        ),
      self.clients.claim(),
    ]),
  );
});
