import { createCipheriv, createDecipheriv, createHmac, randomBytes, randomInt, randomUUID, timingSafeEqual } from "node:crypto";
import type { AuthStore, Profile } from "./store.js";
import { hash, secret } from "./store.js";
import { BangumiWebLogin } from "./bangumi-login.js";
import { ApiHttpError } from "../api/errors.js";
import { accountCollectionSchema } from "../contracts/auth.js";
import { SafeFetcher } from "../providers/safe-fetch.js";
const unauthorized = () => new ApiHttpError({ statusCode: 401, code: "HUB_AUTH_REQUIRED", message: "请先在 Hub 浏览器完成登记或配对。", retryable: false });
export class AuthService {
  readonly #key: Buffer;
  readonly #login = new Map<string, { login: BangumiWebLogin; expires: number; busy: boolean }>();
  readonly #generation = new Map<string, number>();
  readonly #mutations = new Map<string, Promise<void>>();
  async #mutate(user: string, operation: () => Promise<void>): Promise<void> {
    const previous=this.#mutations.get(user)??Promise.resolve();
    const next=previous.catch(()=>undefined).then(operation); this.#mutations.set(user,next);
    try { await next; } finally { if(this.#mutations.get(user)===next)this.#mutations.delete(user); }
  }
  constructor(readonly store: AuthStore, key: Buffer, readonly newLogin: () => BangumiWebLogin = () => new BangumiWebLogin()) { this.#key=Buffer.from(key); }
  csrf(token: string): string { return createHmac("sha256",this.#key).update(`doki.csrf.v1:${token}`).digest("hex"); }
  validCsrf(token: string, input: unknown): boolean { const expected=Buffer.from(this.csrf(token)); const got=Buffer.from(typeof input === "string" ? input : ""); return got.length === expected.length && timingSafeEqual(expected,got); }
  async webUser(token: string | undefined): Promise<string> { if (!token || token.length > 512) throw unauthorized(); const user=await this.store.webUser(hash(token)); if (!user) throw unauthorized(); return user; }
  async deviceUser(token: string | undefined): Promise<string> { if (!token || token.length > 512) throw unauthorized(); const user=await this.store.deviceUser(hash(token)); if (!user) throw unauthorized(); return user; }
  async setup(recover=false): Promise<string> { const user=recover ? await this.store.recoverOwner() : await this.store.createOwner(); const token=secret(); await this.store.createWebSession(user,hash(token)); return token; }
  async createPairing(name: string) { const id=randomUUID(); const code=String(randomInt(100000,1000000)); const pairingSecret=secret(); await this.store.createPairing(id,hash(code),hash(pairingSecret),name); return { id, code, secret: pairingSecret, expiresIn: 600 }; }
  pairingStatus(id: string, pairingSecret: string) { return this.store.pairingStatus(id,hash(pairingSecret)); }
  approve(code: string, user: string) { return this.store.approvePairing(hash(code),user); }
  async claim(id: string, pairingSecret: string) { const token=secret(); const deviceId=await this.store.claimPairing(id,hash(pairingSecret),hash(token)); return { deviceId, token }; }
  async status(user: string) { const credential=await this.store.credential(user); return { paired: true as const, bangumi: credential?.profile ?? null }; }
  async captcha(user: string) {
    for (const [id,item] of this.#login) if (item.expires<Date.now()) { item.login.clear(); this.#login.delete(id); }
    let entry=this.#login.get(user);
    if (entry?.busy) throw new ApiHttpError({ statusCode: 409, code: "LOGIN_BUSY", message: "正在登录，请稍候。", retryable: true });
    if (!entry) { if(this.#login.size>=128) throw unauthorized(); entry={login:this.newLogin(),expires:Date.now()+600000,busy:false}; this.#login.set(user,entry); }
    entry.busy=true;
    try { return await entry.login.captcha(); } finally { entry.busy=false; }
  }
  async login(user: string, email: string, password: string, code: string): Promise<Profile> {
    const entry=this.#login.get(user);
    if (!entry || entry.expires<Date.now() || entry.busy) throw new ApiHttpError({ statusCode: 409, code: "LOGIN_EXPIRED", message: "登录会话已过期，请刷新验证码。", retryable: true });
    const generation=(this.#generation.get(user)??0)+1; this.#generation.set(user,generation); entry.busy=true;
    try {
      const result=await entry.login.login(email,password,code);
      await this.#mutate(user,async()=>{
        if (this.#generation.get(user)!==generation) throw unauthorized();
        await this.store.saveCredential(user,this.encrypt(result.token),result.profile);
      });
      this.#login.delete(user); return result.profile;
    } finally { entry.busy=false; }
  }
  encrypt(token: string): string { const iv=randomBytes(12); const cipher=createCipheriv("aes-256-gcm",this.#key,iv); const payload=Buffer.concat([cipher.update(token,"utf8"),cipher.final()]); return ["v1",iv.toString("base64"),cipher.getAuthTag().toString("base64"),payload.toString("base64")].join("."); }
  decrypt(value: string): string { const [version,iv,tag,payload]=value.split("."); if (version!=="v1"||!iv||!tag||!payload) throw unauthorized(); const cipher=createDecipheriv("aes-256-gcm",this.#key,Buffer.from(iv,"base64")); cipher.setAuthTag(Buffer.from(tag,"base64")); return Buffer.concat([cipher.update(Buffer.from(payload,"base64")),cipher.final()]).toString("utf8"); }
  async unlink(user: string) { this.#generation.set(user,(this.#generation.get(user)??0)+1); this.#login.get(user)?.login.clear(); this.#login.delete(user); await this.#mutate(user,()=>this.store.unlink(user)); }
  async collections(user: string, offset: number): Promise<unknown> {
    const credential=await this.store.credential(user); if(!credential) throw unauthorized();
    const token=this.decrypt(credential.encrypted);
    const fetcher=new SafeFetcher({timeoutMs:15000,maxRedirects:0});
    const {response}=await fetcher.fetch(`https://api.bgm.tv/v0/users/${encodeURIComponent(credential.profile.username)}/collections?subject_type=2&limit=50&offset=${offset}`,{maxRedirects:0,headers:{Authorization:`Bearer ${token}`,"User-Agent":"Doki/0.2 (personal tvOS Hub)"}});
    if(response.status===401) throw new ApiHttpError({statusCode:401,code:"BGM_SESSION_EXPIRED",message:"Bangumi 登录已失效，请在 Hub 重新登录。",retryable:false});
    if(!response.ok) throw new ApiHttpError({statusCode:502,code:"BGM_COLLECTION_UNAVAILABLE",message:"暂时无法读取追番列表。",retryable:true});
    const current=await this.store.credential(user); if(current?.revision!==credential.revision) throw unauthorized();
    let payload: unknown;
    try { payload=JSON.parse(await fetcher.readText(response,{maxBytes:4*1024*1024})); } catch { throw new ApiHttpError({statusCode:502,code:"BGM_COLLECTION_INVALID",message:"追番列表格式异常，请稍后重试。",retryable:true}); }
    const parsed=accountCollectionSchema.safeParse(payload);
    if(!parsed.success) throw new ApiHttpError({statusCode:502,code:"BGM_COLLECTION_INVALID",message:"追番列表格式异常，请稍后重试。",retryable:true});
    return parsed.data;
  }
}
