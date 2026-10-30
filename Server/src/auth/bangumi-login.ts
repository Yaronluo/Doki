import { load } from "cheerio";
import { z } from "zod";
import { SafeFetcher } from "../providers/safe-fetch.js";
import type { FetchTransport } from "../providers/types.js";
import { ApiHttpError } from "../api/errors.js";
import type { Profile } from "./store.js";
const UA = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Safari/605.1.15";
const profileSchema = z.object({ id: z.number().int().positive(), username: z.string().min(1).max(100), nickname: z.string().max(200), avatar: z.object({ large: z.string().optional() }).optional() });
const failed = (code: string, message: string) => new ApiHttpError({ statusCode: 422, code, message, retryable: true });
interface Cookie { name: string; value: string; domain: string; path: string }
export class BangumiWebLogin {
  readonly #cookies = new Map<string, Cookie>();
  #formhash: string | undefined;
  constructor(readonly transport: FetchTransport = new SafeFetcher({ timeoutMs: 15000, maxRedirects: 0 })) {}
  async #request(url: string, body?: string, bearer?: string): Promise<Response> {
    const target = new URL(url);
    if (!["https://bgm.tv", "https://next.bgm.tv", "https://api.bgm.tv"].includes(target.origin)) throw new Error("Invalid Bangumi origin");
    const headers: Record<string,string> = { "User-Agent": UA, Accept: "text/html,application/json,image/*" };
    if (bearer) headers.Authorization = `Bearer ${bearer}`;
    else {
      const cookies = [...this.#cookies.values()].filter(c => (target.hostname === c.domain || target.hostname.endsWith(`.${c.domain}`)) && target.pathname.startsWith(c.path));
      if (cookies.length) headers.Cookie = cookies.map(c => `${c.name}=${c.value}`).join("; ");
    }
    if (body !== undefined) { headers["Content-Type"] = "application/x-www-form-urlencoded"; headers.Origin = "https://bgm.tv"; headers.Referer = "https://bgm.tv/login"; }
    let response: Response;
    try { response = (await this.transport.fetch(url, { headers, method: body === undefined ? "GET" : "POST", ...(body === undefined ? {} : { body }), followRedirects: false })).response; }
    catch { throw failed("BGM_UNREACHABLE", "暂时无法连接 Bangumi 官网，请稍后重试。"); }
    for (const value of response.headers.getSetCookie()) {
      const [first, ...attributes] = value.split(";");
      const split = first?.indexOf("=") ?? -1;
      if (split <= 0) continue;
      const name = first!.slice(0,split).trim(); const content = first!.slice(split+1).trim();
      if (!/^[A-Za-z0-9_]+$/.test(name) || /[\r\n;]/.test(content)) continue;
      let domain = target.hostname; let path = "/";
      for (const attribute of attributes) {
        const [key,...parts] = attribute.trim().split("="); const val=parts.join("=").trim();
        if (key?.toLowerCase() === "domain") domain=val.replace(/^\./,"").toLowerCase();
        if (key?.toLowerCase() === "path" && val.startsWith("/")) path=val;
      }
      if (!["bgm.tv", "next.bgm.tv", "api.bgm.tv"].includes(domain) || !(target.hostname === domain || target.hostname.endsWith(`.${domain}`))) continue;
      const cookieKey = `${domain}:${path}:${name}`;
      if (!content || content === "deleted" || attributes.some(a => /^\s*max-age=0$/i.test(a))) this.#cookies.delete(cookieKey);
      else this.#cookies.set(cookieKey,{name,value:content,domain,path});
    }
    return response;
  }
  async captcha(): Promise<{ bytes: Buffer; contentType: string }> {
    this.#formhash = undefined;
    this.#cookies.clear();
    const page = await this.#request("https://bgm.tv/login");
    if (page.status !== 200) throw failed("BGM_LOGIN_PAGE_UNAVAILABLE", "Bangumi 登录页暂时不可用。");
    const html = await this.transport.readText(page, { maxBytes: 1024 * 1024 });
    this.#formhash = load(html)('input[name="formhash"]').attr("value");
    if (!this.#formhash || this.#formhash.length > 128) throw failed("BGM_LOGIN_PAGE_CHANGED", "Bangumi 登录页面已变化，需要更新适配。");
    const image = await this.#request(`https://bgm.tv/signup/captcha?${Date.now()}`);
    const contentType = image.headers.get("content-type")?.split(";")[0] ?? "";
    if (image.status !== 200 || !["image/gif","image/png","image/jpeg","image/webp"].includes(contentType)) throw failed("BGM_CAPTCHA_UNAVAILABLE", "验证码暂时无法加载，请刷新。");
    const bytes = Buffer.from(await image.arrayBuffer());
    if (bytes.length > 512 * 1024) throw failed("BGM_CAPTCHA_INVALID", "验证码响应异常。");
    return { bytes, contentType };
  }
  async login(email: string, password: string, captcha: string): Promise<{ token: string; profile: Profile }> {
    const formhash = this.#formhash; this.#formhash = undefined;
    if (!formhash) throw failed("BGM_CAPTCHA_REQUIRED", "请先加载新的验证码。");
    const form = new URLSearchParams({ formhash, referer: "", dreferer: "", email, password, captcha_challenge_field: captcha, loginsubmit: "登录" });
    const response = await this.#request("https://bgm.tv/FollowTheRabbit", form.toString());
    await response.body?.cancel().catch(() => undefined);
    if (![...this.#cookies.values()].some(c => c.name === "chii_auth")) throw failed("BGM_LOGIN_REJECTED", "登录未成功，请检查邮箱、密码和验证码后刷新重试。");
    // Keep the same website User-Agent and first-party cookie session. Only the
    // generated personal token is persisted; neither password nor cookies are saved.
    const target = "https://next.bgm.tv/demo/access-tokens";
    const cookies = [...this.#cookies.values()].filter(c => "next.bgm.tv" === c.domain || "next.bgm.tv".endsWith(`.${c.domain}`));
    const tokenResponse = (await this.transport.fetch(target, { method: "POST", followRedirects: false, headers: { "User-Agent": UA, "Content-Type": "application/json", Cookie: cookies.map(c => `${c.name}=${c.value}`).join("; ") }, body: JSON.stringify({ name: "Doki Hub", days: 365 }) })).response;
    const raw = await this.transport.readText(tokenResponse, { maxBytes: 8192 });
    let token: unknown;
    try { token = JSON.parse(raw); } catch { token = undefined; }
    if (tokenResponse.status !== 200 || typeof token !== "string" || !/^[A-Za-z0-9_-]{16,512}$/.test(token)) throw failed("BGM_TOKEN_FAILED", "网页登录成功，但个人令牌未生成，请稍后重试。");
    this.#cookies.clear();
    return { token, profile: await this.verify(token) };
  }
  async verify(token: string): Promise<Profile> {
    const response = await this.#request("https://api.bgm.tv/v0/me", undefined, token);
    if (response.status !== 200) throw failed("BGM_TOKEN_REJECTED", "个人令牌校验失败，请重新登录。");
    let payload: unknown;
    try { payload = JSON.parse(await this.transport.readText(response, { maxBytes: 65536 })); } catch { throw failed("BGM_PROFILE_INVALID", "Bangumi 账号响应异常。"); }
    const parsed = profileSchema.safeParse(payload);
    if (!parsed.success) throw failed("BGM_PROFILE_INVALID", "Bangumi 账号响应异常。");
    const avatar=parsed.data.avatar?.large;
    return { id: parsed.data.id, username: parsed.data.username, nickname: parsed.data.nickname, ...(avatar?.startsWith("https://lain.bgm.tv/") ? { avatar } : {}) };
  }
  clear(): void { this.#cookies.clear(); this.#formhash = undefined; }
}
