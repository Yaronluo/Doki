import { createHash, randomBytes } from "node:crypto";
import type { Pool } from "pg";
import { ApiHttpError } from "../api/errors.js";
export const hash = (value: string): string => createHash("sha256").update(value).digest("hex");
export const secret = (): string => randomBytes(32).toString("base64url");
export interface Profile { id: number; username: string; nickname: string; avatar?: string }
export interface Credential { encrypted: string; profile: Profile; revision: string }
export interface AuthStore {
  hasOwner(): Promise<boolean>;
  createOwner(): Promise<string>;
  recoverOwner(): Promise<string>;
  createWebSession(userId: string, tokenHash: string): Promise<void>;
  webUser(tokenHash: string): Promise<string | undefined>;
  deleteWebSession(tokenHash: string): Promise<void>;
  createPairing(id: string, codeHash: string, secretHash: string, name: string): Promise<void>;
  pairingStatus(id: string, secretHash: string): Promise<string>;
  approvePairing(codeHash: string, userId: string): Promise<void>;
  claimPairing(id: string, secretHash: string, tokenHash: string): Promise<string>;
  deviceUser(tokenHash: string): Promise<string | undefined>;
  credential(userId: string): Promise<Credential | undefined>;
  saveCredential(userId: string, encrypted: string, profile: Profile): Promise<void>;
  unlink(userId: string): Promise<void>;
}
const conflict = () => new ApiHttpError({ statusCode: 409, code: "PAIRING_UNAVAILABLE", message: "配对已失效或已领取，请重新发起。", retryable: false });
export class PgAuthStore implements AuthStore {
  constructor(readonly pool: Pool) {}
  async hasOwner() { return (await this.pool.query("SELECT 1 FROM hub_user WHERE owner_claimed_at IS NOT NULL LIMIT 1")).rowCount !== 0; }
  async createOwner(): Promise<string> {
    const client = await this.pool.connect();
    try {
      await client.query("BEGIN"); await client.query("SELECT pg_advisory_xact_lock(884919)");
      if ((await client.query("SELECT 1 FROM hub_user WHERE owner_claimed_at IS NOT NULL")).rowCount) throw conflict();
      const row = await client.query<{ id: string }>("INSERT INTO hub_user(display_name,owner_claimed_at) VALUES('Doki owner',now()) RETURNING id");
      await client.query("COMMIT"); return row.rows[0]!.id;
    } catch (error) { await client.query("ROLLBACK"); throw error; } finally { client.release(); }
  }
  async recoverOwner(): Promise<string> {
    const row=(await this.pool.query<{id:string}>("SELECT id FROM hub_user WHERE owner_claimed_at IS NOT NULL LIMIT 1")).rows[0];
    if(!row) throw conflict();
    await this.pool.query("DELETE FROM hub_web_session WHERE user_id=$1",[row.id]);
    return row.id;
  }
  async createWebSession(userId: string, tokenHash: string) { await this.pool.query("DELETE FROM hub_web_session WHERE expires_at < now()"); await this.pool.query("INSERT INTO hub_web_session(token_hash,user_id,expires_at) VALUES($1,$2,now()+interval '7 days')", [tokenHash,userId]); }
  async webUser(tokenHash: string) { return (await this.pool.query<{ user_id: string }>("SELECT user_id FROM hub_web_session WHERE token_hash=$1 AND expires_at>now()",[tokenHash])).rows[0]?.user_id; }
  async deleteWebSession(tokenHash: string) { await this.pool.query("DELETE FROM hub_web_session WHERE token_hash=$1",[tokenHash]); }
  async createPairing(id: string, codeHash: string, secretHash: string, name: string) { await this.pool.query("DELETE FROM pairing WHERE expires_at < now() - interval '1 day'"); await this.pool.query("INSERT INTO pairing(id,code_hash,secret_hash,expires_at,device_name) VALUES($1,$2,$3,now()+interval '10 minutes',$4)",[id,codeHash,secretHash,name]); }
  async pairingStatus(id: string, secretHash: string) {
    const row=(await this.pool.query<{ status: string }>("SELECT status FROM pairing WHERE id=$1 AND secret_hash=$2 AND expires_at>now()",[id,secretHash])).rows[0];
    if (!row) throw conflict(); return row.status;
  }
  async approvePairing(codeHash: string, userId: string) { const result=await this.pool.query("UPDATE pairing SET user_id=$2,status='approved',approved_at=now() WHERE code_hash=$1 AND status='pending' AND expires_at>now()",[codeHash,userId]); if (!result.rowCount) throw conflict(); }
  async claimPairing(id: string, secretHash: string, tokenHash: string): Promise<string> {
    const client=await this.pool.connect();
    try {
      await client.query("BEGIN");
      const row=(await client.query<{ user_id: string; device_name: string }>("SELECT user_id,device_name FROM pairing WHERE id=$1 AND secret_hash=$2 AND status='approved' AND expires_at>now() FOR UPDATE",[id,secretHash])).rows[0];
      if (!row) throw conflict();
      const device=(await client.query<{ id: string }>("INSERT INTO device(user_id,name,token_hash) VALUES($1,$2,$3) RETURNING id",[row.user_id,row.device_name,tokenHash])).rows[0]!;
      await client.query("UPDATE pairing SET device_id=$2,status='claimed',claimed_at=now() WHERE id=$1",[id,device.id]);
      await client.query("COMMIT"); return device.id;
    } catch (error) { await client.query("ROLLBACK"); throw error; } finally { client.release(); }
  }
  async deviceUser(tokenHash: string) { return (await this.pool.query<{ user_id: string }>("SELECT user_id FROM device WHERE token_hash=$1 AND status='active'",[tokenHash])).rows[0]?.user_id; }
  async credential(userId: string): Promise<Credential | undefined> {
    const row=(await this.pool.query<{ access_token_encrypted: string; revision: string; profile: Profile }>("SELECT c.access_token_encrypted,c.revision,s.payload AS profile FROM oauth_credential c JOIN upstream_snapshot s ON s.user_id=c.user_id AND s.entity_type='bangumi_profile' AND s.entity_id='self' WHERE c.user_id=$1 AND c.provider='bangumi'",[userId])).rows[0];
    return row ? { encrypted: row.access_token_encrypted, profile: row.profile, revision: row.revision } : undefined;
  }
  async saveCredential(userId: string, encrypted: string, profile: Profile) {
    const client=await this.pool.connect();
    try { await client.query("BEGIN");
      await client.query("INSERT INTO oauth_credential(user_id,provider,access_token_encrypted,token_type,expires_at) VALUES($1,'bangumi',$2,'personal',NULL) ON CONFLICT(user_id,provider) DO UPDATE SET access_token_encrypted=excluded.access_token_encrypted,token_type='personal',expires_at=excluded.expires_at,revision=oauth_credential.revision+1,updated_at=now()",[userId,encrypted]);
      await client.query("INSERT INTO upstream_snapshot(user_id,entity_type,entity_id,payload) VALUES($1,'bangumi_profile','self',$2) ON CONFLICT(user_id,entity_type,entity_id) DO UPDATE SET payload=excluded.payload,fetched_at=now()",[userId,JSON.stringify(profile)]);
      await client.query("COMMIT");
    } catch (error) { await client.query("ROLLBACK"); throw error; } finally { client.release(); }
  }
  async unlink(userId: string) { await this.pool.query("DELETE FROM oauth_credential WHERE user_id=$1 AND provider='bangumi'",[userId]); }
}
