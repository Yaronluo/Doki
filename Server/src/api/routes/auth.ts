import type { FastifyInstance, FastifyRequest, FastifyReply } from "fastify";
import { z } from "zod";
import { timingSafeEqual } from "node:crypto";
import type { HubConfig } from "../../config/config.js";
import { AuthService } from "../../auth/service.js";
import { secret } from "../../auth/store.js";
import { pairingRequestSchema, webLoginSchema } from "../../contracts/auth.js";
import { ApiHttpError } from "../errors.js";
const forbidden=()=>new ApiHttpError({statusCode:403,code:"HUB_BROWSER_FORBIDDEN",message:"请从 Hub 本机浏览器登记，并从同一页面提交操作。",retryable:false});
const escape=(s:string)=>s.replace(/[&<>"']/g,c=>({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"})[c]!);
const bearer=(request:FastifyRequest,prefix="Bearer ")=>request.headers.authorization?.startsWith(prefix)?request.headers.authorization.slice(prefix.length):undefined;
const cookie=(request:FastifyRequest,name:string)=>request.headers.cookie?.split(";").map(p=>p.trim().split("=")).find(([key])=>key===name)?.[1];
function page(title:string,body:string):string {return `<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>${escape(title)} · Doki Hub</title><style>body{font:17px -apple-system,BlinkMacSystemFont,sans-serif;background:#f3f2f7;color:#222;max-width:740px;margin:55px auto;padding:0 24px}main{background:white;padding:32px;border-radius:22px;box-shadow:0 14px 60px #30204010}h1{font-size:30px}p{line-height:1.7;color:#54505e}label{display:block;margin:20px 0 6px}input{font:inherit;width:100%;box-sizing:border-box;padding:14px;border:1px solid #ddd;border-radius:12px}button,a.action{font:inherit;display:inline-block;background:#7957b3;color:white;border:0;border-radius:12px;padding:14px 22px;margin:22px 8px 0 0;text-decoration:none}img{display:block;max-width:100%;margin:12px 0}small{color:#666}.error{color:#b22}hr{border:0;border-top:1px solid #eee;margin:35px 0}</style><main>${body}</main></html>`;}
const hidden=(csrf:string)=>`<input type="hidden" name="csrf" value="${escape(csrf)}">`;
export function registerAuthRoutes(app:FastifyInstance,service:AuthService,config:HubConfig):void {
  app.addContentTypeParser("application/x-www-form-urlencoded",{parseAs:"string",bodyLimit:8192},(_request,body,done)=>done(null,Object.fromEntries(new URLSearchParams(String(body)))));
  const setupNonces=new Map<string,{expires:number,recover:boolean}>();
  const counts=new Map<string,{since:number,count:number}>();
  app.addHook("onRequest",async(request,reply)=>{
    if (!/^(\/($|setup|pair|auth\/)|\/v1\/(account|devices))/.test(request.url)) return;
    reply.header("cache-control","no-store").header("referrer-policy","no-referrer").header("content-security-policy","default-src 'self'; style-src 'unsafe-inline'; script-src 'none'; img-src 'self'; form-action 'self'; frame-ancestors 'none'; base-uri 'none'");
    let limit=counts.get(request.ip);
    if(!limit||Date.now()-limit.since>60000){if(counts.size>=256)counts.delete(counts.keys().next().value!);limit={since:Date.now(),count:0};counts.set(request.ip,limit);}
    if(++limit.count>90)throw new ApiHttpError({statusCode:429,code:"AUTH_RATE_LIMITED",message:"操作过于频繁，请稍后重试。",retryable:true});
  });
  const local=(request:FastifyRequest)=>["127.0.0.1","::1","::ffff:127.0.0.1"].includes(request.ip)&&["127.0.0.1","localhost","[::1]"].includes(new URL(config.hub.baseUrl).hostname)&&/^(localhost|127\.0\.0\.1|\[::1\])(:[0-9]+)?$/.test(request.headers.host??"");
  const origin=(request:FastifyRequest)=>{
    const expected=new URL(config.hub.baseUrl);
    if(request.headers.host!==expected.host&&!local(request))throw forbidden();
    const incoming=request.headers.origin;
    if(incoming&&incoming!==`${expected.protocol}//${request.headers.host}`)throw forbidden();
    if(request.headers["sec-fetch-site"]==="cross-site")throw forbidden();
  };
  const setCookie=(reply:FastifyReply,name:string,value:string)=>reply.header("set-cookie",`${name}=${value}; HttpOnly; SameSite=Strict; Path=/; Max-Age=604800${config.hub.baseUrl.startsWith("https:")?"; Secure":""}`);
  const csrf=(request:FastifyRequest,token:string)=>{origin(request);const body=request.body as Record<string,unknown>|undefined;if(!service.validCsrf(token,body?.csrf))throw forbidden();};
  const web=async(request:FastifyRequest)=>{const token=cookie(request,"doki_owner");return{user:await service.webUser(token),token:token!};};

  app.get("/",async(request,reply)=>{
    origin(request);
    let owner:{user:string;token:string}|undefined;
    try{owner=await web(request);}catch{}
    if(!owner){
      const nonce=secret();setCookie(reply,"doki_setup",nonce);
      const exists=await service.store.hasOwner();
      for(const[key,value]of setupNonces)if(value.expires<Date.now())setupNonces.delete(key);
      if(setupNonces.size>=128)setupNonces.delete(setupNonces.keys().next().value!);
      setupNonces.set(nonce,{expires:Date.now()+300000,recover:exists});
      return reply.type("text/html").send(page("连接 Doki Hub",`<h1>Doki Hub</h1><p>在这里连接电视和 Bangumi。无需申请 Bangumi API 密钥。</p><form method="post" action="/setup">${hidden(service.csrf(nonce))}${config.setupSecret?'<label>Hub 本地登记凭证</label><input name="setupSecret" type="password" required>':(!local(request)?'<p class="error">首次登记请在 Hub 主机的浏览器打开本页。</p>':'')}<button>${exists?"恢复本机管理会话":"登记这台 Hub"}</button></form><small>恢复管理会话仅允许 Hub 本机访问，已有浏览器管理会话会失效。</small>`));
    }
    const status=await service.status(owner.user);const token=service.csrf(owner.token);
    const failed=(request.query as Record<string,unknown>).failed;
    return reply.type("text/html").send(page("管理",`<h1>Doki Hub</h1>${failed?'<p class="error">操作未成功。请刷新验证码，检查输入后重试。</p>':''}<h2>连接 Apple TV</h2><p>在电视“我的 → Bangumi 登录”发起配对，把六位码填在这里批准。</p><form method="post" action="/pair">${hidden(token)}<input name="code" inputmode="numeric" pattern="[0-9]{6}" maxlength="6" placeholder="电视上的六位配对码" required><button>批准这台电视</button></form><hr><h2>Bangumi</h2>${status.bangumi?`<p>已登录 ${escape(status.bangumi.nickname||status.bangumi.username)}</p><p>电视可读取你的追番列表。个人令牌只加密保存在 Hub。</p><form method="post" action="/auth/bgm/unlink">${hidden(token)}<button>解除本机绑定</button></form>`:`<p>邮箱、密码和图片验证码用于登录官网。密码不保存；成功后自动生成并验证个人令牌。</p><form method="post" action="/auth/bgm/login" autocomplete="on">${hidden(token)}<label>Bangumi 邮箱</label><input type="email" name="email" autocomplete="username" required><label>密码</label><input type="password" name="password" autocomplete="current-password" required><label>验证码</label><img src="/auth/bgm/captcha?fresh=${Date.now()}" alt="Bangumi 验证码"><input name="captcha" autocomplete="off" maxlength="32" required><button>登录 Bangumi</button></form><a href="/">刷新验证码</a>`}<hr><small>弹弹play按当前要求暂缓接入。公开视频来源与账号登录分别配置。</small>`));
  });
  app.post("/setup",async(request,reply)=>{
    const nonce=cookie(request,"doki_setup");if(!nonce)throw forbidden();csrf(request,nonce);
    const setup=setupNonces.get(nonce);if(!setup||setup.expires<Date.now())throw forbidden();
    if(config.setupSecret){const provided=String((request.body as Record<string,unknown>).setupSecret??"");const a=Buffer.from(provided);const b=Buffer.from(config.setupSecret);if(a.length!==b.length||!timingSafeEqual(a,b))throw forbidden();}else if(!local(request))throw forbidden();
    setupNonces.delete(nonce);
    const token=await service.setup(setup.recover);setCookie(reply,"doki_owner",token);return reply.redirect("/",303);
  });
  app.get("/pair",async(_request,reply)=>reply.redirect("/",303));
  app.post("/pair",async(request,reply)=>{const owner=await web(request);csrf(request,owner.token);const{code}=z.object({code:z.string().regex(/^[0-9]{6}$/)}).parse(request.body);await service.approve(code,owner.user);return reply.redirect("/",303);});
  app.get("/auth/bgm/captcha",async(request,reply)=>{const owner=await web(request);origin(request);const image=await service.captcha(owner.user);return reply.type(image.contentType).send(image.bytes);});
  app.post("/auth/bgm/login",async(request,reply)=>{const owner=await web(request);csrf(request,owner.token);const input=webLoginSchema.parse(request.body);try{await service.login(owner.user,input.email,input.password,input.captcha);return reply.redirect("/",303);}catch{return reply.redirect("/?failed=1",303);}});
  app.post("/auth/bgm/unlink",async(request,reply)=>{const owner=await web(request);csrf(request,owner.token);await service.unlink(owner.user);return reply.redirect("/",303);});
  app.post("/v1/devices/pairings",async request=>{origin(request);return service.createPairing(pairingRequestSchema.parse(request.body??{}).name);});
  app.get("/v1/devices/pairings/:id",async request=>{const{id}=z.object({id:z.uuid()}).parse(request.params);const token=bearer(request,"Pairing ");if(!token)throw forbidden();return{state:await service.pairingStatus(id,token)};});
  app.post("/v1/devices/pairings/:id/claim",async request=>{const{id}=z.object({id:z.uuid()}).parse(request.params);const token=bearer(request,"Pairing ");if(!token)throw forbidden();return service.claim(id,token);});
  app.get("/v1/account",async request=>service.status(await service.deviceUser(bearer(request))));
  app.get("/v1/account/collections",async request=>{const{offset}=z.object({offset:z.coerce.number().int().min(0).max(10000).default(0)}).parse(request.query);return service.collections(await service.deviceUser(bearer(request)),offset);});
}
