/** Internal provider contract for the first real online-source adapter. */

export interface ProviderRequestContext {
  readonly signal?: AbortSignal;
  readonly requestId: string;
}

export interface SourceSubject {
  readonly providerId: string;
  readonly sourceSubjectKey: string;
  readonly name: string;
  readonly pageUrl: string;
}

export interface SourceEpisode {
  readonly providerId: string;
  readonly mediaId: string;
  readonly sourceSubjectKey: string;
  readonly channel: string;
  readonly episodeNumber: number;
  readonly title: string;
  readonly pageUrl: string;
}

export interface ResolvedAsset {
  readonly assetId: string;
  readonly mediaId: string;
  readonly upstreamUrl: string;
  readonly upstreamHeaders: Readonly<Record<string, string>>;
  readonly mediaType: "hls" | "mp4";
  readonly expiresAt?: string;
  readonly provider: ProviderDescriptor;
}

export interface ProviderDescriptor {
  readonly id: string;
  readonly name: string;
  readonly sourceOrigin: string;
  readonly ruleCommit: string;
  readonly snapshotSha256: string;
}

export interface ProviderCapabilities {
  readonly search: boolean;
  readonly episodeList: boolean;
  readonly resolve: boolean;
  readonly browserRequired: boolean;
}

export interface MediaProvider {
  readonly descriptor: ProviderDescriptor;
  readonly capabilities: ProviderCapabilities;
  search(
    query: string,
    context: ProviderRequestContext
  ): Promise<readonly SourceSubject[]>;
  listEpisodes(
    subject: SourceSubject,
    context: ProviderRequestContext
  ): Promise<readonly SourceEpisode[]>;
  resolve(
    episode: SourceEpisode,
    context: ProviderRequestContext
  ): Promise<ResolvedAsset>;
}

export class ProviderError extends Error {
  readonly code: string;
  readonly retryable: boolean;
  readonly details: Record<string, unknown> | undefined;

  constructor(input: {
    code: string;
    message: string;
    retryable: boolean;
    details?: Record<string, unknown>;
  }) {
    super(input.message);
    this.name = "ProviderError";
    this.code = input.code;
    this.retryable = input.retryable;
    this.details = input.details;
  }
}

export interface FetchTransport {
  fetch(
    url: string,
    options: {
      readonly method?: string;
      readonly body?: string;
      readonly headers?: Readonly<Record<string, string>>;
      readonly signal?: AbortSignal;
      readonly maxRedirects?: number;
      readonly followRedirects?: boolean;
    }
  ): Promise<SafeFetchResult>;
  readText(
    response: Response,
    options?: { readonly maxBytes?: number }
  ): Promise<string>;
}

export interface SafeFetchResult {
  readonly response: Response;
  readonly finalUrl: URL;
}
