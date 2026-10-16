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
  const day=new Date().toISOString().slice(0,10);
  const accepted=await state.storage.transaction(async storage=>{
    let budget=await storage.get('generative-budget');
    // Four private evaluations were run before release on this date. They
    // count toward the same conservative free daily allocation.
    if(!budget || budget.day!==day)budget={day,total:day==='2026-10-16'?4:0,clients:{}};
    if(budget.total>=5 || (budget.clients[client] || 0)>=2)return false;
    budget.total++;budget.clients[client]=(budget.clients[client] || 0)+1;
    await storage.put('generative-budget',budget);return true;
  });
  if(!accepted)return json({error:'daily_capacity_reached'},429);
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
  }catch{return json({error:'service_unavailable'},503)}
}
