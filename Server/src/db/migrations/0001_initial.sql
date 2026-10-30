-- HUB-001 initial schema.
--
-- Stable identity (Bangumi IDs), provider/source mappings, playback sessions,
-- progress events, watch state, sync outbox/cursors, danmaku state and durable
-- jobs are separate concerns. There is no ORM in this project; these
-- constraints are the database contract.

-- ---------------------------------------------------------------------------
-- Identity, devices, pairing and OAuth
-- ---------------------------------------------------------------------------

CREATE TABLE hub_user (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  display_name text NOT NULL CHECK (char_length(display_name) BETWEEN 1 AND 100),
  owner_claimed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE device (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES hub_user (id) ON DELETE CASCADE,
  name text NOT NULL CHECK (char_length(name) BETWEEN 1 AND 100),
  platform text NOT NULL DEFAULT 'tvOS'
    CHECK (platform IN ('tvOS', 'web', 'other')),
  token_hash text NOT NULL UNIQUE CHECK (char_length(token_hash) >= 32),
  status text NOT NULL DEFAULT 'active'
    CHECK (status IN ('pending', 'active', 'revoked')),
  created_at timestamptz NOT NULL DEFAULT now(),
  last_seen_at timestamptz,
  revoked_at timestamptz,
  CONSTRAINT device_revoked_at_matches_status
    CHECK ((status = 'revoked') = (revoked_at IS NOT NULL))
);

CREATE INDEX device_user_status_idx ON device (user_id, status);

CREATE TABLE pairing (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  device_id uuid REFERENCES device (id) ON DELETE CASCADE,
  user_id uuid REFERENCES hub_user (id) ON DELETE CASCADE,
  code_hash text NOT NULL UNIQUE CHECK (char_length(code_hash) >= 16),
  secret_hash text NOT NULL CHECK (char_length(secret_hash) >= 32),
  status text NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'approved', 'claimed', 'expired', 'cancelled')),
  attempts integer NOT NULL DEFAULT 0 CHECK (attempts >= 0),
  expires_at timestamptz NOT NULL,
  approved_at timestamptz,
  claimed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT pairing_expiry_after_creation CHECK (expires_at > created_at),
  CONSTRAINT pairing_approved_has_owner
    CHECK (status <> 'approved' OR (user_id IS NOT NULL AND approved_at IS NOT NULL)),
  CONSTRAINT pairing_claimed_has_timestamp
    CHECK (status <> 'claimed' OR claimed_at IS NOT NULL)
);

CREATE INDEX pairing_status_expires_idx ON pairing (status, expires_at);

CREATE TABLE oauth_transaction (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES hub_user (id) ON DELETE CASCADE,
  device_id uuid REFERENCES device (id) ON DELETE SET NULL,
  provider text NOT NULL CHECK (provider IN ('bangumi')),
  state_hash text NOT NULL UNIQUE CHECK (char_length(state_hash) >= 32),
  code_verifier_encrypted text,
  return_path text CHECK (return_path IS NULL OR return_path LIKE '/%'),
  status text NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'consumed', 'expired', 'failed')),
  expires_at timestamptz NOT NULL,
  consumed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT oauth_transaction_expiry_after_creation CHECK (expires_at > created_at),
  CONSTRAINT oauth_transaction_consumed_has_timestamp
    CHECK (status <> 'consumed' OR consumed_at IS NOT NULL)
);

CREATE INDEX oauth_transaction_status_expires_idx
  ON oauth_transaction (status, expires_at);
CREATE INDEX oauth_transaction_user_provider_idx
  ON oauth_transaction (user_id, provider);

CREATE TABLE oauth_credential (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES hub_user (id) ON DELETE CASCADE,
  provider text NOT NULL CHECK (provider IN ('bangumi')),
  access_token_encrypted text NOT NULL,
  refresh_token_encrypted text,
  token_type text,
  scope text,
  expires_at timestamptz,
  revision bigint NOT NULL DEFAULT 1 CHECK (revision > 0),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, provider)
);

-- ---------------------------------------------------------------------------
-- Metadata and external mappings
-- ---------------------------------------------------------------------------

CREATE TABLE subject (
  bgm_subject_id bigint PRIMARY KEY CHECK (bgm_subject_id > 0),
  media_type text NOT NULL
    CHECK (media_type IN ('tv', 'movie', 'ova', 'web', 'other')),
  title text NOT NULL CHECK (char_length(title) BETWEEN 1 AND 500),
  title_original text,
  summary text,
  air_date date,
  image_url text,
  fetched_at timestamptz,
  revision bigint NOT NULL DEFAULT 1 CHECK (revision > 0),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE episode (
  bgm_episode_id bigint PRIMARY KEY CHECK (bgm_episode_id > 0),
  bgm_subject_id bigint NOT NULL REFERENCES subject (bgm_subject_id) ON DELETE CASCADE,
  kind text NOT NULL DEFAULT 'main'
    CHECK (kind IN ('main', 'sp', 'op', 'ed', 'other')),
  sort_number numeric(10, 3) NOT NULL,
  title text,
  air_date date,
  revision bigint NOT NULL DEFAULT 1 CHECK (revision > 0),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (bgm_subject_id, kind, sort_number)
);

CREATE INDEX episode_subject_sort_idx ON episode (bgm_subject_id, sort_number);

CREATE TABLE external_binding (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  subject_id bigint NOT NULL REFERENCES subject (bgm_subject_id) ON DELETE CASCADE,
  provider text NOT NULL CHECK (provider IN ('tmdb', 'bangumi', 'other')),
  media_type text NOT NULL CHECK (media_type IN ('tv', 'movie', 'other')),
  external_id text NOT NULL CHECK (char_length(external_id) BETWEEN 1 AND 200),
  season integer CHECK (season IS NULL OR season >= 0),
  provenance text,
  confidence numeric(4, 3) CHECK (confidence IS NULL OR confidence BETWEEN 0 AND 1),
  verified boolean NOT NULL DEFAULT false,
  revision bigint NOT NULL DEFAULT 1 CHECK (revision > 0),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE NULLS NOT DISTINCT (subject_id, provider, media_type, external_id, season)
);

CREATE INDEX external_binding_subject_idx ON external_binding (subject_id);

CREATE TABLE episode_external_mapping (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  bgm_episode_id bigint NOT NULL REFERENCES episode (bgm_episode_id) ON DELETE CASCADE,
  binding_id uuid NOT NULL REFERENCES external_binding (id) ON DELETE CASCADE,
  external_episode_id text,
  season integer CHECK (season IS NULL OR season >= 0),
  episode integer CHECK (episode IS NULL OR episode >= 0),
  revision bigint NOT NULL DEFAULT 1 CHECK (revision > 0),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE NULLS NOT DISTINCT (bgm_episode_id, binding_id, season, episode)
);

-- ---------------------------------------------------------------------------
-- Providers and source mappings
-- ---------------------------------------------------------------------------

CREATE TABLE provider (
  provider_id text PRIMARY KEY CHECK (char_length(provider_id) BETWEEN 1 AND 100),
  display_name text NOT NULL,
  implementation_version text NOT NULL,
  enabled boolean NOT NULL DEFAULT false,
  capabilities jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE source_subject (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  provider_id text NOT NULL REFERENCES provider (provider_id) ON DELETE CASCADE,
  source_subject_key text NOT NULL CHECK (char_length(source_subject_key) BETWEEN 1 AND 500),
  canonical_url text,
  title text,
  verified boolean NOT NULL DEFAULT false,
  revision bigint NOT NULL DEFAULT 1 CHECK (revision > 0),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (provider_id, source_subject_key)
);

CREATE TABLE source_episode (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  provider_id text NOT NULL REFERENCES provider (provider_id) ON DELETE CASCADE,
  source_subject_id uuid NOT NULL REFERENCES source_subject (id) ON DELETE CASCADE,
  media_id text NOT NULL CHECK (char_length(media_id) BETWEEN 1 AND 500),
  source_subject_key text NOT NULL CHECK (char_length(source_subject_key) BETWEEN 1 AND 500),
  channel text,
  episode_hint text,
  title text,
  parser_version text,
  revision bigint NOT NULL DEFAULT 1 CHECK (revision > 0),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (provider_id, media_id)
);

CREATE INDEX source_episode_subject_idx ON source_episode (source_subject_id);

CREATE TABLE subject_source_binding (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES hub_user (id) ON DELETE CASCADE,
  subject_id bigint NOT NULL REFERENCES subject (bgm_subject_id) ON DELETE CASCADE,
  provider_id text NOT NULL REFERENCES provider (provider_id) ON DELETE CASCADE,
  source_subject_key text NOT NULL,
  verified boolean NOT NULL DEFAULT false,
  revision bigint NOT NULL DEFAULT 1 CHECK (revision > 0),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, subject_id, provider_id, source_subject_key)
);

CREATE TABLE episode_source_mapping (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES hub_user (id) ON DELETE CASCADE,
  bgm_episode_id bigint NOT NULL REFERENCES episode (bgm_episode_id) ON DELETE CASCADE,
  source_episode_id uuid NOT NULL REFERENCES source_episode (id) ON DELETE CASCADE,
  confidence numeric(4, 3) CHECK (confidence IS NULL OR confidence BETWEEN 0 AND 1),
  verified boolean NOT NULL DEFAULT false,
  revision bigint NOT NULL DEFAULT 1 CHECK (revision > 0),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, bgm_episode_id, source_episode_id)
);

-- ---------------------------------------------------------------------------
-- Playback sessions, progress events and checkpoints
-- ---------------------------------------------------------------------------

CREATE TABLE playback_session (
  id text PRIMARY KEY CHECK (char_length(id) BETWEEN 1 AND 100),
  user_id uuid NOT NULL REFERENCES hub_user (id) ON DELETE CASCADE,
  device_id uuid NOT NULL REFERENCES device (id) ON DELETE CASCADE,
  bgm_episode_id bigint NOT NULL REFERENCES episode (bgm_episode_id) ON DELETE CASCADE,
  status text NOT NULL DEFAULT 'locating'
    CHECK (status IN (
      'locating', 'resolving', 'preparing', 'ready', 'playing', 'paused',
      'seeking', 'buffering', 'recovering', 'failed', 'closed', 'cancelled'
    )),
  generation bigint NOT NULL DEFAULT 1 CHECK (generation > 0),
  write_epoch bigint NOT NULL DEFAULT 1 CHECK (write_epoch > 0),
  resume_revision bigint NOT NULL DEFAULT 0 CHECK (resume_revision >= 0),
  current_source_episode_id uuid REFERENCES source_episode (id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  last_activity_at timestamptz NOT NULL DEFAULT now(),
  closed_at timestamptz
);

CREATE INDEX playback_session_user_episode_idx
  ON playback_session (user_id, bgm_episode_id, created_at DESC);
CREATE INDEX playback_session_device_status_idx
  ON playback_session (device_id, status);

CREATE TABLE progress_event (
  event_id uuid PRIMARY KEY,
  session_id text NOT NULL REFERENCES playback_session (id) ON DELETE CASCADE,
  device_id uuid NOT NULL REFERENCES device (id) ON DELETE CASCADE,
  device_seq bigint NOT NULL CHECK (device_seq > 0),
  write_epoch bigint NOT NULL CHECK (write_epoch > 0),
  base_revision bigint NOT NULL CHECK (base_revision >= 0),
  bgm_episode_id bigint NOT NULL REFERENCES episode (bgm_episode_id) ON DELETE CASCADE,
  kind text NOT NULL CHECK (kind IN ('progress', 'pause', 'seekCompleted', 'ended')),
  position_seconds numeric(14, 3) NOT NULL,
  duration_seconds numeric(14, 3),
  client_occurred_at timestamptz NOT NULL,
  server_received_at timestamptz NOT NULL DEFAULT now(),
  status text NOT NULL DEFAULT 'accepted'
    CHECK (status IN ('accepted', 'duplicate', 'conflict')),
  resulting_revision bigint CHECK (resulting_revision IS NULL OR resulting_revision >= 0),
  CONSTRAINT progress_event_position_range
    CHECK (position_seconds >= 0 AND position_seconds <= 1000000000),
  CONSTRAINT progress_event_duration_range
    CHECK (duration_seconds IS NULL OR
      (duration_seconds > 0 AND duration_seconds <= 1000000000)),
  CONSTRAINT progress_event_position_within_duration
    CHECK (duration_seconds IS NULL OR position_seconds <= duration_seconds),
  UNIQUE (session_id, device_seq)
);

CREATE INDEX progress_event_session_received_idx
  ON progress_event (session_id, server_received_at);
CREATE INDEX progress_event_episode_idx
  ON progress_event (bgm_episode_id, server_received_at);

CREATE TABLE device_checkpoint (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES hub_user (id) ON DELETE CASCADE,
  device_id uuid NOT NULL REFERENCES device (id) ON DELETE CASCADE,
  bgm_episode_id bigint NOT NULL REFERENCES episode (bgm_episode_id) ON DELETE CASCADE,
  session_id text REFERENCES playback_session (id) ON DELETE SET NULL,
  position_seconds numeric(14, 3) NOT NULL,
  duration_seconds numeric(14, 3),
  timeline_id text,
  revision bigint NOT NULL DEFAULT 0 CHECK (revision >= 0),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT device_checkpoint_position_range
    CHECK (position_seconds >= 0 AND position_seconds <= 1000000000),
  CONSTRAINT device_checkpoint_duration_range
    CHECK (duration_seconds IS NULL OR
      (duration_seconds > 0 AND duration_seconds <= 1000000000)),
  UNIQUE (device_id, bgm_episode_id)
);

CREATE TABLE episode_progress (
  user_id uuid NOT NULL REFERENCES hub_user (id) ON DELETE CASCADE,
  bgm_episode_id bigint NOT NULL REFERENCES episode (bgm_episode_id) ON DELETE CASCADE,
  position_seconds numeric(14, 3) NOT NULL DEFAULT 0,
  duration_seconds numeric(14, 3),
  furthest_position numeric(14, 3) NOT NULL DEFAULT 0,
  resume_revision bigint NOT NULL DEFAULT 0 CHECK (resume_revision >= 0),
  write_epoch bigint NOT NULL DEFAULT 1 CHECK (write_epoch > 0),
  active_session_id text REFERENCES playback_session (id) ON DELETE SET NULL,
  timeline_id text,
  updated_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, bgm_episode_id),
  CONSTRAINT episode_progress_position_range
    CHECK (position_seconds >= 0 AND position_seconds <= 1000000000),
  CONSTRAINT episode_progress_furthest_range
    CHECK (furthest_position >= 0 AND furthest_position <= 1000000000),
  CONSTRAINT episode_progress_duration_range
    CHECK (duration_seconds IS NULL OR
      (duration_seconds > 0 AND duration_seconds <= 1000000000))
);

-- ---------------------------------------------------------------------------
-- Watch state and upstream snapshots
-- ---------------------------------------------------------------------------

CREATE TABLE watch_state (
  user_id uuid NOT NULL REFERENCES hub_user (id) ON DELETE CASCADE,
  bgm_episode_id bigint NOT NULL REFERENCES episode (bgm_episode_id) ON DELETE CASCADE,
  state text NOT NULL CHECK (state IN ('watched', 'unwatched')),
  intent_source text NOT NULL CHECK (intent_source IN ('user', 'auto')),
  revision bigint NOT NULL DEFAULT 1 CHECK (revision > 0),
  updated_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, bgm_episode_id)
);

CREATE TABLE collection_intent (
  user_id uuid NOT NULL REFERENCES hub_user (id) ON DELETE CASCADE,
  bgm_subject_id bigint NOT NULL REFERENCES subject (bgm_subject_id) ON DELETE CASCADE,
  intent jsonb NOT NULL DEFAULT '{}'::jsonb,
  revision bigint NOT NULL DEFAULT 1 CHECK (revision > 0),
  updated_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, bgm_subject_id)
);

CREATE TABLE upstream_snapshot (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES hub_user (id) ON DELETE CASCADE,
  entity_type text NOT NULL,
  entity_id text NOT NULL,
  payload jsonb NOT NULL DEFAULT '{}'::jsonb,
  fetched_at timestamptz NOT NULL DEFAULT now(),
  expires_at timestamptz,
  UNIQUE (user_id, entity_type, entity_id)
);

-- ---------------------------------------------------------------------------
-- Sync clock, changes, outbox and issues
-- ---------------------------------------------------------------------------

CREATE TABLE user_sync_clock (
  user_id uuid PRIMARY KEY REFERENCES hub_user (id) ON DELETE CASCADE,
  revision bigint NOT NULL DEFAULT 0 CHECK (revision >= 0),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE sync_change (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES hub_user (id) ON DELETE CASCADE,
  revision bigint NOT NULL CHECK (revision > 0),
  entity_type text NOT NULL,
  entity_id text NOT NULL,
  operation text NOT NULL CHECK (operation IN ('upsert', 'delete')),
  payload jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, revision, entity_type, entity_id, operation)
);

CREATE INDEX sync_change_user_revision_idx ON sync_change (user_id, revision);

CREATE TABLE outbox (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES hub_user (id) ON DELETE CASCADE,
  entity_type text NOT NULL,
  entity_id text NOT NULL,
  field_group text NOT NULL,
  intent_revision bigint NOT NULL CHECK (intent_revision > 0),
  desired_state jsonb NOT NULL DEFAULT '{}'::jsonb,
  status text NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'in_flight', 'succeeded', 'failed', 'discarded')),
  attempts integer NOT NULL DEFAULT 0 CHECK (attempts >= 0),
  next_attempt_at timestamptz NOT NULL DEFAULT now(),
  locked_at timestamptz,
  locked_by text,
  last_error_code text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, entity_type, entity_id, field_group)
);

CREATE INDEX outbox_ready_idx ON outbox (status, next_attempt_at);

CREATE TABLE sync_issue (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES hub_user (id) ON DELETE CASCADE,
  entity_type text NOT NULL,
  entity_id text NOT NULL,
  code text NOT NULL,
  message text NOT NULL,
  details jsonb NOT NULL DEFAULT '{}'::jsonb,
  resolved_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX sync_issue_user_open_idx ON sync_issue (user_id, resolved_at);

-- ---------------------------------------------------------------------------
-- Danmaku mapping, timing and preferences
-- ---------------------------------------------------------------------------

CREATE TABLE episode_danmaku_mapping (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES hub_user (id) ON DELETE CASCADE,
  bgm_episode_id bigint NOT NULL REFERENCES episode (bgm_episode_id) ON DELETE CASCADE,
  danmaku_episode_id text NOT NULL,
  source text NOT NULL CHECK (source IN ('bgmMap', 'search', 'manual')),
  verified boolean NOT NULL DEFAULT false,
  revision bigint NOT NULL DEFAULT 1 CHECK (revision > 0),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, bgm_episode_id),
  CONSTRAINT episode_danmaku_mapping_int64_decimal
    CHECK (danmaku_episode_id ~ '^[1-9][0-9]{0,18}$'
      AND danmaku_episode_id::numeric <= 9223372036854775807)
);

CREATE TABLE danmaku_timing (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES hub_user (id) ON DELETE CASCADE,
  bgm_episode_id bigint NOT NULL REFERENCES episode (bgm_episode_id) ON DELETE CASCADE,
  media_id text NOT NULL CHECK (char_length(media_id) BETWEEN 1 AND 200),
  offset_seconds numeric(8, 3) NOT NULL,
  revision bigint NOT NULL DEFAULT 1 CHECK (revision > 0),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, bgm_episode_id, media_id),
  CONSTRAINT danmaku_timing_offset_range
    CHECK (offset_seconds >= -3600 AND offset_seconds <= 3600)
);

CREATE TABLE danmaku_preferences (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES hub_user (id) ON DELETE CASCADE,
  device_id uuid REFERENCES device (id) ON DELETE CASCADE,
  enabled boolean NOT NULL DEFAULT true,
  density numeric(4, 3) NOT NULL DEFAULT 0.5 CHECK (density BETWEEN 0 AND 1),
  font_scale numeric(4, 3) NOT NULL DEFAULT 1 CHECK (font_scale BETWEEN 0.5 AND 3),
  opacity numeric(4, 3) NOT NULL DEFAULT 0.9 CHECK (opacity BETWEEN 0.1 AND 1),
  area text NOT NULL DEFAULT 'top'
    CHECK (area IN ('top', 'middle', 'bottom', 'full')),
  modes jsonb NOT NULL DEFAULT '["scroll", "top", "bottom"]'::jsonb,
  revision bigint NOT NULL DEFAULT 1 CHECK (revision > 0),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE NULLS NOT DISTINCT (user_id, device_id)
);

-- ---------------------------------------------------------------------------
-- Durable jobs and provider health
-- ---------------------------------------------------------------------------

CREATE TABLE job (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  kind text NOT NULL CHECK (char_length(kind) BETWEEN 1 AND 100),
  payload jsonb NOT NULL DEFAULT '{}'::jsonb,
  status text NOT NULL DEFAULT 'queued'
    CHECK (status IN ('queued', 'running', 'succeeded', 'failed', 'cancelled')),
  priority integer NOT NULL DEFAULT 0,
  run_at timestamptz NOT NULL DEFAULT now(),
  attempts integer NOT NULL DEFAULT 0 CHECK (attempts >= 0),
  max_attempts integer NOT NULL DEFAULT 3 CHECK (max_attempts > 0),
  locked_at timestamptz,
  locked_by text,
  last_error_code text,
  last_error_message text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  finished_at timestamptz,
  CONSTRAINT job_attempts_within_limit CHECK (attempts <= max_attempts)
);

CREATE INDEX job_ready_idx
  ON job (status, run_at, priority DESC)
  WHERE status = 'queued';
CREATE INDEX job_running_locked_idx
  ON job (locked_at)
  WHERE status = 'running';

CREATE TABLE provider_health (
  provider_id text PRIMARY KEY REFERENCES provider (provider_id) ON DELETE CASCADE,
  state text NOT NULL CHECK (state IN ('ready', 'degraded', 'unavailable', 'unknown')),
  checked_at timestamptz NOT NULL DEFAULT now(),
  latency_ms integer CHECK (latency_ms IS NULL OR latency_ms >= 0),
  error_code text,
  details jsonb NOT NULL DEFAULT '{}'::jsonb,
  updated_at timestamptz NOT NULL DEFAULT now()
);
