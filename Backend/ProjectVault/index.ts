import { CHUNK, UUID, validateHead, digest, ownerID } from './protocol.ts';
import {authenticatedOwner,AuthFailure} from './auth.ts';
import reference from './trusted-auth.json' with {type:'json'};

const url=Deno.env.get('SUPABASE_URL')!;
const key=JSON.parse(Deno.env.get('SUPABASE_SECRET_KEYS') || '{}').default || Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const bucket='cookies-projects';
const headers={'apikey':key,'Authorization':'Bearer '+key,'Content-Type':'application/json'};
class Failure extends Error {constructor(public status:number,message:string){super(message)}}
function response(value:unknown,status=200){return new Response(JSON.stringify(value),{status,headers:{'Content-Type':'application/json','Cache-Control':'no-store'}})}
async function rest(path:string,method='GET',body?:unknown){
  const r=await fetch(url+'/rest/v1/'+path,{method,headers,body:body===undefined ? undefined:JSON.stringify(body),signal:AbortSignal.timeout(15000)});
  const text=await r.text(),data=text?JSON.parse(text):null;if(!r.ok)throw new Failure(r.status,typeof data?.message==='string' ? data.message:'Vault unavailable');return data;
}
async function limited(req:Request,limit:number){
  const reader=req.body?.getReader();if(!reader)throw new Failure(400,'Missing request body');let count=0;const chunks:Uint8Array[]=[];
  for(;;){const{done,value}=await reader.read();if(done)break;count+=value.length;if(count>limit){await reader.cancel();throw new Failure(413,'Request too large')}chunks.push(value)}
  const bytes=new Uint8Array(count);let offset=0;for(const chunk of chunks){bytes.set(chunk,offset);offset+=chunk.length}return bytes;
}
async function body(req:Request){try{return JSON.parse(new TextDecoder().decode(await limited(req,16384)))}catch(error){if(error instanceof Failure)throw error;throw new Failure(400,'Invalid JSON body')}}
async function authenticate(req:Request){
  const publicKey=JSON.parse(Deno.env.get('SUPABASE_PUBLISHABLE_KEYS')||'{}').default||Deno.env.get('SUPABASE_ANON_KEY')!;
  return authenticatedOwner(req,[{url:reference.url,key:reference.key},{url,key:publicKey}]);
}
function ids(project:string,revision?:string){if(!UUID.test(project) || (revision!==undefined&&!UUID.test(revision)))throw new Failure(400,'Invalid identifier')}
function prefix(owner:string,project:string,revision:string){return `${owner}/${project}/${revision}`}
async function revision(owner:string,project:string,id:string){
  ids(project,id);const rows=await rest(`cookies_vault_revisions?owner_id=eq.${owner}&project_id=eq.${project}&revision_id=eq.${id}&select=*`);
  if(rows.length!==1)throw new Failure(404,'Revision not found');return rows[0];
}
async function cleanup(owner:string){
  await rest('rpc/cookies_vault_expire','POST',{p_owner:null});
  const rows=await rest(`cookies_vault_revisions?stage=eq.retired&retired_at=lt.${encodeURIComponent(new Date(Date.now()-15*60*1000).toISOString())}&limit=8`);
  for(const row of rows){
    const h=validateHead(row.head),paths=h.chunks.map((_,i)=>prefix(row.owner_id,row.project_id,row.revision_id)+'/'+i);
    const r=await fetch(url+'/storage/v1/object/'+bucket,{method:'DELETE',headers,body:JSON.stringify({prefixes:paths}),signal:AbortSignal.timeout(20000)});
    if(r.ok)await rest('rpc/cookies_vault_remove_revision','POST',{p_owner:row.owner_id,p_project:row.project_id,p_revision:row.revision_id});
  }
}
Deno.serve(async(req:Request)=>{
  try{
    const owner=await authenticate(req),parts=new URL(req.url).pathname.split('/').filter(Boolean),action=parts.slice(parts.indexOf('project-vault')+1);
    const op=action[0];
    if(req.method==='GET' && op==='list'){
      const projects=await rest(`cookies_vault_projects?owner_id=eq.${owner}&select=*&order=updated_at.desc&limit=1000`);
      const usage=await rest(`cookies_vault_revisions?owner_id=eq.${owner}&select=byte_size`);
      return response({owner,projects,used:usage.reduce((n:number,r:{byte_size:number})=>n+r.byte_size,0),limit:536870912});
    }
    if(req.method==='POST' && op==='reserve'){
      const v=await body(req);ids(v.project,v.revision);const head=validateHead(v.head);
      if(!Number.isSafeInteger(v.expected) || v.expected<0)throw new Failure(400,'Invalid generation');
      await cleanup(owner);
      await rest('rpc/cookies_vault_reserve','POST',{p_owner:owner,p_project:v.project,p_revision:v.revision,p_expected:v.expected,p_head:head});
      return response({owner});
    }
    if(op==='chunk' && action.length===4){
      const [_,project,id,part]=action;const row=await revision(owner,project,id),head=validateHead(row.head),i=Number(part);
      if(!/^\d+$/.test(part) || !Number.isSafeInteger(i) || !head.chunks[i])throw new Failure(400,'Invalid chunk index');
      const path=prefix(owner,project,id)+'/'+i;
      if(req.method==='PUT'){
        if(row.stage!=='pending' || Date.parse(row.created_at)<Date.now()-3600000)throw new Failure(409,'Upload expired');
        const stated=Number(req.headers.get('Content-Length'));if(stated>CHUNK)throw new Failure(413,'Chunk too large');
        const bytes=await limited(req,CHUNK),count=bytes.length;
        if(count!==head.chunks[i].bytes || await digest(bytes)!==head.chunks[i].sha256)throw new Failure(422,'Chunk checksum mismatch');
        const r=await fetch(url+'/storage/v1/object/'+bucket+'/'+path,{method:'POST',headers:{...headers,'Content-Type':'application/octet-stream','x-upsert':'false'},body:bytes,signal:AbortSignal.timeout(25000)});
        if(!r.ok){const old=await fetch(url+'/storage/v1/object/'+bucket+'/'+path,{headers,signal:AbortSignal.timeout(25000)});if(!old.ok || await digest(await old.arrayBuffer())!==head.chunks[i].sha256)throw new Failure(503,'Chunk could not be saved')}
        return response({sha256:head.chunks[i].sha256});
      }
      if(req.method==='GET'){
        if(row.stage!=='current')throw new Failure(409,'Project changed; refresh it');
        const r=await fetch(url+'/storage/v1/object/'+bucket+'/'+path,{headers,signal:AbortSignal.timeout(25000)});
        if(!r.ok)throw new Failure(503,'Project chunk unavailable');return new Response(r.body,{headers:{'Content-Type':'application/octet-stream','Cache-Control':'no-store','X-Content-SHA256':head.chunks[i].sha256}});
      }
    }
    if(req.method==='POST' && op==='commit'){
      const v=await body(req),row=await revision(owner,v.project,v.revision),head=validateHead(row.head);
      if(row.stage==='retired')throw new Failure(409,'Upload retired');
      for(let i=0;i<head.chunks.length;i++){
        const r=await fetch(url+'/storage/v1/object/'+bucket+'/'+prefix(owner,v.project,v.revision)+'/'+i,{method:'HEAD',headers,signal:AbortSignal.timeout(15000)});
        if(!r.ok || Number(r.headers.get('Content-Length'))!==head.chunks[i].bytes)throw new Failure(409,'Incomplete upload');
      }
      return response(await rest('rpc/cookies_vault_commit','POST',{p_owner:owner,p_project:v.project,p_revision:v.revision}));
    }
    if(req.method==='POST' && op==='delete'){
      const v=await body(req);ids(v.project);if(!Number.isSafeInteger(v.expected) || v.expected<1)throw new Failure(400,'Invalid generation');
      await rest('rpc/cookies_vault_delete','POST',{p_owner:owner,p_project:v.project,p_expected:v.expected});return response({deleted:true});
    }
    if(req.method==='POST' && op==='cleanup'){await cleanup(owner);return response({ok:true})}
    throw new Failure(404,'Unknown operation');
  }catch(error){if(error instanceof Failure || error instanceof AuthFailure)return response({message:error.message},error.status);console.error('Vault request failed',error instanceof Error ? error.name:'Unknown');return response({message:'Could not complete vault request'},500)}
});
