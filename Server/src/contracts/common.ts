import { z } from "zod";

/**
 * Largest value representable by a signed 64-bit integer. Danmaku library and
 * comment IDs must be transported as canonical decimal strings because they do
 * not fit in a JavaScript number without precision loss.
 */
export const MAX_INT64_DECIMAL = "9223372036854775807";
const MAX_INT64 = 9_223_372_036_854_775_807n;

export const MAX_SAFE_REVISION = Number.MAX_SAFE_INTEGER;

export const utcIso8601Schema = z.string().refine(
  (value) => {
    const parsed = Date.parse(value);
    return (
      !Number.isNaN(parsed) &&
      /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,3})?Z$/.test(value)
    );
  },
  { message: "must be an ISO8601 UTC timestamp ending in Z" }
);

export const int64DecimalStringSchema = z
  .string()
  .regex(/^[1-9][0-9]{0,18}$/, {
    message: "must be a canonical positive decimal string"
  })
  .refine(
    (value) => {
      if (!/^[1-9][0-9]{0,18}$/.test(value)) {
        return false;
      }
      return BigInt(value) <= MAX_INT64;
    },
    { message: "must fit in a signed 64-bit integer" }
  );

export const nonNegativeIntegerSchema = z
  .number()
  .int()
  .min(0)
  .max(MAX_SAFE_REVISION);

export const positiveIntegerSchema = z
  .number()
  .int()
  .min(1)
  .max(MAX_SAFE_REVISION);

export const secondsSchema = z
  .number()
  .refine(Number.isFinite, { message: "must be finite" })
  .min(0)
  .max(1_000_000_000);

export const signedOffsetSecondsSchema = z
  .number()
  .refine(Number.isFinite, { message: "must be finite" })
  .min(-3_600)
  .max(3_600);

export const uuidSchema = z
  .string()
  .regex(
    /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i,
    { message: "must be a UUID" }
  );

export const jsonObjectSchema = z.record(z.string(), z.unknown());
