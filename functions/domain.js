'use strict';
const TOTAL_DAYS = 365;
function validTimeZone(value) {
  if (typeof value !== 'string' || value.length > 100) return false;
  try { new Intl.DateTimeFormat('en-CA', {timeZone:value}).format(); return true; } catch { return false; }
}
function dateKey(now, timeZone) {
  if (!validTimeZone(timeZone)) throw new Error('Invalid time zone');
  const parts = Object.fromEntries(new Intl.DateTimeFormat('en-CA', {timeZone, year:'numeric',month:'2-digit',day:'2-digit'}).formatToParts(now).map(x=>[x.type,x.value]));
  return `${parts.year}-${parts.month}-${parts.day}`;
}
function ordinal(key) {
  if (typeof key !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(key)) throw new Error('Invalid date');
  const ms=Date.parse(`${key}T00:00:00Z`);
  if (!Number.isFinite(ms) || new Date(ms).toISOString().slice(0,10)!==key) throw new Error('Invalid date');
  return ms / 86400000;
}
function unlockedThrough(startDate, today) { return Math.max(1, Math.min(TOTAL_DAYS, ordinal(today)-ordinal(startDate)+1)); }
function mergeCompletion(journey, day, today) {
  if (!Number.isInteger(day) || day<1 || day>unlockedThrough(journey.startDate,today)) throw new Error('Lesson is not available yet');
  return [...new Set([...(journey.completedDays||[]).filter(x=>Number.isInteger(x)&&x>=1&&x<=TOTAL_DAYS),day])].sort((a,b)=>a-b);
}
function mergeActivityDays(journey, previous, requested, today) {
  if (!Array.isArray(requested) || requested.length > 366) {
    throw new TypeError('Invalid activity dates');
  }
  for (const day of requested) ordinal(day);
  const start = ordinal(journey.startDate), end = ordinal(today);
  const eligible = day => {
    try { const value = ordinal(day); return value >= start && value <= end; }
    catch { return false; }
  };
  return [...new Set([
    ...(Array.isArray(previous) ? previous : []), ...requested, today,
  ].filter(eligible))].sort();
}
// RevenueCat API v2 uses the internal entitlement ID, not the SDK lookup key.
const REVENUECAT_PROJECT_ID = 'proj802af471';
const LIFETIME_ENTITLEMENT_ID = 'entl62ead602f6';
function lifetimeAccess(activeEntitlements, now = Date.now()) {
  if (activeEntitlements?.object !== 'list' || !Array.isArray(activeEntitlements.items)) {
    throw new TypeError('Invalid active entitlement response');
  }
  const currentTime = now instanceof Date ? now.getTime() : now;
  return activeEntitlements.items.some(entitlement => {
    if (entitlement?.entitlement_id !== LIFETIME_ENTITLEMENT_ID) return false;
    // Null is the documented lifetime/non-consumable expiry. Revoked/refunded
    // purchases disappear from this authoritative active list.
    if (entitlement.expires_at === null) return true;
    if (!Number.isSafeInteger(entitlement.expires_at)) {
      throw new TypeError('Invalid entitlement expiry');
    }
    return entitlement.expires_at > currentTime;
  });
}
function webhookCustomerIds(event) {
  const arrays = ['aliases', 'transferred_from', 'transferred_to'];
  for (const field of arrays) {
    if (event[field] != null && !Array.isArray(event[field])) {
      throw new TypeError('Invalid webhook identities');
    }
  }
  return [...new Set([
    event.app_user_id, event.original_app_user_id,
    ...(event.aliases || []), ...(event.transferred_from || []), ...(event.transferred_to || []),
  ].filter(id => typeof id === 'string' && id.length > 0 && id.length <= 128
    && !id.startsWith('$RCAnonymousID:') && !id.includes('/')))];
}
module.exports={TOTAL_DAYS,validTimeZone,dateKey,ordinal,unlockedThrough,mergeCompletion,mergeActivityDays,lifetimeAccess,webhookCustomerIds,REVENUECAT_PROJECT_ID,LIFETIME_ENTITLEMENT_ID};

function gradeAttempt(catalog, request, revision) {
  if(request.journeyRevision!==revision)throw new Error('stale-revision');
  if(request.contentVersion!==catalog.version)throw new Error('content-version');
  if(typeof request.attemptId!=='string'||!/^[a-zA-Z0-9-]{16,100}$/.test(request.attemptId))throw new Error('attempt-id');
  const lesson=catalog.lessons.find(l=>l.day===request.day);
  if(!lesson)throw new Error('content-unavailable');
  const selected=request.selectedOptionIds;
  if(!selected||typeof selected!=='object'||Array.isArray(selected)||Object.keys(selected).length!==2)throw new Error('answers-required');
  const answers=lesson.questions.map(q=>{
    const optionId=selected[q.id];
    if(!q.options.some(o=>o.id===optionId))throw new Error('invalid-option');
    return {questionId:q.id,selectedOptionId:optionId,correct:optionId===q.correctOptionId};
  });
  return {answers,correctCount:answers.filter(a=>a.correct).length,questionCount:2};
}
module.exports.gradeAttempt=gradeAttempt;
