#!/usr/bin/env node
/**
 * Atlas-Fetch: Multi-source adapter. Fetches from RSS, HTML, GitHub.
 * Parallel fetch (concurrency 5), lightweight cache (30 min TTL).
 * Outputs: sources_raw.json, items_normalized.json, provenance.json, fetch_diagnostics.json
 */

import { readFileSync, writeFileSync, mkdirSync } from "node:fs";
import { createHash } from "node:crypto";
import { resolve, dirname } from "node:path";
import { fileURLToPath } from "node:url";
import { fetchRss, normalizeRss } from "./adapters/rss.js";
import { fetchHtml, normalizeHtml } from "./adapters/html.js";
import { fetchGitHub, normalizeGitHub } from "./adapters/github.js";
import type { NormalizedItem, SourceConfig, CoverageReport, FailureBucket } from "./types.js";
import { applyFetchPolicy, DEFAULT_FETCH_POLICY } from "../../../runtime/atlas/fetch_policy.js";
import { loadCache, saveCache, isFresh, getCachedData, updateCacheEntry } from "./fetch_cache.js";
import { withRetry } from "./retry.js";

const __dirname = dirname(fileURLToPath(import.meta.url));
const ROOT = resolve(__dirname, "../../..");
const CONFIG_PATH = resolve(ROOT, "runtime/atlas/config/sources.json");
const CONCURRENCY = 5;

/** Fallback URLs for known-broken sources (404/moved). */
const URL_OVERRIDES: Record<string, string> = {
  "https://github.com/openai/openai/releases.atom": "https://github.com/openai/openai-python/releases.atom",
};

interface SourcesConfig {
  sources: SourceConfig[];
  html_domain_allowlist?: string[];
}

interface FetchDiagnostic {
  source_id: string;
  per_source_time_ms: number;
  skipped_by_cache: boolean;
  adapter_used: string;
  item_count: number;
  bucket: FailureBucket;
  reason?: string;
}

type CoverageGroupStats = { ok: number; total: number; ok_rate: number };

function parseHttpStatus(message: unknown): number | null {
  const text = String(message ?? "");
  const m = text.match(/\b(?:HTTP|Status code)\s+(\d{3})\b/i);
  if (!m) return null;
  const n = Number(m[1]);
  return Number.isFinite(n) ? n : null;
}

function classifyFailureBucket(message: string, itemCount = 0): FailureBucket {
  if (itemCount > 0) return "ok";
  const msg = message.toLowerCase();
  if (msg.includes("no items returned")) return "empty";
  if (msg.includes("blocked_by_policy") || msg.includes("not configured")) return "blocked";
  if (msg.includes("429") || msg.includes("rate limit")) return "rate_limited";
  if (msg.includes("timeout") || msg.includes("etimedout") || msg.includes("abortsignal")) return "timeout";
  if (msg.includes("certificate") || msg.includes("tls") || msg.includes("ssl")) return "tls";
  if (msg.includes("enotfound") || msg.includes("dns")) return "dns";
  if (msg.includes("parse") || msg.includes("xml") || msg.includes("unexpected token") || msg.includes("invalid")) return "parse_error";
  const status = parseHttpStatus(message);
  if (status && status >= 500) return "http_5xx";
  if (status && status >= 400) return "http_4xx";
  return "unknown";
}

function sourceFreshnessTs(items: NormalizedItem[]): number {
  let ts = 0;
  for (const it of items) {
    const n = Date.parse(it.published_at ?? "");
    if (Number.isFinite(n) && n > ts) ts = n;
  }
  return ts;
}

function normalizeAdapterName(adapter: string | undefined): string {
  if (!adapter) return "unknown";
  if (adapter === "rss_atom" || adapter === "rss") return "rss";
  if (adapter === "html_feed" || adapter === "html") return "html";
  if (adapter === "github_releases" || adapter === "github") return "github";
  if (adapter === "x") return "x";
  return adapter;
}

function sha256(data: string): string {
  return createHash("sha256").update(data).digest("hex");
}

async function fetchSource(
  config: SourceConfig,
  allowlist: string[]
): Promise<{ raw: unknown[]; normalized: NormalizedItem[]; adapter: string }> {
  if (config.fetch_type === "rss") {
    try {
      const raw = await fetchRss(config);
      return { raw, normalized: normalizeRss(raw, config), adapter: "rss_atom" };
    } catch (err) {
      console.warn(`[fetch] RSS failed for ${config.id}, falling back to HTML: ${String(err)}`);
      const raw = await fetchHtml(config, allowlist);
      return { raw, normalized: normalizeHtml(raw, config), adapter: "html_feed" };
    }
  }
  if (config.fetch_type === "html") {
    const raw = await fetchHtml(config, allowlist);
    return { raw, normalized: normalizeHtml(raw, config), adapter: "html_feed" };
  }
  if (config.fetch_type === "github") {
    const raw = await fetchGitHub(config);
    return { raw, normalized: normalizeGitHub(raw, config), adapter: "github_releases" };
  }
  if (config.fetch_type === "x") {
    throw new Error("X adapter not configured; use rss/blog/github fallback");
  }
  throw new Error(`Unknown fetch_type: ${config.fetch_type}`);
}

async function main(): Promise<void> {
  const runId = process.env.ATLAS_RUN_ID ?? `atlas-${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 8)}`;
  const outDir = process.env.ATLAS_OUT_DIR ?? resolve(ROOT, "out/atlas", runId);
  const skillsOutDir = process.env.SKILLS_OUT_BASE
    ? resolve(process.env.SKILLS_OUT_BASE, "atlas-fetch")
    : resolve(outDir, "atlas-fetch");

  mkdirSync(outDir, { recursive: true });
  mkdirSync(skillsOutDir, { recursive: true });

  const configRaw = readFileSync(CONFIG_PATH, "utf-8");
  const config: SourcesConfig = JSON.parse(configRaw);
  const sources = config.sources
    .filter((s) => s.enabled)
    .map((s) => (URL_OVERRIDES[s.url] ? { ...s, url: URL_OVERRIDES[s.url] } : s));
  const allowlist = config.html_domain_allowlist ?? [
    "openai.com",
    "anthropic.com",
    "deepmind.google",
    "github.com",
  ];

  const cache = loadCache();
  const allRaw: Record<string, unknown[]> = {};
  const allNormalized: NormalizedItem[] = [];
  const coverage: CoverageReport[] = [];
  const diagnostics: FetchDiagnostic[] = [];

  const processSource = async (src: SourceConfig): Promise<void> => {
    const t0 = Date.now();
    if (isFresh(cache, src.id)) {
      const cached = getCachedData(cache, src.id);
      if (cached) {
        console.log(`[fetch] skipped (fresh cache) source=${src.id}`);
        const freshness = sourceFreshnessTs(cached.normalized);
        allRaw[src.id] = cached.raw;
        allNormalized.push(...cached.normalized);
        coverage.push({
          source_id: src.id,
          source_name: src.source_name,
          status: cached.normalized.length > 0 ? "ok" : "empty",
          bucket: cached.normalized.length > 0 ? "ok" : "empty",
          item_count: cached.normalized.length,
          ...(cached.normalized.length === 0 ? { reason: "no items returned" } : {}),
          adapter: normalizeAdapterName(src.fetch_type),
          kind: src.kind,
          category: src.category,
          editorial_weight: src.editorial_weight,
          freshness_ts: freshness,
          ok_rate: cached.normalized.length > 0 ? 1 : 0,
          kol_profile: src.kol_profile,
        });
        diagnostics.push({
          source_id: src.id,
          per_source_time_ms: 0,
          skipped_by_cache: true,
          adapter_used: src.fetch_type,
          item_count: cached.normalized.length,
          bucket: cached.normalized.length > 0 ? "ok" : "empty",
          ...(cached.normalized.length === 0 ? { reason: "no items returned" } : {}),
        });
        return;
      }
    }

    try {
      const { raw, normalized, adapter } = await withRetry(() => fetchSource(src, allowlist), src.id);
      const elapsed = Date.now() - t0;
      console.log(`[fetch] source=${src.id} time=${elapsed} ms`);
      allRaw[src.id] = raw;
      allNormalized.push(...normalized);
      const status: "ok" | "empty" = normalized.length > 0 ? "ok" : "empty";
      const freshness = sourceFreshnessTs(normalized);
      coverage.push({
        source_id: src.id,
        source_name: src.source_name,
        status,
        bucket: status,
        item_count: normalized.length,
        ...(status === "empty" && { reason: "no items returned" }),
        adapter: normalizeAdapterName(adapter),
        kind: src.kind,
        category: src.category,
        editorial_weight: src.editorial_weight,
        freshness_ts: freshness,
        ok_rate: status === "ok" ? 1 : 0,
        kol_profile: src.kol_profile,
      });
      updateCacheEntry(cache, src.id, runId);
      diagnostics.push({
        source_id: src.id,
        per_source_time_ms: elapsed,
        skipped_by_cache: false,
        adapter_used: adapter,
        item_count: normalized.length,
        bucket: status,
        ...(status === "empty" ? { reason: "no items returned" } : {}),
      });
    } catch (err) {
      const msg = String(err);
      const bucket = classifyFailureBucket(msg);
      coverage.push({
        source_id: src.id,
        source_name: src.source_name,
        status: bucket,
        bucket,
        item_count: 0,
        reason: msg.slice(0, 300),
        adapter: normalizeAdapterName(src.fetch_type),
        kind: src.kind,
        category: src.category,
        editorial_weight: src.editorial_weight,
        freshness_ts: 0,
        ok_rate: 0,
        kol_profile: src.kol_profile,
      });
      diagnostics.push({
        source_id: src.id,
        per_source_time_ms: Date.now() - t0,
        skipped_by_cache: false,
        adapter_used: src.fetch_type,
        item_count: 0,
        bucket,
        reason: msg.slice(0, 300),
      });
    }
  };

  for (let i = 0; i < sources.length; i += CONCURRENCY) {
    const chunk = sources.slice(i, i + CONCURRENCY);
    await Promise.all(chunk.map((src) => processSource(src)));
  }

  saveCache(cache);

  const policy = DEFAULT_FETCH_POLICY;
  const limited = applyFetchPolicy(
    allNormalized,
    policy,
    (it) => it.category_hint ?? "uncategorized"
  );

  async function translateSummaryToZh(text: string): Promise<string> {
    let t = (text ?? "").trim();
    while (t && Buffer.byteLength(t, "utf8") > 450) t = t.slice(0, -1);
    if (!t) return "";
    const engines = [
      async () => {
        let url = `https://api.mymemory.translated.net/get?q=${encodeURIComponent(t)}&langpair=en|zh`;
        const email = process.env.ATLAS_MYMEMORY_EMAIL;
        if (email) url += `&de=${encodeURIComponent(email)}`;
        const res = await fetch(url, { signal: AbortSignal.timeout(10000) });
        if (!res.ok) throw new Error(`MyMemory ${res.status}`);
        const j = (await res.json()) as { responseData?: { translatedText?: string } };
        return (j.responseData?.translatedText ?? "").trim();
      },
      async () => {
        const { translate } = await import("@vitalets/google-translate-api");
        const { text: zh } = await translate(t, { to: "zh-CN" });
        return (zh ?? "").trim();
      },
    ];
    for (const fn of engines) {
      try {
        const zh = await fn();
        if (zh) return zh;
      } catch (err) {
        if (process.env.DEBUG) console.warn("[translate]", String(err));
      }
    }
    return "";
  }

  const PLACEHOLDER_ZH = "（摘要生成失败）";
  const skipTranslate = process.env.ATLAS_SKIP_TRANSLATE === "1";
  const withSummaryZh: Array<NormalizedItem & { summary_zh?: string; summary_zh_reason?: string }> = [];
  if (skipTranslate) {
    limited.forEach((it) =>
      withSummaryZh.push({
        ...it,
        summary_zh: PLACEHOLDER_ZH,
        summary_zh_reason: "ATLAS_SKIP_TRANSLATE=1",
      })
    );
  } else {
    console.log(`[fetch] translating ${limited.length} summaries to zh-CN...`);
    const TRANSLATE_CONCURRENCY = 5;
    const TRANSLATE_DELAY_MS = 200;
    for (let i = 0; i < limited.length; i += TRANSLATE_CONCURRENCY) {
      const chunk = limited.slice(i, i + TRANSLATE_CONCURRENCY);
      const results = await Promise.all(
        chunk.map(async (it) => {
          const toTranslate = (it.summary ?? "").trim() || (it.title ?? "").trim();
          const summary_zh = await translateSummaryToZh(toTranslate);
          if (summary_zh) {
            return { ...it, summary_zh };
          }
          return {
            ...it,
            summary_zh: PLACEHOLDER_ZH,
            summary_zh_reason: "translation_failed",
          };
        })
      );
      withSummaryZh.push(...results);
      if (i + TRANSLATE_CONCURRENCY < limited.length) {
        await new Promise((r) => setTimeout(r, TRANSLATE_DELAY_MS));
      }
    }
  }

  const sourcesRaw = {
    run_id: runId,
    item_count: allNormalized.length,
    item_count_after_policy: limited.length,
    by_source: allRaw,
    coverage,
  };
  const rawJson = JSON.stringify(sourcesRaw, null, 2);
  const rawPath = resolve(skillsOutDir, "sources_raw.json");
  writeFileSync(rawPath, rawJson, "utf-8");

  const normalizedJson = JSON.stringify(
    { run_id: runId, items: withSummaryZh, item_count: withSummaryZh.length },
    null,
    2
  );
  const normalizedPath = resolve(skillsOutDir, "items_normalized.json");
  writeFileSync(normalizedPath, normalizedJson, "utf-8");

  const rawSha = sha256(rawJson);
  const normalizedSha = sha256(normalizedJson);
  const provenance = {
    run_id: runId,
    pipeline_output_sha256: rawSha,
    render_input_sha256: normalizedSha,
    coverage,
    timestamp: new Date().toISOString(),
  };
  writeFileSync(
    resolve(skillsOutDir, "provenance.json"),
    JSON.stringify(provenance, null, 2),
    "utf-8"
  );

  const fetchDiagnostics = {
    run_id: runId,
    per_source_time_ms: Object.fromEntries(diagnostics.map((d) => [d.source_id, d.per_source_time_ms])),
    skipped_by_cache: diagnostics.filter((d) => d.skipped_by_cache).map((d) => d.source_id),
    adapter_used: Object.fromEntries(diagnostics.map((d) => [d.source_id, d.adapter_used])),
    item_count: Object.fromEntries(diagnostics.map((d) => [d.source_id, d.item_count])),
  };
  writeFileSync(
    resolve(outDir, "fetch_diagnostics.json"),
    JSON.stringify(fetchDiagnostics, null, 2),
    "utf-8"
  );

  const byKindRaw = new Map<string, { ok: number; total: number }>();
  const byAdapterRaw = new Map<string, { ok: number; total: number }>();
  let okCount = 0;
  let blockedCount = 0;
  for (const c of coverage) {
    const isOk = c.status === "ok";
    if (isOk) okCount++;
    if (c.status === "blocked") blockedCount++;
    const kind = c.kind ?? "unknown";
    const adapter = c.adapter ?? "unknown";
    const kRow = byKindRaw.get(kind) ?? { ok: 0, total: 0 };
    const aRow = byAdapterRaw.get(adapter) ?? { ok: 0, total: 0 };
    kRow.total += 1;
    aRow.total += 1;
    if (isOk) {
      kRow.ok += 1;
      aRow.ok += 1;
    }
    byKindRaw.set(kind, kRow);
    byAdapterRaw.set(adapter, aRow);
  }
  const byKind: Record<string, CoverageGroupStats> = {};
  const byAdapter: Record<string, CoverageGroupStats> = {};
  for (const [k, v] of byKindRaw.entries()) {
    byKind[k] = { ok: v.ok, total: v.total, ok_rate: v.total > 0 ? Number((v.ok / v.total).toFixed(4)) : 0 };
  }
  for (const [k, v] of byAdapterRaw.entries()) {
    byAdapter[k] = { ok: v.ok, total: v.total, ok_rate: v.total > 0 ? Number((v.ok / v.total).toFixed(4)) : 0 };
  }
  const failed = coverage
    .filter((c) => c.status !== "ok")
    .map((c) => ({
      source_id: c.source_id,
      source_name: c.source_name ?? c.source_id,
      bucket: c.bucket ?? c.status,
      reason: c.reason ?? "unknown",
      kind: c.kind ?? "unknown",
      adapter: c.adapter ?? "unknown",
    }))
    .slice(0, 10);
  const coverageStats = {
    run_id: runId,
    generated_at: new Date().toISOString(),
    total_sources: coverage.length,
    ok_sources: okCount,
    overall_ok_rate: coverage.length > 0 ? Number((okCount / coverage.length).toFixed(4)) : 0,
    blocked_share: coverage.length > 0 ? Number((blockedCount / coverage.length).toFixed(4)) : 0,
    by_kind: byKind,
    by_adapter: byAdapter,
    per_source: coverage.map((c) => ({
      source_id: c.source_id,
      source_name: c.source_name ?? c.source_id,
      status: c.status,
      bucket: c.bucket ?? c.status,
      http_status: parseHttpStatus(c.reason),
      reason: c.reason ?? "",
      kind: c.kind ?? "unknown",
      adapter: c.adapter ?? "unknown",
    })),
    top_failed_sources: failed,
  };
  writeFileSync(
    resolve(outDir, "coverage_stats.json"),
    JSON.stringify(coverageStats, null, 2),
    "utf-8"
  );

  console.log(`run_id=${runId}`);
  console.log(`atlas_out_dir=${outDir}`);
  console.log(`sources_raw=${rawPath}`);
  console.log(`items_normalized=${normalizedPath}`);
  console.log(`item_count=${limited.length} (after policy: per_source=${policy.per_source_limit}, global=${policy.global_cap})`);
}

export { main as runFetch };

const isMain = process.argv[1]?.endsWith("index.ts") || process.argv[1]?.includes("atlas-fetch");
if (isMain) {
  main().catch((err) => {
    console.error("atlas-fetch FAIL:", err);
    process.exit(1);
  });
}
