import { describe, expect, it } from "vitest";
import { int64DecimalStringSchema } from "../src/contracts/common.js";
import {
  danmakuItemSchema,
  danmakuLoadSchema
} from "../src/contracts/danmaku.js";
import {
  playbackPlanSchema,
  type PlaybackPlan
} from "../src/contracts/playback.js";
import { progressEventSchema } from "../src/contracts/progress.js";

const validEvent = {
  eventId: "123e4567-e89b-42d3-a456-426614174000",
  sessionId: "ps_example",
  deviceSeq: 42,
  writeEpoch: 7,
  baseRevision: 18,
  kind: "seekCompleted",
  positionSeconds: 305.5,
  durationSeconds: 1440,
  clientOccurredAt: "2026-10-29T14:00:00Z"
};

const validPlaybackPlan: PlaybackPlan = {
  sessionId: "ps_example",
  episodeId: 1024,
  status: "ready",
  resumeAtSeconds: 312.5,
  resumeRevision: 18,
  writeEpoch: 7,
  source: {
    sourceId: "se_example",
    mode: "relay",
    url: "https://hub.example.com/s/ps_example/manifest",
    expiresAt: "2026-10-29T16:00:00Z"
  },
  tracks: {
    subtitleLanguages: ["zh-Hans"],
    hasAlternateAudio: false
  },
  capabilities: {
    canSeek: true,
    canAutoFailover: false
  }
};

describe("int64 danmaku identifiers", () => {
  it("accepts a decimal string at the signed 64-bit boundary", () => {
    expect(int64DecimalStringSchema.safeParse("9223372036854775807").success).toBe(
      true
    );
    expect(
      danmakuItemSchema.safeParse({
        id: "9223372036854775806",
        timeSeconds: 12.34,
        mode: "scroll",
        colorRgb: 16777215,
        text: "self-made fixture comment"
      }).success
    ).toBe(true);
  });

  it("rejects a JavaScript number even when it looks like an int64", () => {
    const parsed = danmakuItemSchema.safeParse({
      id: 9_223_372_036_854_775_806,
      timeSeconds: 12.34,
      mode: "scroll",
      colorRgb: 16777215,
      text: "number must not be accepted"
    });
    expect(parsed.success).toBe(false);
  });

  it("rejects out-of-range, leading-zero, negative and non-decimal strings", () => {
    for (const value of [
      "9223372036854775808",
      "09223372036854775807",
      "-1",
      "12.5",
      "1e3",
      ""
    ]) {
      expect(int64DecimalStringSchema.safeParse(value).success).toBe(false);
    }
  });

  it("parses a normalized danmaku load with mapping revision and truncation", () => {
    const parsed = danmakuLoadSchema.safeParse({
      loadId: "dl_example",
      status: "ready",
      bgmEpisodeId: 1024,
      danmakuEpisodeId: "123450001",
      mappingRevision: 1,
      contentRevision: "dc_example",
      mediaId: "media_example",
      offsetSeconds: 0.5,
      truncated: false,
      items: [
        {
          id: "9223372036854775806",
          timeSeconds: 12.34,
          mode: "scroll",
          colorRgb: 16777215,
          text: "这是一条自造的测试弹幕"
        }
      ]
    });
    expect(parsed.success).toBe(true);
  });
});

describe("progress event validation", () => {
  it("accepts a backward seek and preserves the smaller position", () => {
    const parsed = progressEventSchema.safeParse({
      ...validEvent,
      kind: "seekCompleted",
      positionSeconds: 12.5
    });
    expect(parsed.success).toBe(true);
    if (parsed.success) {
      expect(parsed.data.positionSeconds).toBe(12.5);
    }
  });

  it("rejects negative and non-finite positions", () => {
    for (const positionSeconds of [-0.1, Number.NaN, Number.POSITIVE_INFINITY]) {
      expect(
        progressEventSchema.safeParse({
          ...validEvent,
          positionSeconds
        }).success
      ).toBe(false);
    }
  });

  it("rejects a position beyond a known duration and a zero duration", () => {
    expect(
      progressEventSchema.safeParse({
        ...validEvent,
        positionSeconds: 1440.1,
        durationSeconds: 1440
      }).success
    ).toBe(false);
    expect(
      progressEventSchema.safeParse({
        ...validEvent,
        durationSeconds: 0
      }).success
    ).toBe(false);
  });

  it("rejects unknown event kinds and unknown fields", () => {
    expect(
      progressEventSchema.safeParse({
        ...validEvent,
        kind: "teleport"
      }).success
    ).toBe(false);
    expect(
      progressEventSchema.safeParse({
        ...validEvent,
        unexpected: true
      }).success
    ).toBe(false);
  });
});

describe("playback plan validation", () => {
  it("accepts the documented ready plan shape", () => {
    expect(playbackPlanSchema.safeParse(validPlaybackPlan).success).toBe(true);
  });

  it("rejects negative resume positions and non-ready statuses", () => {
    expect(
      playbackPlanSchema.safeParse({
        ...validPlaybackPlan,
        resumeAtSeconds: -1
      }).success
    ).toBe(false);
    expect(
      playbackPlanSchema.safeParse({
        ...validPlaybackPlan,
        status: "processing"
      }).success
    ).toBe(false);
  });
});
