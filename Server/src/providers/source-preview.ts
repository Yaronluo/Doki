import { ProviderError, type MediaProvider, type SourceEpisode, type SourceSubject } from "./types.js";
import type { MediaRelay } from "../media/relay.js";
import type { SourcePreviewPlan } from "../contracts/source-preview.js";

export interface SourcePreviewInput {
  readonly query: string;
  readonly episodeNumber?: number;
  readonly channel?: string;
}

export interface SourcePreviewDependencies {
  readonly provider: MediaProvider;
  readonly relay: MediaRelay;
  readonly now?: () => Date;
}

export class SourcePreviewService {
  readonly #provider: MediaProvider;
  readonly #relay: MediaRelay;
  readonly #now: () => Date;

  constructor(dependencies: SourcePreviewDependencies) {
    this.#provider = dependencies.provider;
    this.#relay = dependencies.relay;
    this.#now = dependencies.now ?? (() => new Date());
  }

  async build(
    input: SourcePreviewInput,
    context: { requestId: string; signal?: AbortSignal }
  ): Promise<SourcePreviewPlan> {
    const subjects = await this.#provider.search(input.query, context);
    const subject = this.chooseSubject(subjects, input.query);
    if (subject === undefined) {
      throw new ProviderError({
        code: "SOURCE_SUBJECT_NOT_FOUND",
        message: "源站没有找到匹配条目",
        retryable: false
      });
    }

    const episodes = await this.#provider.listEpisodes(subject, context);
    const episode = this.chooseEpisode(episodes, input);
    if (episode === undefined) {
      throw new ProviderError({
        code: "SOURCE_EPISODES_EMPTY",
        message: "源站没有找到匹配章节",
        retryable: false
      });
    }

    const asset = await this.#provider.resolve(episode, context);
    const session = this.#relay.createSession({
      providerId: this.#provider.descriptor.id,
      upstreamUrl: asset.upstreamUrl,
      headers: asset.upstreamHeaders
    });

    return {
      sessionId: session.sessionId,
      status: "ready",
      provider: {
        id: this.#provider.descriptor.id,
        name: this.#provider.descriptor.name
      },
      subject: {
        name: subject.name,
        sourceSubjectKey: subject.sourceSubjectKey
      },
      episode: {
        number: episode.episodeNumber,
        title: episode.title,
        channel: episode.channel,
        mediaId: episode.mediaId
      },
      source: {
        mode: "relay",
        url: session.masterUrl,
        expiresAt: session.expiresAt
      },
      tracks: {
        subtitleLanguages: [],
        hasAlternateAudio: false
      },
      capabilities: {
        canSeek: true,
        canAutoFailover: false
      },
      durationHintSeconds: 1_440,
      provenance: {
        ruleCommit: this.#provider.descriptor.ruleCommit,
        snapshotSha256: this.#provider.descriptor.snapshotSha256,
        verifiedAt: this.#now().toISOString()
      }
    };
  }

  private chooseSubject(
    subjects: readonly SourceSubject[],
    query: string
  ): SourceSubject | undefined {
    const normalizedQuery = normalizeName(query);
    return (
      subjects.find((subject) => normalizeName(subject.name) === normalizedQuery) ??
      subjects[0]
    );
  }

  private chooseEpisode(
    episodes: readonly SourceEpisode[],
    input: SourcePreviewInput
  ): SourceEpisode | undefined {
    const filteredByChannel =
      input.channel === undefined
        ? episodes
        : episodes.filter((episode) =>
            episode.channel.includes(input.channel as string)
          );
    const pool = filteredByChannel.length > 0 ? filteredByChannel : episodes;
    if (input.episodeNumber !== undefined) {
      return pool.find((episode) => episode.episodeNumber === input.episodeNumber);
    }
    return pool[0];
  }
}

function normalizeName(value: string): string {
  return value
    .normalize("NFKC")
    .replace(/\s+/g, "")
    .replace(/[·・:：\-—_]/g, "")
    .toLowerCase();
}
