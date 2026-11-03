const VERSION='holyher-shell-walk-v1';
const ARTWORK='holyher-artwork-v1';
self.addEventListener('message',event=>{if(event.data==='HOLYHER_UPDATE')self.skipWaiting();});
// Account data, OAuth helpers and backend calls are never cached here.
self.addEventListener('install',event=>event.waitUntil(caches.open(VERSION).then(cache=>cache.addAll(['/app/','/app/storage.js','/app/flutter_bootstrap.js']))));
self.addEventListener('activate',event=>event.waitUntil(caches.keys().then(keys=>Promise.all(keys.filter(k=>k.startsWith('holyher-shell-')&&k!==VERSION).map(k=>caches.delete(k)))).then(()=>self.clients.claim())));
self.addEventListener('fetch',event=>{
 const url=new URL(event.request.url);
 if(event.request.method!=='GET'||url.origin!==self.location.origin||(!url.pathname.startsWith('/app/')&&!url.pathname.startsWith('/artwork/v1/'))||url.pathname.includes('/__/auth'))return;
 const asset=/\.(?:js|wasm|json|ttf|otf|png|webp|jpg|svg)$/.test(url.pathname);
 if(event.request.mode==='navigate'){
  event.respondWith(fetch(event.request).catch(()=>caches.match('/app/')));return;
 }
 if(asset)event.respondWith(caches.open(url.pathname.startsWith('/artwork/')?ARTWORK:VERSION).then(async cache=>{
  const cached=await cache.match(event.request);
  if(cached)return cached;
  const response=await fetch(event.request);
  if(response.ok)await cache.put(event.request,response.clone());return response;
 }));
});
