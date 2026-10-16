import {test} from 'node:test';
import assert from 'node:assert/strict';
import {authenticatedOwner,AuthFailure} from './auth.ts';
import {ownerID} from './protocol.ts';
const issuers=[{url:'https://original.test',key:'public-original'},{url:'https://owned.test',key:'public-owned'}];
const id='af2ab6ae-47a6-4ee3-a8ab-e43dec1dc209';
const request=(iss:string)=>new Request('https://vault.test/list',{headers:{Authorization:'Bearer h.'+btoa(JSON.stringify({iss,sub:'forged-subject'}))+'.s'}});
test('Owned signed session does not depend on original issuer availability',async()=>{
 const calls:string[]=[];
 const fetcher=(async(input:RequestInfo|URL)=>{calls.push(String(input));assert.equal(String(input),'https://owned.test/auth/v1/user');return Response.json({id})}) as typeof fetch;
 assert.equal(await authenticatedOwner(request('https://owned.test/auth/v1'),issuers,fetcher),await ownerID(issuers[1].url,id));assert.equal(calls.length,1);
});
test('One issuer timeout cannot prevent another fixed issuer from validating',async()=>{
 const calls:string[]=[];
 const fetcher=(async(input:RequestInfo|URL)=>{calls.push(String(input));if(String(input).startsWith(issuers[0].url))throw new DOMException('Timed out','TimeoutError');return Response.json({id})}) as typeof fetch;
 assert.equal(await authenticatedOwner(request('unknown'),issuers,fetcher),await ownerID(issuers[1].url,id));assert.equal(calls.length,2);
});
test('Unverified issuer and subject never authorize or select an arbitrary host',async()=>{
 const calls:string[]=[];
 const fetcher=(async(input:RequestInfo|URL)=>{calls.push(String(input));return new Response('',{status:401})}) as typeof fetch;
 await assert.rejects(authenticatedOwner(request('https://attacker.test/auth/v1'),issuers,fetcher),(e:unknown)=>e instanceof AuthFailure && e.status===401);
 assert.deepEqual(calls,issuers.map(i=>i.url+'/auth/v1/user'));
});
test('Unavailable identity service is 503, never a false expired-session or 500',async()=>{
 const fetcher=(async()=>{throw new DOMException('Timed out','TimeoutError')}) as typeof fetch;
 await assert.rejects(authenticatedOwner(request('unknown'),issuers,fetcher),(e:unknown)=>e instanceof AuthFailure && e.status===503);
 for(const status of [408,429,503]){
  const limited=(async()=>new Response('',{status})) as typeof fetch;
  await assert.rejects(authenticatedOwner(request('unknown'),issuers,limited),(e:unknown)=>e instanceof AuthFailure && e.status===503);
 }
});
