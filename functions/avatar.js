'use strict';
function createAvatarCleanup({deleteObject}) {
  return async ({uid, before, after}) => {
    if (typeof before !== 'string' || !before || before === after) return;
    let path;
    try {
      const url = new URL(before);
      if (url.protocol !== 'https:' || url.hostname !== 'firebasestorage.googleapis.com') return;
      path = decodeURIComponent(url.pathname.split('/o/')[1] || '');
    } catch (_) { return; }
    const prefix = `users/${uid}/avatars/`;
    if (!path.startsWith(prefix) || !/^[0-9]+\.jpg$/.test(path.slice(prefix.length))) return;
    await deleteObject(path);
  };
}
module.exports = {createAvatarCleanup};
