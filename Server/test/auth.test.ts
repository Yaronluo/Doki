import { describe, expect, it } from "vitest";
import { BangumiWebLogin } from "../src/auth/bangumi-login.js";
import { AuthService } from "../src/auth/service.js";
import type { AuthStore, Profile } from "../src/auth/store.js";
import type { FetchTransport } from "../src/providers/types.js";
import { createApp } from "../src/api/app.js";
import { testConfig } from "./helpers/test-config.js";
const fixtureToken = "selfmade-personal-token-0123456789";
const fixturePassword = "self-made-password-never-real";
const fixtureProfile: Profile = {id:42,username:"fixture-user",nickname:"自造用户"};
function website(rejected=false): {transport:FetchTransport; calls:{url:string;headers:Readonly<Record<string,string>>;body?:string}[]} {
  const calls:{url:string;headers:Readonly<Record<string,string>>;body?:string}[]=[];
  return {calls,transport:{
    async fetch(url,options){
      calls.push({url,headers:options.headers??{},...(options.body?{body:options.body}:{})});
      let response:Response;
      if(url==="https://bgm.tv/login")response=new Response('<form><input name="formhash" value="self-made-form"></form>',{headers:{"set-cookie":"session=fixture; Domain=bgm.tv; Path=/; Secure"}});
      else if(url.includes("/signup/captcha?"))response=new Response(new Uint8Array([71,73,70]),{headers:{"content-type":"image/gif"}});
      else if(url==="https://bgm.tv/FollowTheRabbit"){
        expect(new URLSearchParams(options.body).get("password")).toBe(fixturePassword);
        expect(options.followRedirects).toBe(false);
        response=new Response(null,{status:302,headers:{location:"https://untrusted.example/",...(!rejected?{"set-cookie":"chii_auth=fixture-session; Domain=bgm.tv; Path=/; Secure"}:{})}});
      } else if(url==="https://next.bgm.tv/demo/access-tokens"){
        expect(options.headers?.["User-Agent"]).toBe(calls[0]?.headers["User-Agent"]);
        expect(options.headers?.Cookie).toContain("chii_auth=");
        expect(JSON.parse(options.body!)).toMatchObject({days:365});
        response=new Response(JSON.stringify(fixtureToken));
      }else if(url==="https://api.bgm.tv/v0/me"){
        expect(options.headers?.Authorization).toBe(`Bearer ${fixtureToken}`);
        expect(options.headers?.Cookie).toBeUndefined();
        response=new Response(JSON.stringify(fixtureProfile));
      }else throw new Error("Unexpected outbound destination");
      return{response,finalUrl:new URL(url)};
    },
    async readText(response){return response.text();}
  }};
}
function storeStub():AuthStore&{saved:string|undefined} {
  const users=new Map<string,string>();let claimed=false;
  const store:AuthStore&{saved:string|undefined}={
    saved:undefined,
    async hasOwner(){return claimed;},async createOwner(){claimed=true;return"owner";},async recoverOwner(){return"owner";},
    async createWebSession(user,token){users.set(token,user);},async webUser(token){return users.get(token);},async deleteWebSession(token){users.delete(token);},
    async createPairing(){},async pairingStatus(){return"pending";},async approvePairing(){},async claimPairing(){return"00000000-0000-4000-8000-000000000001";},async deviceUser(){return undefined;},
    async credential(){return store.saved?{encrypted:store.saved,profile:fixtureProfile,revision:"1"}:undefined;},
    async saveCredential(_user,encrypted){store.saved=encrypted;},async unlink(){store.saved=undefined;}
  };return store;
}
describe("Bangumi website login without OAuth credentials",()=>{
  it("keeps the same first-party session, does not follow a login redirect, verifies only the personal token",async()=>{
    const fixture=website();const login=new BangumiWebLogin(fixture.transport);
    expect((await login.captcha()).contentType).toBe("image/gif");
    const result=await login.login("fixture@example.invalid",fixturePassword,"1234");
    expect(result.profile.id).toBe(42);
    expect(fixture.calls.map(c=>new URL(c.url).host)).toEqual(["bgm.tv","bgm.tv","bgm.tv","next.bgm.tv","api.bgm.tv"]);
    expect(fixture.calls.every(c=>!c.body?.includes("client_secret")&&!c.body?.includes("client_id"))).toBe(true);
    await expect(login.login("fixture@example.invalid",fixturePassword,"1234")).rejects.toMatchObject({code:"BGM_CAPTCHA_REQUIRED"});
  });
  it("rejects wrong credentials/captcha without manufacturing a token and requires a fresh challenge",async()=>{
    const fixture=website(true);const login=new BangumiWebLogin(fixture.transport);await login.captcha();
    await expect(login.login("fixture@example.invalid",fixturePassword,"bad")).rejects.toMatchObject({code:"BGM_LOGIN_REJECTED"});
    expect(fixture.calls.some(c=>c.url.includes("/demo/access-tokens"))).toBe(false);
    await expect(login.login("fixture@example.invalid",fixturePassword,"bad")).rejects.toMatchObject({code:"BGM_CAPTCHA_REQUIRED"});
  });
  it("encrypts the credential with independent nonces and authenticates the stored ciphertext",async()=>{
    const store=storeStub();const service=new AuthService(store,Buffer.alloc(32,17),()=>new BangumiWebLogin(website().transport));
    await service.captcha("owner");await service.login("owner","fixture@example.invalid",fixturePassword,"1234");
    expect(store.saved).not.toContain(fixtureToken);expect(store.saved).not.toContain(fixturePassword);
    expect(service.decrypt(store.saved!)).toBe(fixtureToken);
    expect(service.encrypt(fixtureToken)).not.toBe(store.saved);
    const other=new AuthService(store,Buffer.alloc(32,18));expect(()=>other.decrypt(store.saved!)).toThrow();
  });
  it("an old login completion cannot reattach an account after explicit unlink",async()=>{
    let release:(value:{token:string;profile:Profile})=>void=()=>{};
    const pending=new Promise<{token:string;profile:Profile}>(resolve=>{release=resolve;});
    class Delayed extends BangumiWebLogin {override async captcha(){return{bytes:Buffer.from("fixture"),contentType:"image/png"};}override async login(){return pending;}}
    const store=storeStub();const service=new AuthService(store,Buffer.alloc(32,17),()=>new Delayed());
    await service.captcha("owner");const login=service.login("owner","fixture@example.invalid",fixturePassword,"1234");
    await service.unlink("owner");release({token:fixtureToken,profile:fixtureProfile});
    await expect(login).rejects.toMatchObject({statusCode:401});expect(store.saved).toBeUndefined();
  });
  it("browser setup enforces origin, CSRF and a one-use nonce; unpaired account reads are denied",async()=>{
    const store=storeStub();const service=new AuthService(store,Buffer.alloc(32,17));
    const app=createApp({config:testConfig({HUB_SETUP_SECRET:""}),authService:service,readiness:{async check(){throw new Error("not used");}}});
    try{
      const get=await app.inject({url:"/"});expect(get.statusCode).toBe(200);
      const cookie=String(get.headers["set-cookie"]).split(";")[0]!;
      const csrf=/name="csrf" value="([^"]+)"/.exec(get.body)![1]!;
      const payload=new URLSearchParams({csrf}).toString();
      const foreign=await app.inject({method:"POST",url:"/setup",headers:{cookie,origin:"https://evil.example","content-type":"application/x-www-form-urlencoded"},payload});expect(foreign.statusCode).toBe(403);
      const setup=await app.inject({method:"POST",url:"/setup",headers:{cookie,"content-type":"application/x-www-form-urlencoded"},payload});expect(setup.statusCode).toBe(303);
      const replay=await app.inject({method:"POST",url:"/setup",headers:{cookie,"content-type":"application/x-www-form-urlencoded"},payload});expect(replay.statusCode).toBe(403);
      expect((await app.inject({url:"/v1/account"})).statusCode).toBe(401);
    }finally{await app.close();}
  });
});
