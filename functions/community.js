'use strict';
// The brothers: every post, reply, edit, delete and report passes through
// here, so the moderation the app shows is the moderation that holds.
const {patterns} = require('./moderation.json');

const BLOCKED = patterns.map(p => new RegExp(p, 'i'));
const LINK = /(https?:\/\/|www\.|\.(com|net|org|io|co|ly|gg)\b)/i;
const KINDS = ['word', 'prayer', 'win'];
const REASONS = ['spam', 'harassment', 'hate', 'sexual', 'violence', 'false', 'other'];
const METALS = ['brass', 'silver', 'bronze', 'steel', 'pine'];
const HIDE_AT = 3;

/** Folds look-alike characters so "sh1t" reads as what it is. */
function fold(text) {
  return text.toLowerCase().replace(/0/g, 'o').replace(/1/g, 'i').replace(/3/g, 'e')
    .replace(/4/g, 'a').replace(/5/g, 's').replace(/@/g, 'a').replace(/\$/g, 's');
}

/** A short reason the text cannot be posted, or null when it can. */
function textProblem(text, max = 600) {
  if (typeof text !== 'string') return 'Write a little more first.';
  const t = text.trim();
  if (t.length < 2) return 'Write a little more first.';
  if (t.length > max) return `Keep it under ${max} characters.`;
  const plain = fold(t);
  if (LINK.test(plain)) return 'Links are not allowed here.';
  if (BLOCKED.some(p => p.test(plain))) return 'Keep it clean, brother.';
  return null;
}

function createCommunity({db, HttpsError, FieldValue, now = Date.now}) {
  function requireIdentity(request) {
    if (!request.auth || typeof request.auth.uid !== 'string' || !request.auth.uid) {
      throw new HttpsError('unauthenticated', 'Please sign in.');
    }
    return request.auth.uid;
  }
  function id(value, what = 'post') {
    if (typeof value !== 'string' || !/^[A-Za-z0-9_-]{1,64}$/.test(value)) {
      throw new HttpsError('invalid-argument', `That ${what} could not be found.`);
    }
    return value;
  }
  function clean(text, max) {
    const problem = textProblem(text, max);
    if (problem) throw new HttpsError('invalid-argument', problem);
    return text.trim();
  }
  async function requireMember(uid) {
    const [member, ban, guard] = await Promise.all([
      db.doc(`members/${uid}`).get(), db.doc(`bans/${uid}`).get(), db.doc(`deletionGuards/${uid}`).get()]);
    if (guard.exists && guard.data()?.deleting) throw new HttpsError('permission-denied', 'This account is being deleted.');
    if (ban.exists) throw new HttpsError('permission-denied', 'This account can no longer post here.');
    if (!member.exists) throw new HttpsError('failed-precondition', 'Join the brothers first.');
    return member.data();
  }
  async function rate(uid, key, perHour, perDay) {
    const ref = db.doc(`communityRates/${uid}`);
    await db.runTransaction(async tx => {
      const doc = await tx.get(ref);
      const day = (doc.data()?.[key] || []).filter(t => t > now() - 86400000);
      if (day.filter(t => t > now() - 3600000).length >= perHour || day.length >= perDay) {
        throw new HttpsError('resource-exhausted', 'Easy, brother. Try again a little later.');
      }
      day.push(now());
      tx.set(ref, {[key]: day.slice(-perDay)}, {merge: true});
    });
  }
  function author(uid, m) {
    return {
      authorId: uid, authorName: m.name, authorMetal: METALS.includes(m.metal) ? m.metal : 'brass',
      authorPhoto: m.photo || '', authorMedal: m.medal || '', authorStreak: m.streak || 0,
    };
  }

  async function post(request) {
    const uid = requireIdentity(request);
    const member = await requireMember(uid);
    const data = request.data || {};
    const text = clean(data.text, 600);
    const kind = KINDS.includes(data.kind) ? data.kind : 'word';
    let verseRef = '', verseText = '';
    if (data.verseRef != null || data.verseText != null) {
      if (textProblem(data.verseRef, 60) || textProblem(data.verseText, 1200)) {
        throw new HttpsError('invalid-argument', 'That verse could not be attached.');
      }
      verseRef = data.verseRef.trim();
      verseText = data.verseText.trim();
    }
    await rate(uid, 'posts', 6, 20);
    const ref = db.collection('posts').doc();
    await ref.set({
      ...author(uid, member), text, kind, verseRef, verseText,
      amens: 0, amenBy: [], comments: 0, reports: 0, hidden: false, createdAt: FieldValue.serverTimestamp(),
    });
    return {id: ref.id};
  }

  async function edit(request) {
    const uid = requireIdentity(request);
    await requireMember(uid);
    const ref = db.doc(`posts/${id(request.data?.postId)}`);
    const text = clean(request.data?.text, 600);
    await db.runTransaction(async tx => {
      const doc = await tx.get(ref);
      if (!doc.exists) throw new HttpsError('not-found', 'This post is gone.');
      if (doc.data().authorId !== uid) throw new HttpsError('permission-denied', 'Only the author can edit this.');
      const created = doc.data().createdAt?.toMillis?.() ?? 0;
      if (now() - created > 86400000) throw new HttpsError('failed-precondition', 'Posts can be edited for a day.');
      tx.update(ref, {text, editedAt: FieldValue.serverTimestamp()});
    });
    return {edited: true};
  }

  async function comment(request) {
    const uid = requireIdentity(request);
    const member = await requireMember(uid);
    const postId = id(request.data?.postId);
    const text = clean(request.data?.text, 400);
    await rate(uid, 'comments', 30, 120);
    const postRef = db.doc(`posts/${postId}`);
    const ref = postRef.collection('comments').doc();
    await db.runTransaction(async tx => {
      const p = await tx.get(postRef);
      if (!p.exists || p.data().hidden) throw new HttpsError('not-found', 'This post is gone.');
      const {authorId, authorName, authorMetal, authorPhoto} = author(uid, member);
      tx.set(ref, {
        authorId, authorName, authorMetal, authorPhoto, text,
        amens: 0, amenBy: [], reports: 0, hidden: false, createdAt: FieldValue.serverTimestamp(),
      });
      tx.update(postRef, {comments: FieldValue.increment(1)});
      tx.set(db.doc(`users/${uid}/commentRefs/${ref.id}`), {postId});
    });
    return {id: ref.id};
  }

  async function remove(request) {
    const uid = requireIdentity(request);
    const postRef = db.doc(`posts/${id(request.data?.postId)}`);
    const commentId = request.data?.commentId == null ? null : id(request.data.commentId, 'reply');
    const post = await postRef.get();
    if (!post.exists) return {deleted: true};
    if (commentId) {
      const ref = postRef.collection('comments').doc(commentId);
      await db.runTransaction(async tx => {
        const c = await tx.get(ref);
        if (!c.exists) return;
        if (c.data().authorId !== uid && post.data().authorId !== uid) {
          throw new HttpsError('permission-denied', 'You can only delete your own replies.');
        }
        tx.delete(ref);
        tx.update(postRef, {comments: FieldValue.increment(-1)});
        tx.delete(db.doc(`users/${c.data().authorId}/commentRefs/${commentId}`));
      });
      return {deleted: true};
    }
    if (post.data().authorId !== uid) throw new HttpsError('permission-denied', 'You can only delete your own posts.');
    await db.recursiveDelete(postRef);
    return {deleted: true};
  }

  async function report(request) {
    const uid = requireIdentity(request);
    const postId = id(request.data?.postId);
    const commentId = request.data?.commentId == null ? null : id(request.data.commentId, 'reply');
    const reason = request.data?.reason;
    if (!REASONS.includes(reason)) throw new HttpsError('invalid-argument', 'Choose a reason.');
    await rate(uid, 'reports', 20, 60);
    const target = commentId ? db.doc(`posts/${postId}/comments/${commentId}`) : db.doc(`posts/${postId}`);
    const reportRef = db.doc(`reports/${commentId || postId}_${uid}`);
    await db.runTransaction(async tx => {
      const [t, r] = await Promise.all([tx.get(target), tx.get(reportRef)]);
      if (!t.exists) throw new HttpsError('not-found', 'That is already gone.');
      if (r.exists) return;
      const reports = (t.data().reports || 0) + 1;
      tx.set(reportRef, {
        reporter: uid, postId, commentId, authorId: t.data().authorId, authorName: t.data().authorName,
        reason, text: t.data().text, status: 'open', createdAt: FieldValue.serverTimestamp(),
      });
      tx.update(target, reports >= HIDE_AT ? {reports, hidden: true} : {reports});
    });
    return {reported: true};
  }

  /** Removes everything a brother put into the community. */
  async function purge(uid) {
    await db.doc(`members/${uid}`).delete();
    const posts = await db.collection('posts').where('authorId', '==', uid).get();
    for (const p of posts.docs) await db.recursiveDelete(p.ref);
    const refs = await db.collection(`users/${uid}/commentRefs`).get();
    for (const r of refs.docs) {
      const postRef = db.doc(`posts/${r.data().postId}`);
      const cRef = postRef.collection('comments').doc(r.id);
      await db.runTransaction(async tx => {
        const [c, p] = await Promise.all([tx.get(cRef), tx.get(postRef)]);
        if (c.exists) {
          tx.delete(cRef);
          if (p.exists) tx.update(postRef, {comments: FieldValue.increment(-1)});
        }
        tx.delete(r.ref);
      });
    }
    const amened = await db.collection('posts').where('amenBy', 'array-contains', uid).get();
    for (const p of amened.docs) {
      await p.ref.update({amenBy: FieldValue.arrayRemove(uid), amens: FieldValue.increment(-1)});
    }
    await db.doc(`communityRates/${uid}`).delete();
  }

  async function leave(request) {
    const uid = requireIdentity(request);
    await purge(uid);
    return {left: true};
  }

  /** A name that breaks the rules becomes "Brother" until he changes it. */
  async function moderateMember(event) {
    const after = event.data?.after;
    const data = after?.data();
    if (!data || !textProblem(data.name, 24)) return;
    await after.ref.update({name: 'Brother'});
  }

  return {post, edit, comment, remove, report, leave, purge, moderateMember};
}

module.exports = {createCommunity, textProblem, fold};
