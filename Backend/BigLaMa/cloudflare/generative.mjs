// Optional hosted reconstruction. The prompt, model, geometry and budget are
// server-owned. No account token, input image or response is persisted/logged.
const json=(body,status=200)=>Response.json(body,{status,headers:{'cache-control':'no-store'}});
const MAX_BODY=1_500_000;
const PROMPT='Restore image 0 by erasing the text in the marked regions only. Image 1 shows the exact regions to repair in bright magenta. Reconstruct the original underlying background, continuing its existing gradients, texture, fine line patterns and colors naturally through those regions. Preserve every border, decorative line, panel, shape, existing object and the exact original composition and geometry. The result must look like the same original comic artwork before lettering was added. No new letters, symbols or objects. Replace all magenta with matching background.';
async function boundedForm(request){
  const reader=request.body?.getReader();if(!reader)throw new Error('invalid');
  let size=0;const parts=[];
  for(;;){const{done,value}=await reader.read();if(done)break;size+=value.length;if(size>MAX_BODY){await reader.cancel();throw new Error('large')}parts.push(value)}
  return new Response(new Blob(parts),{headers:{'content-type':request.headers.get('content-type') || ''}}).formData();
}
function png480(bytes){
  const signature=[137,80,78,71,13,10,26,10];
  if(bytes.length<33 || signature.some((n,i)=>bytes[i]!==n))return false;
  const v=new DataView(bytes.buffer,bytes.byteOffset,bytes.byteLength);
  return v.getUint32(8)===13 && v.getUint32(12)===0x49484452 && v.getUint32(16)===480 && v.getUint32(20)===480;
}
export async function reconstruct(request,env,state){
  if(!env.AI)return json({error:'not_configured'},503);
  let images;
  try{
    const form=await boundedForm(request),entries=[...form];
    if(entries.length!==2 || new Set(entries.map(([k])=>k)).size!==2)throw new Error('invalid');
    images=[];
    for(const name of ['image','marked']){
      const file=form.get(name);if(!(file instanceof File) || file.size>700_000)throw new Error('invalid');
      const bytes=new Uint8Array(await file.arrayBuffer());if(!png480(bytes))throw new Error('invalid');images.push(bytes);
    }
  }catch(error){return json({error:error.message==='large'?'region_too_large':'invalid_region'},error.message==='large'?413:400)}
  const client=request.headers.get('x-cookies-client');
  if(!client)return json({error:'client_unavailable'},400);
  const now=new Date(),day=now.toISOString().slice(0,10),month=day.slice(0,7);
  const limit=(value,fallback,max)=>Number.isSafeInteger(Number(value)) && Number(value)>0 ? Math.min(max,Number(value)):fallback;
  const daily=limit(env.GENERATIVE_DAILY_REQUESTS,250,10_000),perClient=limit(env.GENERATIVE_CLIENT_DAILY_REQUESTS,50,daily),monthly=limit(env.GENERATIVE_MONTHLY_REQUESTS,1000,100_000);
  const reservation=await state.storage.transaction(async storage=>{
    let budget=await storage.get('generative-budget'),usage=await storage.get('generative-month');
    // Preserve genuine prior usage, but never seed synthetic daily exhaustion.
    if(!budget || budget.day!==day)budget={day,total:0,clients:{}};
    if(!usage || usage.month!==month)usage={month,total:0};
    if((budget.clients[client] || 0)>=perClient)return 'client_daily_capacity_reached';
    if(budget.total>=daily)return 'service_daily_capacity_reached';
    if(usage.total>=monthly)return 'service_monthly_capacity_reached';
    budget.total++;budget.clients[client]=(budget.clients[client] || 0)+1;usage.total++;
    await storage.put('generative-budget',budget);await storage.put('generative-month',usage);return null;
  });
  if(reservation)return json({error:reservation},429);
  try{
    const form=new FormData();form.set('prompt',PROMPT);form.set('width','512');form.set('height','512');
    images.forEach((bytes,i)=>form.set('input_image_'+i,new Blob([bytes],{type:'image/png'}),'region.png'));
    const serialized=new Response(form);
    const result=await env.AI.run('@cf/black-forest-labs/flux-2-klein-9b',{multipart:{body:serialized.body,contentType:serialized.headers.get('content-type')}});
    if(typeof result.image!=='string' || result.image.length>8_000_000)throw new Error('invalid');
    const raw=atob(result.image.replace(/^data:image\/[^;]+;base64,/,'')),bytes=Uint8Array.from(raw,c=>c.charCodeAt(0));
    if(bytes[0]!==137 && !(bytes[0]===255 && bytes[1]===216))throw new Error('invalid');
    const digest=await crypto.subtle.digest('SHA-256',images[0]);
    return new Response(bytes,{headers:{'content-type':bytes[0]===137?'image/png':'image/jpeg','cache-control':'no-store','x-cookies-source-sha256':[...new Uint8Array(digest)].map(v=>v.toString(16).padStart(2,'0')).join('')}});
  }catch(error){
    // Provider failures are not successful user edits. Release the application
    // daily reservation. Keep ambiguous attempts in the shared monthly cost
    // ceiling: a provider can bill even if its response is lost or invalid.
    const message=String(error?.message || ''),code=Number(error?.code || error?.errors?.[0]?.code);
    const notCharged=[3036,3040].includes(code) || /3036|daily free allocation|10,?000 neurons/i.test(message);
    await state.storage.transaction(async storage=>{
      const budget=await storage.get('generative-budget'),usage=await storage.get('generative-month');
      if(budget?.day===day){budget.total=Math.max(0,budget.total-1);budget.clients[client]=Math.max(0,(budget.clients[client] || 0)-1);await storage.put('generative-budget',budget)}
      if(notCharged && usage?.month===month){usage.total=Math.max(0,usage.total-1);await storage.put('generative-month',usage)}
    });
    if(code===3036 || /3036|daily free allocation|10,?000 neurons/i.test(message))return json({error:'provider_account_capacity_reached'},503);
    return json({error:'service_unavailable'},503);
  }
}
