import {UUID,ownerID} from './protocol.ts';
export class AuthFailure extends Error {
  status:number;
  constructor(status:number,message:string){super(message);this.status=status}
}
export type Issuer={url:string;key:string};
export async function authenticatedOwner(req:Request,issuers:Issuer[],fetcher:typeof fetch=fetch){
  const authorization=req.headers.get('Authorization');
  if(!authorization?.startsWith('Bearer ') || authorization.length>8192)throw new AuthFailure(401,'Sign in first');
  // The unverified issuer is only an ordering hint within this fixed allowlist.
  // Identity ALWAYS comes from that issuer's signature-validating user API.
  let hint:string|undefined;
  try{hint=JSON.parse(atob(authorization.slice(7).split('.')[1].replaceAll('-','+').replaceAll('_','/'))).iss}catch{}
  const ordered=[...issuers].sort((a,b)=>Number(b.url+'/auth/v1'===hint)-Number(a.url+'/auth/v1'===hint));
  let unavailable=false;
  for(const issuer of ordered){
    try{
      const response=await fetcher(issuer.url+'/auth/v1/user',{headers:{apikey:issuer.key,Authorization:authorization},signal:AbortSignal.timeout(10000)});
      if(response.status>=500 || response.status===429 || response.status===408){unavailable=true;continue}
      if(!response.ok)continue;
      const user=await response.json();
      if(typeof user.id==='string' && UUID.test(user.id) && user.is_anonymous!==true)return ownerID(issuer.url,user.id);
    }catch{unavailable=true}
  }
  throw new AuthFailure(unavailable?503:401,unavailable?'Account verification temporarily unavailable':'Session expired');
}
