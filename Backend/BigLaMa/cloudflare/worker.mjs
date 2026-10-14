import {DurableObject} from "cloudflare:workers";
import handler, {RestorationGateCore} from "./core.mjs";
export default handler;
export class RestorationGate extends DurableObject {
  constructor(ctx, env) { super(ctx, env); this.core = new RestorationGateCore(ctx, env); }
  fetch(request) { return this.core.fetch(request); }
}
