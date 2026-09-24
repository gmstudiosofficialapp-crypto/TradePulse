'use strict';
const MANIFEST = 'flutter-app-manifest';
const TEMP = 'flutter-temp-cache';
const CACHE_NAME = 'flutter-app-cache';

const RESOURCES = {"assets/AssetManifest.bin": "ad038e446f97fb0e8e6ff06590759777",
"assets/AssetManifest.bin.json": "e0669245d3af5b196aa7e5976878d468",
"assets/assets/icons/crypto/btc.png": "8f8d12b8691a706a99e7544bd33527c2",
"assets/assets/icons/crypto/doge.png": "1938a5ea7cbe7458795a834563258ced",
"assets/assets/icons/crypto/eth.png": "174b0414fece541456d82f84a296e380",
"assets/assets/icons/crypto/sol.png": "0bf2916a9c679e99dc9060ee1cc2dde5",
"assets/assets/icons/crypto/usdc.png": "7dfa6cbc7537f528327e421ff3527656",
"assets/assets/icons/crypto/usdt.png": "1209268b2a9b376e08bdcfb12b98aaf9",
"assets/assets/icons/crypto/xrp.png": "2308acc5cb079e77004f6ae91cc7b051",
"assets/assets/icons/flags/au.png": "f9b1378ebc3d7497c9124be2ce9d141a",
"assets/assets/icons/flags/ca.png": "cc00eb304b28c4fb9b0f8a22e88d79c3",
"assets/assets/icons/flags/ch.png": "fa62de254012b0e0d930f952d91d4218",
"assets/assets/icons/flags/eu.png": "3802f77675bb6b4d935ba45d86051a0e",
"assets/assets/icons/flags/gb.png": "74d947e76be53ddb5003b0ddfcd8089f",
"assets/assets/icons/flags/jp.png": "d1ed74a8462d06dd171b8a707e393b74",
"assets/assets/icons/flags/us.png": "0534161a3d82678bd6153188af83ecf1",
"assets/assets/icons/SOURCES.txt": "560879fee0a14072cdadbf5f6b07c6db",
"assets/FontManifest.json": "dc3d03800ccca4601324923c0b1d6d57",
"assets/fonts/MaterialIcons-Regular.otf": "44eadd7940467d5e607fac3aabd55cb0",
"assets/NOTICES": "9e33160734421fc75c8367b8fadba77f",
"assets/packages/cupertino_icons/assets/CupertinoIcons.ttf": "33b7d9392238c04c131b6ce224e13711",
"assets/shaders/ink_sparkle.frag": "ecc85a2e95f5e9f53123dcaf8cb9b6ce",
"assets/shaders/stretch_effect.frag": "40d68efbbf360632f614c731219e95f0",
"canvaskit/canvaskit.js": "8331fe38e66b3a898c4f37648aaf7ee2",
"canvaskit/canvaskit.js.symbols": "a3c9f77715b642d0437d9c275caba91e",
"canvaskit/canvaskit.wasm": "9b6a7830bf26959b200594729d73538e",
"canvaskit/chromium/canvaskit.js": "a80c765aaa8af8645c9fb1aae53f9abf",
"canvaskit/chromium/canvaskit.js.symbols": "e2d09f0e434bc118bf67dae526737d07",
"canvaskit/chromium/canvaskit.wasm": "a726e3f75a84fcdf495a15817c63a35d",
"canvaskit/skwasm.js": "8060d46e9a4901ca9991edd3a26be4f0",
"canvaskit/skwasm.js.symbols": "3a4aadf4e8141f284bd524976b1d6bdc",
"canvaskit/skwasm.wasm": "7e5f3afdd3b0747a1fd4517cea239898",
"canvaskit/skwasm_heavy.js": "740d43a6b8240ef9e23eed8c48840da4",
"canvaskit/skwasm_heavy.js.symbols": "0755b4fb399918388d71b59ad390b055",
"canvaskit/skwasm_heavy.wasm": "b0be7910760d205ea4e011458df6ee01",
"favicon.ico": "6cffec790fde414e21343f03822b491e",
"favicon.png": "d9eaff586dbd73d0c82f5113f83a3965",
"flutter.js": "24bc71911b75b5f8135c949e27a2984e",
"flutter_bootstrap.js": "5d5f0ac540fe28fb5f773bd7de6341c3",
"icons/apple-touch-icon.png": "fee7b26d4f94f6f6a5f2801cff0f008a",
"icons/favicon-16.png": "236370e89cb28e5b2e0ae77e66334769",
"icons/favicon-32.png": "d9eaff586dbd73d0c82f5113f83a3965",
"icons/favicon-48.png": "55a4a87c68364ed4afc073b6581af64a",
"icons/Icon-192.png": "0e5478bbd102363f8c1f1959b26ccd1c",
"icons/Icon-512.png": "9b767cbb8f2d3e117ad28892cf172e3a",
"icons/Icon-maskable-192.png": "83b8e05711f60136a2e299d29a68f26f",
"icons/Icon-maskable-512.png": "06f1f2dba632a1cd908d0fef9918e3c7",
"index.html": "d6378e8d0bff42ef7076a73290b4a7a7",
"/": "d6378e8d0bff42ef7076a73290b4a7a7",
"main.dart.js": "5b22565a48fd4a856a0a0c2c5c8b8bb0",
"manifest.json": "b999d17ec09a69b82410ef79f214f3b6",
"robots.txt": "c9f371230be5d646351acdb151a1e044",
"sitemap.xml": "1a484dea7719dc0444a083a7ccd508d4",
"version.json": "07c113b00282aa105433b6817b087dc3"};
// The application shell files that are downloaded before a service worker can
// start.
const CORE = ["main.dart.js",
"index.html",
"flutter_bootstrap.js",
"assets/AssetManifest.bin.json",
"assets/FontManifest.json"];

// During install, the TEMP cache is populated with the application shell files.
self.addEventListener("install", (event) => {
  self.skipWaiting();
  return event.waitUntil(
    caches.open(TEMP).then((cache) => {
      return cache.addAll(
        CORE.map((value) => new Request(value, {'cache': 'reload'})));
    })
  );
});
// During activate, the cache is populated with the temp files downloaded in
// install. If this service worker is upgrading from one with a saved
// MANIFEST, then use this to retain unchanged resource files.
self.addEventListener("activate", function(event) {
  return event.waitUntil(async function() {
    try {
      var contentCache = await caches.open(CACHE_NAME);
      var tempCache = await caches.open(TEMP);
      var manifestCache = await caches.open(MANIFEST);
      var manifest = await manifestCache.match('manifest');
      // When there is no prior manifest, clear the entire cache.
      if (!manifest) {
        await caches.delete(CACHE_NAME);
        contentCache = await caches.open(CACHE_NAME);
        for (var request of await tempCache.keys()) {
          var response = await tempCache.match(request);
          await contentCache.put(request, response);
        }
        await caches.delete(TEMP);
        // Save the manifest to make future upgrades efficient.
        await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
        // Claim client to enable caching on first launch
        self.clients.claim();
        return;
      }
      var oldManifest = await manifest.json();
      var origin = self.location.origin;
      for (var request of await contentCache.keys()) {
        var key = request.url.substring(origin.length + 1);
        if (key == "") {
          key = "/";
        }
        // If a resource from the old manifest is not in the new cache, or if
        // the MD5 sum has changed, delete it. Otherwise the resource is left
        // in the cache and can be reused by the new service worker.
        if (!RESOURCES[key] || RESOURCES[key] != oldManifest[key]) {
          await contentCache.delete(request);
        }
      }
      // Populate the cache with the app shell TEMP files, potentially overwriting
      // cache files preserved above.
      for (var request of await tempCache.keys()) {
        var response = await tempCache.match(request);
        await contentCache.put(request, response);
      }
      await caches.delete(TEMP);
      // Save the manifest to make future upgrades efficient.
      await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
      // Claim client to enable caching on first launch
      self.clients.claim();
      return;
    } catch (err) {
      // On an unhandled exception the state of the cache cannot be guaranteed.
      console.error('Failed to upgrade service worker: ' + err);
      await caches.delete(CACHE_NAME);
      await caches.delete(TEMP);
      await caches.delete(MANIFEST);
    }
  }());
});
// The fetch handler redirects requests for RESOURCE files to the service
// worker cache.
self.addEventListener("fetch", (event) => {
  if (event.request.method !== 'GET') {
    return;
  }
  var origin = self.location.origin;
  var key = event.request.url.substring(origin.length + 1);
  // Redirect URLs to the index.html
  if (key.indexOf('?v=') != -1) {
    key = key.split('?v=')[0];
  }
  if (event.request.url == origin || event.request.url.startsWith(origin + '/#') || key == '') {
    key = '/';
  }
  // If the URL is not the RESOURCE list then return to signal that the
  // browser should take over.
  if (!RESOURCES[key]) {
    return;
  }
  // If the URL is the index.html, perform an online-first request.
  if (key == '/') {
    return onlineFirst(event);
  }
  event.respondWith(caches.open(CACHE_NAME)
    .then((cache) =>  {
      return cache.match(event.request).then((response) => {
        // Either respond with the cached resource, or perform a fetch and
        // lazily populate the cache only if the resource was successfully fetched.
        return response || fetch(event.request).then((response) => {
          if (response && Boolean(response.ok)) {
            cache.put(event.request, response.clone());
          }
          return response;
        });
      })
    })
  );
});
self.addEventListener('message', (event) => {
  // SkipWaiting can be used to immediately activate a waiting service worker.
  // This will also require a page refresh triggered by the main worker.
  if (event.data === 'skipWaiting') {
    self.skipWaiting();
    return;
  }
  if (event.data === 'downloadOffline') {
    downloadOffline();
    return;
  }
});
// Download offline will check the RESOURCES for all files not in the cache
// and populate them.
async function downloadOffline() {
  var resources = [];
  var contentCache = await caches.open(CACHE_NAME);
  var currentContent = {};
  for (var request of await contentCache.keys()) {
    var key = request.url.substring(origin.length + 1);
    if (key == "") {
      key = "/";
    }
    currentContent[key] = true;
  }
  for (var resourceKey of Object.keys(RESOURCES)) {
    if (!currentContent[resourceKey]) {
      resources.push(resourceKey);
    }
  }
  return contentCache.addAll(resources);
}
// Attempt to download the resource online before falling back to
// the offline cache.
function onlineFirst(event) {
  return event.respondWith(
    fetch(event.request).then((response) => {
      return caches.open(CACHE_NAME).then((cache) => {
        cache.put(event.request, response.clone());
        return response;
      });
    }).catch((error) => {
      return caches.open(CACHE_NAME).then((cache) => {
        return cache.match(event.request).then((response) => {
          if (response != null) {
            return response;
          }
          throw error;
        });
      });
    })
  );
}
