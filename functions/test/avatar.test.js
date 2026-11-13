'use strict';
const {test} = require('node:test');
const assert = require('node:assert/strict');
const {createAvatarCleanup} = require('../avatar');
const url = path => `https://firebasestorage.googleapis.com/v0/b/demo-holyhim.appspot.com/o/${encodeURIComponent(path)}?alt=media&token=fixture`;
test('accepted avatar replacement/removal cleans only the previous owner image', async () => {
 const removed=[];const cleanup=createAvatarCleanup({deleteObject:async path=>removed.push(path)});
 const before=url('users/alice/avatars/123.jpg');
 await cleanup({uid:'alice',before,after:before});assert.deepEqual(removed,[]);
 await cleanup({uid:'alice',before,after:url('users/alice/avatars/456.jpg')});
 await cleanup({uid:'alice',before,after:''});
 assert.deepEqual(removed,['users/alice/avatars/123.jpg','users/alice/avatars/123.jpg']);
 for(const old of [url('users/bob/avatars/123.jpg'),url('users/alice/avatars/123.jpg/elsewhere'),'https://example.com/o/users%2Falice%2Favatars%2F123.jpg','malformed',null])await cleanup({uid:'alice',before:old,after:null});
 assert.equal(removed.length,2);
});
test('avatar deletion errors remain retryable by the event trigger',async()=>{
 const cleanup=createAvatarCleanup({deleteObject:async()=>{throw new Error('temporary');}});
 await assert.rejects(cleanup({uid:'alice',before:url('users/alice/avatars/123.jpg'),after:null}),/temporary/);
});
