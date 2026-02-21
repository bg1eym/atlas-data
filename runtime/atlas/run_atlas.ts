#!/usr/bin/env node
/**
 * Atlas pipeline: fetch -> filter -> render. LOCAL_ONLY.
 */

import { readFileSync, writeFileSync, mkdirSync, existsSync } from "node:fs";
import { createHash } from "node:crypto";
import { resolve, dirname } from "node:path";
import { fileURLToPath } from "node:url";
import { filterAiRelevance } from "./filter_ai_relevance.js";
import { formatRadarItems } from "./format_radar.js";
import { runFetch } from "../../skills/atlas-fetch/src/index.js";
import { runCivilizationPipeline } from "./civilization/index.js";
import { writeTgCoverCard } from "./tg_cover_card.js";
import type { RadarItem } from "./filter_ai_relevance.js";

const __dirname = dirname(fileURLToPath(import.meta.url));
const ROOT = resolve(__dirname, "../..");

function sha256(data: string): string {
  return createHash("sha256").update(data).digest("hex");
}

function truncateForTg(text: string, maxLen = 3896): string {
  const suffix = "\n\n(… 已截断 / truncated for TG)";
  if (text.length <= maxLen) return text;
  const lines = text.split("\n");
  const result: string[] = [];
  let len = 0;
  for (const line of lines) {
    if (len + line.length + 1 > maxLen) break;
    result.push(line);
    len += line.length + 1;
  }
  return (result.length > 0 ? result.join("\n") : text.slice(0, maxLen)) + suffix;
}

export type AtlasRunResult = {
  runId: string;
  outDir: string;
  itemCount: number;
  renderedPath: string;
};

export async function runAtlasPipeline(): Promise<AtlasRunResult> {
  const runId = `atlas-${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 8)}`;
  const outDir = resolve(ROOT, "out/atlas", runId);
  mkdirSync(outDir, { recursive: true });

  const fetchOutDir = resolve(outDir, "atlas-fetch");
  mkdirSync(fetchOutDir, { recursive: true });

  process.env.ATLAS_RUN_ID = runId;
  process.env.ATLAS_OUT_DIR = outDir;
  process.env.SKILLS_OUT_BASE = outDir;
  await runFetch();

  const normalizedPath = resolve(fetchOutDir, "items_normalized.json");
  if (!existsSync(normalizedPath)) {
    console.error("items_normalized.json not found");
    process.exit(1);
  }

  const normalized = JSON.parse(readFileSync(normalizedPath, "utf-8"));
  const items: RadarItem[] = (normalized.items ?? []).map((n: { title: string; source_name: string; url: string; summary: string; category_hint?: string }) => ({
    title: n.title,
    source: n.source_name,
    summary: n.summary ?? "",
    url: n.url,
    category: n.category_hint,
  }));

  const { allowed, report } = filterAiRelevance(items);
  const today = new Date().toISOString().slice(0, 10);
  const { text: rendered, itemCount: formatCount } = formatRadarItems(allowed, runId, today);
  const truncated = truncateForTg(rendered);

  const renderPath = resolve(outDir, "rendered_text.txt");
  writeFileSync(renderPath, truncated, "utf-8");

  const provenancePath = resolve(fetchOutDir, "provenance.json");
  const provenance = existsSync(provenancePath)
    ? JSON.parse(readFileSync(provenancePath, "utf-8"))
    : {};
  const renderMeta = {
    pipeline_run_id: runId,
    render_input_sha256: provenance.render_input_sha256 ?? sha256(JSON.stringify(items)),
    render_output_sha256: sha256(truncated),
    render_timestamp: new Date().toISOString(),
    item_count: formatCount,
    filter_report: report,
  };
  writeFileSync(resolve(outDir, "render_meta.json"), JSON.stringify(renderMeta, null, 2), "utf-8");

  const normItems = (normalized.items ?? []).map((n: { id?: string; source_id?: string; title: string; source_name?: string; summary?: string; summary_zh?: string; url?: string; published_at?: string; kind?: string; category_hint?: string }) => ({
    id: n.id,
    source_id: n.source_id,
    title: n.title,
    source_name: n.source_name,
    summary: n.summary,
    summary_zh: n.summary_zh,
    url: n.url,
    published_at: n.published_at,
    kind: n.kind,
    category_hint: n.category_hint,
  }));
  runCivilizationPipeline(normItems, outDir, runId);
  writeTgCoverCard(outDir, runId);

  // Write audit/summary.json with pipeline_verdict and delivery_verdict.
  // Pipeline never depends on TELEGRAM_* or DASHBOARD_URL_BASE.
  // Local runs: delivery_verdict=NOT_CONFIGURED (TG stage skipped).
  const coverageStatsPath = resolve(outDir, "coverage_stats.json");
  let overallOkRate = 1;
  if (existsSync(coverageStatsPath)) {
    try {
      const stats = JSON.parse(readFileSync(coverageStatsPath, "utf-8")) as { overall_ok_rate?: number };
      overallOkRate = Number(stats.overall_ok_rate ?? 1);
    } catch {}
  }
  const pipelineVerdict =
    formatCount === 0 ? "BLOCKED" : overallOkRate >= 0.65 ? "OK" : "DEGRADED";
  const auditDir = resolve(outDir, "audit");
  mkdirSync(auditDir, { recursive: true });
  const auditSummary = {
    pipeline_verdict: pipelineVerdict,
    delivery_verdict: "NOT_CONFIGURED" as const,
    delivery_reason: null as string | null,
    verdict: pipelineVerdict,
    exit_code: 0,
    finished_at: new Date().toISOString(),
  };
  writeFileSync(resolve(auditDir, "summary.json"), JSON.stringify(auditSummary, null, 2), "utf-8");

  // Machine-readable result contract for TG/oc-bind integration.
  const coverPath = resolve(outDir, "cover.png");
  const coverExists = existsSync(coverPath);
  const classDistPath = resolve(outDir, "classification_distribution.json");
  let categoriesCount = 0;
  if (existsSync(classDistPath)) {
    try {
      const dist = JSON.parse(readFileSync(classDistPath, "utf-8")) as { counts_by_radar_category?: Record<string, number> };
      const counts = dist.counts_by_radar_category ?? {};
      categoriesCount = Object.values(counts).filter((c) => c > 0).length;
    } catch {}
  }
  const resultContract = {
    run_id: runId,
    generated_at: new Date().toISOString(),
    item_count: formatCount,
    categories_count: categoriesCount,
    coverage: {
      overall_ok_rate: overallOkRate,
      pipeline_verdict: pipelineVerdict,
    },
    dashboard_rel_path: runId,
    dashboard_url: "",
    cover_rel_path_or_url: coverExists ? "cover.png" : null,
    cover_url: "",
    cover_missing: !coverExists,
  };
  writeFileSync(resolve(outDir, "result.json"), JSON.stringify(resultContract, null, 2), "utf-8");

  console.log(`run_id=${runId}`);
  console.log(`out_dir=${outDir}`);
  console.log(`item_count=${formatCount}`);
  console.log(`rendered=${renderPath}`);

  return {
    runId,
    outDir,
    itemCount: formatCount,
    renderedPath: renderPath,
  };
}

async function main(): Promise<void> {
  await runAtlasPipeline();
}

const isMain = process.argv[1]?.endsWith("run_atlas.ts") || process.argv[1]?.endsWith("run_atlas.js");
if (isMain) {
  main().catch((err) => {
    console.error("run_atlas FAIL:", err);
    process.exit(1);
  });
}
