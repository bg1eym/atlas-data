/**
 * Lightweight fetch cache. Skip source if fetched < 30 min ago.
 * When skipping, load data from last run's sources_raw.json.
 */

import { readFileSync, writeFileSync, mkdirSync, existsSync } from "node:fs";
import { resolve, dirname } from "node:path";
import { fileURLToPath } from "node:url";
import type { NormalizedItem } from "./types.js";

const __dirname = dirname(fileURLToPath(import.meta.url));
const ROOT = resolve(__dirname, "../../..");
const CACHE_TTL_MS = 30 * 60 * 1000; // 30 min

export interface CacheEntry {
  source_id: string;
  last_fetch_timestamp: number;
  last_run_id?: string;
  etag?: string;
  last_modified?: string;
}

export interface FetchCache {
  entries: Record<string, CacheEntry>;
  updated_at: string;
}

function getCachePath(): string {
  return resolve(ROOT, "out/cache/fetch_cache.json");
}

export function loadCache(): FetchCache {
  const path = getCachePath();
  if (!existsSync(path)) return { entries: {}, updated_at: new Date().toISOString() };
  try {
    const raw = readFileSync(path, "utf-8");
    return JSON.parse(raw) as FetchCache;
  } catch {
    return { entries: {}, updated_at: new Date().toISOString() };
  }
}

export function saveCache(cache: FetchCache): void {
  const path = getCachePath();
  mkdirSync(resolve(path, ".."), { recursive: true });
  writeFileSync(path, JSON.stringify(cache, null, 2), "utf-8");
}

export function isFresh(cache: FetchCache, sourceId: string): boolean {
  const entry = cache.entries[sourceId];
  if (!entry) return false;
  const age = Date.now() - entry.last_fetch_timestamp;
  return age < CACHE_TTL_MS;
}

const ID_PREFIXES = ["rss-", "html-", "gh-"] as const;

function itemBelongsToSource(item: { id?: string }, sourceId: string): boolean {
  const id = item.id ?? "";
  return ID_PREFIXES.some((p) => id.startsWith(`${p}${sourceId}-`));
}

export function getCachedData(
  cache: FetchCache,
  sourceId: string
): { raw: unknown[]; normalized: NormalizedItem[] } | null {
  const entry = cache.entries[sourceId];
  if (!entry?.last_run_id) return null;
  const rawPath = resolve(ROOT, "out/atlas", entry.last_run_id, "atlas-fetch", "sources_raw.json");
  if (!existsSync(rawPath)) return null;
  try {
    const data = JSON.parse(readFileSync(rawPath, "utf-8")) as { by_source?: Record<string, unknown[]> };
    const raw = (data.by_source?.[sourceId] ?? []) as unknown[];
    const itemsPath = resolve(ROOT, "out/atlas", entry.last_run_id, "atlas-fetch", "items_normalized.json");
    if (!existsSync(itemsPath)) return { raw, normalized: [] };
    const itemsData = JSON.parse(readFileSync(itemsPath, "utf-8")) as { items?: NormalizedItem[] };
    const normalized = (itemsData.items ?? [])
      .filter((it) => itemBelongsToSource(it, sourceId))
      .map((it) => ({
        ...it,
        summary: ((it.summary ?? "").trim() || (it.title ?? "").trim() || "(no summary)").slice(0, 500),
      }));
    return { raw, normalized };
  } catch {
    return null;
  }
}

export function updateCacheEntry(
  cache: FetchCache,
  sourceId: string,
  runId: string,
  etag?: string,
  lastModified?: string
): void {
  cache.entries[sourceId] = {
    source_id: sourceId,
    last_fetch_timestamp: Date.now(),
    last_run_id: runId,
    ...(etag && { etag }),
    ...(lastModified && { last_modified: lastModified }),
  };
  cache.updated_at = new Date().toISOString();
}
