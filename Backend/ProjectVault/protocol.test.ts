import assert from 'node:assert/strict';
import test from 'node:test';
import {validateHead,ownerID,digest,CHUNK} from './protocol.ts';
const hash='a'.repeat(64);
const head=()=>({version:1,title:'الفصل',bytes:10,sha256:hash,chunks:[{bytes:10,sha256:hash}],width:800,height:15000});
test('strict manifest rejects truncation, oversized and malicious fields',()=>{
 assert.equal(validateHead({...head(),unknown:'not retained'}).title,'الفصل');
 assert.equal(Object.keys(validateHead({...head(),unknown:true})).includes('unknown'),false);
 for(const bad of [null,{}, {...head(),bytes:NaN}, {...head(),bytes:134217729},{...head(),sha256:'no'}, {...head(),chunks:[]},{...head(),chunks:[{bytes:9,sha256:hash}]},{...head(),width:1000000000}])assert.throws(()=>validateHead(bad));
});
test('chunk boundaries match exact length',()=>{
 const x={...head(),bytes:CHUNK+1,chunks:[{bytes:CHUNK,sha256:hash},{bytes:1,sha256:hash}]};assert.equal(validateHead(x).chunks.length,2);
 assert.throws(()=>validateHead({...x,chunks:[{bytes:CHUNK-1,sha256:hash},{bytes:2,sha256:hash}]}));
});
test('owner namespace cannot collide between legitimate issuers',async()=>{
 const a=await ownerID('https://one','31a0dd93-c30f-4c22-86b7-b4c9bb649b1b');assert.match(a,/^[0-9a-f-]{36}$/);assert.equal(a,await ownerID('https://one','31a0dd93-c30f-4c22-86b7-b4c9bb649b1b'));
 assert.notEqual(a,await ownerID('https://two','31a0dd93-c30f-4c22-86b7-b4c9bb649b1b'));assert.equal(await digest(new TextEncoder().encode('abc')),'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad');
});
