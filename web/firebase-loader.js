// Public SDK modules only. No account data is included here.
try {
  window.firebase_core = await import('./vendor/firebase/13.1.0/firebase-app.js');
  const [auth, firestore, functions] = await Promise.all([
    import('./vendor/firebase/13.1.0/firebase-auth.js'),
    import('./vendor/firebase/13.1.0/firebase-firestore-pipelines.js'),
    import('./vendor/firebase/13.1.0/firebase-functions.js')
  ]);
  window.firebase_auth = auth;
  window.firebase_firestore = firestore;
  window.firebase_functions = functions;
  const bootstrap = document.createElement('script');
  bootstrap.src = '/app/flutter_bootstrap.js';
  bootstrap.onerror = () => window.dispatchEvent(new Event('error'));
  document.body.append(bootstrap);
} catch (_) {
  window.dispatchEvent(new Event('error'));
}
