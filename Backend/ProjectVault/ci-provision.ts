// Temporary CI-only provisioning. GitHub's signed OIDC identity is checked;
// privileged platform keys never leave this function or enter a test bundle.
import {createRemoteJWKSet,jwtVerify} from 'npm:jose@6.1.0';
import {ownerID,UUID} from './protocol.ts';
const root=Deno.env.get('SUPABASE_URL')!;
const key=JSON.parse(Deno.env.get('SUPABASE_SECRET_KEYS')||'{}').default||Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const api=JSON.parse(Deno.env.get('SUPABASE_PUBLISHABLE_KEYS')||'{}').default||Deno.env.get('SUPABASE_ANON_KEY')!;
const keys=createRemoteJWKSet(new URL('https://token.actions.githubusercontent.com/.well-known/jwks'));
const headers={apikey:key,Authorization:'Bearer '+key,'Content-Type':'application/json'};
async function admin(path:string,method='GET',body?:unknown){const r=await fetch(root+path,{method,headers,body:body===undefined?undefined:JSON.stringify(body)});const text=await r.text();if(!r.ok)throw new Error('Test infrastructure request failed '+r.status);return text?JSON.parse(text):null}
async function clean(user:{id:string;app_metadata?:Record<string,unknown>},run:string){
 if(user.app_metadata?.cookies_vault_ci!==true || user.app_metadata?.run_id!==run)return;
 const owner=await ownerID(root,user.id),rows=await admin('/rest/v1/cookies_vault_revisions?owner_id=eq.'+owner+'&select=*');
 for(const row of rows){const paths=row.head.chunks.map((_:unknown,i:number)=>`${owner}/${row.project_id}/${row.revision_id}/${i}`);await admin('/storage/v1/object/cookies-projects','DELETE',{prefixes:paths})}
 await admin('/rest/v1/cookies_vault_projects?owner_id=eq.'+owner,'DELETE');await admin('/rest/v1/cookies_vault_revisions?owner_id=eq.'+owner,'DELETE');await admin('/auth/v1/admin/users/'+user.id,'DELETE');
}
function isPublicKey(value:string){if(value?.startsWith('sb_publishable_'))return true;try{return JSON.parse(atob(value.split('.')[1].replaceAll('-','+').replaceAll('_','/'))).role==='anon'}catch{return false}}
Deno.serve(async req=>{
 try{
  const token=req.headers.get('Authorization')?.replace(/^Bearer /,'');if(!token)return new Response('Unauthorized',{status:401});
  const {payload:p}=await jwtVerify(token,keys,{issuer:'https://token.actions.githubusercontent.com',audience:'cookies-vault-native-tests',maxTokenAge:'10 minutes'});
  if(p.repository_id!=='1411265955' || p.repository_owner_id!=='319563334' || p.ref!=='refs/heads/verify/project-vault-oct16' || p.workflow_ref!=='naruto00o9n-max/Legend-ios/.github/workflows/project-vault.yml@refs/heads/verify/project-vault-oct16')return new Response('Forbidden',{status:403});
  if(!isPublicKey(api))throw new Error('No public test client key configured');
  const run=String(p.run_id),action=new URL(req.url).pathname.split('/').pop();
  if(action==='cleanup'){
   const body=await req.json();if(!Array.isArray(body.users)||body.users.length>5)return new Response('Invalid users',{status:400});
   for(const id of body.users){if(!UUID.test(id))return new Response('Invalid user',{status:400});const user=await admin('/auth/v1/admin/users/'+id);await clean(user,run)}
   return Response.json({cleaned:true});
  }
  if(action!=='provision')return new Response('Not found',{status:404});
  const password=crypto.randomUUID()+crypto.randomUUID(),email='ci-vault-'+crypto.randomUUID()+'@example.invalid';
  const user=await admin('/auth/v1/admin/users','POST',{email,password,email_confirm:true,app_metadata:{cookies_vault_ci:true,run_id:run,run_attempt:String(p.run_attempt)}});
  const r=await fetch(root+'/auth/v1/token?grant_type=password',{method:'POST',headers:{apikey:api,'Content-Type':'application/json'},body:JSON.stringify({email,password})});const session=await r.json();
  if(!r.ok){await clean(user,run);throw new Error('Could not sign into test account')}
  return Response.json({configuration:{url:root,key:api},session},{headers:{'Cache-Control':'no-store'}});
 }catch(error){console.error('CI vault setup failed',error instanceof Error?error.name:'Unknown');return new Response('Test setup failed',{status:403})}
});
