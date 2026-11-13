const VERSION='holyhim-shell-v2';
const ART='holyhim-art-v2';
self.addEventListener('message',event=>{if(event.data==='HOLYHIM_UPDATE')self.skipWaiting();});
// Only the public shell and art. Firestore owns account persistence and its queue.
self.addEventListener('install',event=>event.waitUntil(caches.open(VERSION).then(cache=>cache.addAll(['/app/','/app/flutter_bootstrap.js']))));
self.addEventListener('activate',event=>event.waitUntil(caches.keys().then(keys=>Promise.all(keys.filter(k=>/^holyhim-(shell|artwork|art)-/.test(k)&&k!==VERSION&&k!==ART).map(k=>caches.delete(k)))).then(()=>self.clients.claim())));
self.addEventListener('fetch',event=>{
 const url=new URL(event.request.url);
 if(event.request.method!=='GET'||url.origin!==self.location.origin||(!url.pathname.startsWith('/app/')&&!url.pathname.startsWith('/art/v2/'))||url.pathname.includes('/__/auth'))return;
 if(event.request.mode==='navigate'){event.respondWith(fetch(event.request).catch(()=>caches.match('/app/')));return;}
 if(/\.(?:js|wasm|json|ttf|otf|png|webp|jpg|svg)$/.test(url.pathname))event.respondWith(caches.open(url.pathname.startsWith('/art/')?ART:VERSION).then(async cache=>{
  const cached=await cache.match(event.request);if(cached)return cached;
  const response=await fetch(event.request);if(response.ok)await cache.put(event.request,response.clone());return response;
 }));
});
