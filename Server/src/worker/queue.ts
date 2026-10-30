import type { Pool } from "pg";
import type { Logger } from "../logging/logger.js";

export interface JobRecord {
  readonly id: string;
  readonly kind: string;
  readonly payload: unknown;
  readonly attempts: number;
  readonly maxAttempts: number;
}

export type JobHandler = (job: JobRecord) => Promise<void>;

export interface WorkerOptions {
  readonly pool: Pool;
  readonly logger: Logger;
  readonly workerId: string;
  readonly handlers: ReadonlyMap<string, JobHandler>;
  readonly pollIntervalMs?: number;
  readonly signal?: AbortSignal;
  readonly once?: boolean;
  readonly redact?: (input: string) => string;
}

interface JobRow {
  id: string;
  kind: string;
  payload: unknown;
  attempts: number;
  max_attempts: number;
}

function toJobRecord(row: JobRow): JobRecord {
  return {
    id: row.id,
    kind: row.kind,
    payload: row.payload,
    attempts: row.attempts,
    maxAttempts: row.max_attempts
  };
}

export async function claimNextJob(
  pool: Pool,
  workerId: string
): Promise<JobRecord | null> {
  const client = await pool.connect();
  try {
    await client.query("BEGIN");
    const selected = await client.query<JobRow>(
      `SELECT id, kind, payload, attempts, max_attempts
         FROM job
        WHERE status = 'queued' AND run_at <= now()
        ORDER BY priority DESC, run_at ASC, created_at ASC
        FOR UPDATE SKIP LOCKED
        LIMIT 1`
    );
    const row = selected.rows[0];
    if (row === undefined) {
      await client.query("COMMIT");
      return null;
    }
    const updated = await client.query<JobRow>(
      `UPDATE job
          SET status = 'running',
              attempts = attempts + 1,
              locked_at = now(),
              locked_by = $2,
              updated_at = now()
        WHERE id = $1
        RETURNING id, kind, payload, attempts, max_attempts`,
      [row.id, workerId]
    );
    await client.query("COMMIT");
    const claimed = updated.rows[0];
    return claimed === undefined ? null : toJobRecord(claimed);
  } catch (error) {
    try {
      await client.query("ROLLBACK");
    } catch {
      // Ignore rollback failures; the original error is more useful.
    }
    throw error;
  } finally {
    client.release();
  }
}

export async function succeedJob(pool: Pool, jobId: string): Promise<void> {
  await pool.query(
    `UPDATE job
        SET status = 'succeeded',
            locked_at = NULL,
            locked_by = NULL,
            finished_at = now(),
            updated_at = now()
      WHERE id = $1`,
    [jobId]
  );
}

export async function failJob(
  pool: Pool,
  job: JobRecord,
  input: {
    readonly code: string;
    readonly message: string;
    readonly retryable: boolean;
  }
): Promise<void> {
  if (input.retryable && job.attempts < job.maxAttempts) {
    const backoffSeconds = Math.min(60, 2 ** Math.max(0, job.attempts - 1));
    await pool.query(
      `UPDATE job
          SET status = 'queued',
              run_at = now() + ($2 * interval '1 second'),
              locked_at = NULL,
              locked_by = NULL,
              last_error_code = $3,
              last_error_message = $4,
              updated_at = now()
        WHERE id = $1`,
      [job.id, backoffSeconds, input.code, input.message.slice(0, 500)]
    );
    return;
  }
  await pool.query(
    `UPDATE job
        SET status = 'failed',
            locked_at = NULL,
            locked_by = NULL,
            last_error_code = $2,
            last_error_message = $3,
            finished_at = now(),
            updated_at = now()
      WHERE id = $1`,
    [job.id, input.code, input.message.slice(0, 500)]
  );
}

export async function requeueStaleJobs(
  pool: Pool,
  staleAfterMs: number
): Promise<number> {
  const result = await pool.query(
    `UPDATE job
        SET status = 'queued',
            locked_at = NULL,
            locked_by = NULL,
            updated_at = now()
      WHERE status = 'running'
        AND locked_at < now() - ($1 * interval '1 millisecond')`,
    [staleAfterMs]
  );
  return result.rowCount ?? 0;
}

export async function runWorkerOnce(
  options: WorkerOptions
): Promise<boolean> {
  const job = await claimNextJob(options.pool, options.workerId);
  if (job === null) {
    return false;
  }
  options.logger.info(
    {
      jobId: job.id,
      kind: job.kind,
      attempt: job.attempts,
      maxAttempts: job.maxAttempts
    },
    "job_claimed"
  );
  const handler = options.handlers.get(job.kind);
  if (handler === undefined) {
    await failJob(options.pool, job, {
      code: "JOB_KIND_UNSUPPORTED",
      message: `No handler registered for job kind ${job.kind}`,
      retryable: false
    });
    options.logger.error(
      { jobId: job.id, kind: job.kind, code: "JOB_KIND_UNSUPPORTED" },
      "job_failed"
    );
    return true;
  }
  try {
    await handler(job);
    await succeedJob(options.pool, job.id);
    options.logger.info({ jobId: job.id, kind: job.kind }, "job_succeeded");
  } catch (error) {
    const rawMessage =
      error instanceof Error ? error.message : "job handler failed";
    const safeMessage =
      options.redact === undefined ? rawMessage : options.redact(rawMessage);
    await failJob(options.pool, job, {
      code: "JOB_HANDLER_ERROR",
      message: safeMessage,
      retryable: true
    });
    options.logger.error(
      { err: error, jobId: job.id, kind: job.kind, code: "JOB_HANDLER_ERROR" },
      "job_failed"
    );
  }
  return true;
}

function sleep(ms: number, signal: AbortSignal | undefined): Promise<void> {
  return new Promise((resolve) => {
    if (signal?.aborted === true) {
      resolve();
      return;
    }
    const timer = setTimeout(() => {
      signal?.removeEventListener("abort", onAbort);
      resolve();
    }, ms);
    const onAbort = (): void => {
      clearTimeout(timer);
      resolve();
    };
    signal?.addEventListener("abort", onAbort, { once: true });
  });
}

export async function runWorkerLoop(
  options: WorkerOptions
): Promise<void> {
  const pollIntervalMs = options.pollIntervalMs ?? 2_000;
  const stale = await requeueStaleJobs(options.pool, 15 * 60 * 1_000);
  if (stale > 0) {
    options.logger.warn({ count: stale }, "stale_jobs_requeued");
  }
  while (options.signal?.aborted !== true) {
    let processed: boolean;
    try {
      processed = await runWorkerOnce(options);
    } catch (error) {
      if (options.once === true) {
        throw error;
      }
      options.logger.error({ err: error }, "worker_poll_failed");
      await sleep(pollIntervalMs, options.signal);
      continue;
    }
    if (options.once === true) {
      return;
    }
    if (!processed) {
      await sleep(pollIntervalMs, options.signal);
    }
  }
}
