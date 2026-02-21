/**
 * Atlas-Fetch types. NormalizedItem aligns with radar format.
 */

export type ItemKind = "official" | "news" | "community" | "report" | "kol";
export type AdapterType = "rss" | "html" | "github" | "x";
export type FailureBucket =
  | "ok"
  | "empty"
  | "rate_limited"
  | "parse_error"
  | "blocked"
  | "timeout"
  | "tls"
  | "dns"
  | "http_4xx"
  | "http_5xx"
  | "unknown";

export interface KolProfile {
  platform: "x" | "rss" | "blog" | "substack" | "github" | "hn" | "reddit";
  handle_or_url: string;
  fallback_signal_sources?: Array<{
    kind: "rss" | "blog" | "substack" | "github" | "hn" | "reddit";
    label: string;
    url: string;
  }>;
}

export interface NormalizedItem {
  id: string;
  source_id?: string;
  title: string;
  source_name: string;
  source_domain: string;
  url: string;
  published_at: string;
  summary: string;
  language: string;
  tags: string[];
  category_hint: string;
  kind?: ItemKind;
}

export interface RawItem {
  id: string;
  title: string;
  link?: string;
  url?: string;
  content?: string;
  contentSnippet?: string;
  pubDate?: string;
  isoDate?: string;
  creator?: string;
  source?: string;
  [key: string]: unknown;
}

export interface SourceConfig {
  id: string;
  type: string;
  fetch_type: AdapterType;
  url: string;
  source_name: string;
  enabled: boolean;
  coverage_required: boolean;
  kind?: ItemKind;
  category?: string;
  editorial_weight?: number;
  selectors?: string[];
  headers?: Record<string, string>;
  rate_limit?: { rps?: number; burst?: number };
  kol_profile?: KolProfile;
}

export interface Adapter {
  fetch(config: SourceConfig): Promise<RawItem[]>;
  normalize(raw: RawItem[], config: SourceConfig): NormalizedItem[];
}

export interface CoverageReport {
  source_id: string;
  source_name?: string;
  status: FailureBucket;
  bucket?: FailureBucket;
  item_count: number;
  reason?: string;
  adapter?: AdapterType;
  kind?: ItemKind;
  category?: string;
  editorial_weight?: number;
  freshness_ts?: number;
  ok_rate?: number;
  kol_profile?: KolProfile;
}
