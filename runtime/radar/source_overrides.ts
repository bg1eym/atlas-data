import { existsSync, mkdirSync, readFileSync, writeFileSync, appendFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = dirname(fileURLToPath(import.meta.url));
const ROOT = resolve(__dirname, "../..");

export const OVERRIDES_PATH = resolve(ROOT, "environment/sources_overrides.json");
export const EXTRA_ALLOWLIST_PATH = resolve(ROOT, "environment/sources_allowlist_extra.json");
export const CHANGESET_PATH = resolve(ROOT, "out/radar_sources/changeset.jsonl");

export type OverrideAdapter = "rss" | "html" | "github" | "x";
export type OverrideKind = "official" | "news" | "community" | "report" | "kol";

export type SourceOverride = {
  kind: OverrideKind;
  name: string;
  url: string;
  adapter: OverrideAdapter;
  category: string;
  weight?: number;
  enabled?: boolean;
  selectors?: string[];
  headers?: Record<string, string>;
  rate_limit?: { rps?: number; burst?: number };
  kol_profile?: {
    platform: "x" | "rss" | "blog" | "substack" | "github" | "hn" | "reddit";
    handle_or_url: string;
    fallback_signal_sources?: Array<{
      kind: "rss" | "blog" | "substack" | "github" | "hn" | "reddit";
      label: string;
      url: string;
    }>;
  };
};

export type SourcesOverridesFile = {
  version: "1.0";
  sources: SourceOverride[];
};

function safeReadJson<T>(path: string, fallback: T): T {
  if (!existsSync(path)) return fallback;
  try {
    return JSON.parse(readFileSync(path, "utf-8")) as T;
  } catch {
    return fallback;
  }
}

export function loadSourcesOverrides(): SourcesOverridesFile {
  const file = safeReadJson<SourcesOverridesFile>(OVERRIDES_PATH, { version: "1.0", sources: [] });
  if (!file || file.version !== "1.0" || !Array.isArray(file.sources)) {
    return { version: "1.0", sources: [] };
  }
  return file;
}

export function saveSourcesOverrides(file: SourcesOverridesFile): void {
  mkdirSync(dirname(OVERRIDES_PATH), { recursive: true });
  writeFileSync(OVERRIDES_PATH, JSON.stringify(file, null, 2), "utf-8");
}

export function loadExtraAllowlist(): string[] {
  const file = safeReadJson<{ version?: string; domains?: string[] }>(EXTRA_ALLOWLIST_PATH, { domains: [] });
  return Array.isArray(file.domains) ? file.domains : [];
}

function parseDomain(url: string): string {
  try {
    return new URL(url).hostname.replace(/^www\./, "");
  } catch {
    return "";
  }
}

export function validateOverride(
  entry: SourceOverride,
  baseAllowlist: string[],
  extraAllowlist: string[]
): void {
  const required = [entry.kind, entry.name, entry.url, entry.adapter, entry.category];
  if (required.some((x) => !x || String(x).trim().length === 0)) {
    throw new Error("kind/name/url/adapter/category are required");
  }
  if (!entry.url.startsWith("https://")) {
    throw new Error("url must start with https://");
  }
  const domain = parseDomain(entry.url);
  if (!domain) {
    throw new Error("invalid url domain");
  }
  const allow = new Set([...baseAllowlist, ...extraAllowlist]);
  if (!allow.has(domain)) {
    throw new Error(`domain ${domain} not in allowlist`);
  }
  if (!["official", "news", "community", "report", "kol"].includes(entry.kind)) {
    throw new Error(`invalid kind: ${entry.kind}`);
  }
  if (!["rss", "html", "github", "x"].includes(entry.adapter)) {
    throw new Error(`invalid adapter: ${entry.adapter}`);
  }
  if (entry.weight != null && !Number.isFinite(entry.weight)) {
    throw new Error("weight must be a finite number");
  }
}

export function appendChangeset(entry: Record<string, unknown>): void {
  mkdirSync(dirname(CHANGESET_PATH), { recursive: true });
  appendFileSync(CHANGESET_PATH, JSON.stringify({ ts: new Date().toISOString(), ...entry }) + "\n", "utf-8");
}
