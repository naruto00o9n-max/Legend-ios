// Cookies-owned transfer protocol. IDs never determine ownership; the function
// derives it from a server-verified session. No ZIP is unpacked on the server.
export const CHUNK = 8 * 1024 * 1024;
export const LIMIT = 128 * 1024 * 1024;
export const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
export const HEX = /^[0-9a-f]{64}$/;
export type Head = { version: number; title: string; bytes: number; sha256: string; chunks: {bytes:number;sha256:string}[]; width:number; height:number };
export function validateHead(value: unknown): Head {
  const h = value as Head;
  if (!h || h.version !== 1 || typeof h.title !== 'string' || h.title.length > 256 || !Number.isSafeInteger(h.bytes) || h.bytes <= 0 || h.bytes > LIMIT || !HEX.test(h.sha256)) throw new Error('Invalid project manifest');
  if (!Number.isSafeInteger(h.width) || !Number.isSafeInteger(h.height) || h.width < 1 || h.height < 1 || h.width * h.height > 200_000_000) throw new Error('Invalid image dimensions');
  if (!Array.isArray(h.chunks) || h.chunks.length !== Math.ceil(h.bytes / CHUNK)) throw new Error('Invalid chunk count');
  let total = 0;
  for (const [i,c] of h.chunks.entries()) {
    if (!c || !Number.isSafeInteger(c.bytes) || c.bytes !== Math.min(CHUNK, h.bytes-i*CHUNK) || !HEX.test(c.sha256)) throw new Error('Invalid chunk');
    total += c.bytes;
  }
  if (total !== h.bytes) throw new Error('Invalid transfer length');
  // Rebuild instead of accepting unknown/unbounded fields into the database.
  return {version:1,title:h.title,bytes:h.bytes,sha256:h.sha256,chunks:h.chunks.map(c=>({bytes:c.bytes,sha256:c.sha256})),width:h.width,height:h.height};
}
export async function digest(data: ArrayBuffer | Uint8Array): Promise<string> {
  return Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256',data as BufferSource))).map(x=>x.toString(16).padStart(2,'0')).join('');
}
export async function ownerID(issuer:string,id:string):Promise<string> {
  const h=await digest(new TextEncoder().encode(issuer+'\n'+id));
  return `${h.slice(0,8)}-${h.slice(8,12)}-5${h.slice(13,16)}-a${h.slice(17,20)}-${h.slice(20,32)}`;
}
