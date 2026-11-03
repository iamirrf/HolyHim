/* Account data never enters the public shell/asset cache. IndexedDB commits
 * batches and deletion tombstones in one transaction. One writer tab per account
 * prevents read/modify/write outbox races between concurrent browser sessions. */
(() => {
  let opening;
  const leases = new Map();
  function database() {
    if (!opening) opening = new Promise((resolve, reject) => {
      const request = indexedDB.open('holyher-accounts-v1', 1);
      request.onupgradeneeded = () => {
        request.result.createObjectStore('records');
        request.result.createObjectStore('erased');
      };
      request.onsuccess = () => {
        request.result.onversionchange = () => { request.result.close(); opening = null; };
        resolve(request.result);
      };
      request.onerror = () => { opening = null; reject(new Error('Account storage is unavailable.')); };
      request.onblocked = () => { opening = null; reject(new Error('Close another HolyHer tab to finish the storage update.')); };
    });
    return opening;
  }
  async function lease(account) {
    if (leases.has(account)) return leases.get(account).ready;
    if (!navigator.locks) throw new Error('This browser cannot safely open account storage.');
    let accept, refuse, release;
    const ready = new Promise((resolve,reject) => { accept=resolve;refuse=reject; });
    const held = new Promise(resolve => { release=resolve; });
    leases.set(account,{ready,release});
    navigator.locks.request('holyher:'+account,{mode:'exclusive',ifAvailable:true},async lock => {
      if (!lock) { leases.delete(account); refuse(new Error('Your walk is open in another tab. Close that tab and Retry here.')); return; }
      accept(); await held;
    }).catch(error=>{leases.delete(account);refuse(error);});
    return ready;
  }
  async function transaction(account, mode, action, erase=false) {
    await lease(account);
    const db=await database();
    return new Promise((resolve,reject)=>{
      const tx=db.transaction(['records','erased'],mode);
      let result;
      tx.oncomplete=()=>resolve(result);
      tx.onerror=()=>reject(new Error('Your account data could not be saved.'));
      tx.onabort=()=>reject(new Error('Your account storage is unavailable or was deleted.'));
      const guard=tx.objectStore('erased').get(account);
      guard.onsuccess=()=>{
        if(guard.result && !erase){tx.abort();return;}
        action(tx, value=>{result=value;});
      };
    });
  }
  window.holyherStorageRead=async(account,key)=>transaction(account,'readonly',(tx,done)=>{
    const r=tx.objectStore('records').get(JSON.stringify([account,key]));r.onsuccess=()=>done(r.result??'null');
  });
  window.holyherStorageWrite=async(account,batch)=>transaction(account,'readwrite',(tx,done)=>{
    for(const [key,value] of Object.entries(JSON.parse(batch)))tx.objectStore('records').put(JSON.stringify(value),JSON.stringify([account,key]));done(true);
  });
  window.holyherStorageExport=async account=>transaction(account,'readonly',(tx,done)=>{
    const result={};const request=tx.objectStore('records').openCursor();
    request.onsuccess=()=>{const cursor=request.result;if(!cursor){done(JSON.stringify(result));return;}const [owner,key]=JSON.parse(cursor.key);if(owner===account)result[key]=JSON.parse(cursor.value);cursor.continue();};
  });
  window.holyherStorageErase=async account=>transaction(account,'readwrite',(tx,done)=>{
    tx.objectStore('erased').put(true,account);
    const request=tx.objectStore('records').openCursor();request.onsuccess=()=>{const cursor=request.result;if(!cursor){done(true);return;}if(JSON.parse(cursor.key)[0]===account)cursor.delete();cursor.continue();};
  },true);
  window.holyherStorageRelease=account=>{const entry=leases.get(account);if(entry){entry.release();leases.delete(account);}};
})();
