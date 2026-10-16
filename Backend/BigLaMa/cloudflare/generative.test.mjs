import {test} from 'node:test';
import assert from 'node:assert/strict';
import {reconstruct} from './generative.mjs';
function storage(){const values=new Map(),s={get:async k=>structuredClone(values.get(k)),put:async(k,v)=>values.set(k,structuredClone(v))};return{...s,transaction:async f=>f(s)}}
function png(w=480){const b=new Uint8Array(33),v=new DataView(b.buffer);b.set([137,80,78,71,13,10,26,10]);v.setUint32(8,13);v.setUint32(12,0x49484452);v.setUint32(16,w);v.setUint32(20,480);return b}
function request({width=480,extra=false,client='client'}={}){const f=new FormData();f.set('image',new Blob([png(width)]),'source.png');f.set('marked',new Blob([png()]),'marked.png');if(extra)f.set('prompt','attacker prompt');return new Request('https://internal/v1/reconstruct',{method:'POST',headers:{'x-cookies-client':client},body:f})}
test('Invalid geometry and injected prompts never reserve quota or call AI',async()=>{
 const s=storage(),env={AI:{run(){throw new Error('must not run')}}};
 assert.equal((await reconstruct(request({width:512}),env,{storage:s})).status,400);
 assert.equal((await reconstruct(request({extra:true}),env,{storage:s})).status,400);
 assert.equal(await s.get('generative-budget'),undefined);
});
test('Fixed hosted request and persisted budget survive object recreation',async()=>{
 const s=storage();let calls=0;
 const env={AI:{async run(model,body){calls++;assert.equal(model,'@cf/black-forest-labs/flux-2-klein-9b');const form=await new Response(body.multipart.body,{headers:{'content-type':body.multipart.contentType}}).formData();assert.equal(form.get('width'),'512');assert.equal(form.get('height'),'512');assert.match(form.get('prompt'),/No new letters/);return{image:btoa(String.fromCharCode(...png()))}}}};
 const today=new Date().toISOString().slice(0,10);await s.put('generative-budget',{day:today,total:3,clients:{}});
 const first=await reconstruct(request(),env,{storage:s});assert.equal(first.status,200);assert.match(first.headers.get('x-cookies-source-sha256'),/^[0-9a-f]{64}$/);assert.equal(first.headers.get('cache-control'),'no-store');
 assert.equal((await reconstruct(request(),env,{storage:s})).status,200);
 assert.equal((await reconstruct(request({client:'second'}),env,{storage:s})).status,429);assert.equal(calls,2);
});
test('Client limit and failed inference retain reservations without exposing model errors',async()=>{
 const s=storage(),today=new Date().toISOString().slice(0,10);await s.put('generative-budget',{day:today,total:0,clients:{}});
 const env={AI:{async run(){throw new Error('private implementation detail')}}};
 for(let n=0;n<2;n++){const result=await reconstruct(request(),env,{storage:s});assert.equal(result.status,503);assert.deepEqual(await result.json(),{error:'service_unavailable'})}
 assert.equal((await reconstruct(request(),env,{storage:s})).status,429);assert.equal((await s.get('generative-budget')).total,2);
});
