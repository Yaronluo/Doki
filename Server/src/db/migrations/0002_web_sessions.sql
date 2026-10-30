-- Browser owner sessions and TV display names. Raw browser/device tokens are
-- never stored: SHA-256 hashes authenticate them, and Bangumi credentials are AES-GCM encrypted.
CREATE TABLE hub_web_session (
  token_hash text PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES hub_user(id) ON DELETE CASCADE,
  expires_at timestamptz NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX hub_web_session_expiry_idx ON hub_web_session(expires_at);
ALTER TABLE pairing ADD COLUMN device_name text NOT NULL DEFAULT 'Apple TV';
