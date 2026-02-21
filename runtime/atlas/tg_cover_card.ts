/**
 * TG Cover Card generator. Output: tg_cover_card_zh.txt
 * No send; artifact only.
 */

import { readFileSync, writeFileSync, existsSync } from "node:fs";
import { resolve } from "node:path";

const DASHBOARD_URL_PLACEHOLDER = "{{DASHBOARD_URL}}";

function buildDashboardUrl(runId: string, dashboardUrlBase?: string): string {
  const base = (dashboardUrlBase ?? process.env.DASHBOARD_URL_BASE ?? "http://localhost:5173/").trim();
  if (!base) {
    return `http://localhost:5173/?run_id=${encodeURIComponent(runId)}`;
  }
  if (base.includes("{{run_id}}")) {
    return base.replaceAll("{{run_id}}", encodeURIComponent(runId));
  }
  try {
    const u = new URL(base);
    u.searchParams.set("run_id", runId);
    return u.toString();
  } catch {
    const sep = base.includes("?") ? "&" : "?";
    return `${base}${sep}run_id=${encodeURIComponent(runId)}`;
  }
}

export function ensureDashboardUrlInCoverCard(
  cardText: string,
  runId: string,
  dashboardUrlBase?: string,
): { text: string; dashboardUrl: string } {
  const dashboardUrl = buildDashboardUrl(runId, dashboardUrlBase);
  const withUrl = cardText.includes(DASHBOARD_URL_PLACEHOLDER)
    ? cardText.replaceAll(DASHBOARD_URL_PLACEHOLDER, dashboardUrl)
    : cardText.replace(
        /^🟦 打开 Dashboard：.*$/m,
        `🟦 打开 Dashboard：${dashboardUrl}`,
      );
  return { text: withUrl, dashboardUrl };
}

export function generateTgCoverCard(
  runDir: string,
  runId: string
): string {
  const today = new Date().toISOString().slice(0, 10);
  const lines: string[] = [];

  lines.push(`🧭 Atlas 文明态势雷达（${today}）`);
  lines.push("");

  const highlightsPath = resolve(runDir, "civilization", "highlights.json");
  const renderMetaPath = resolve(runDir, "render_meta.json");
  const provenancePath = resolve(runDir, "atlas-fetch", "provenance.json");

  let highlights: { structural_events: Array<{ title: string; civ_primary_tag: string; score_total: number; summary_zh: string }> } = { structural_events: [] };
  if (existsSync(highlightsPath)) {
    highlights = JSON.parse(readFileSync(highlightsPath, "utf-8"));
  }

  const topEvent = highlights.structural_events[0];
  if (topEvent) {
    const radarLabel = topEvent.radar_category ? `[${topEvent.radar_category}]` : "";
    lines.push(`• 🔥 ${topEvent.summary_zh} ${radarLabel} [${topEvent.civ_primary_tag}] (${topEvent.score_total})`);
  } else {
    lines.push("• 🔥 （暂无结构性事件）");
  }

  const aggregatesPath = resolve(runDir, "civilization", "aggregates.json");
  let topTag = "—";
  let topCount = 0;
  let topRadarCat = "—";
  let topRadarCount = 0;
  if (existsSync(aggregatesPath)) {
    const agg = JSON.parse(readFileSync(aggregatesPath, "utf-8"));
    const tagEntries = Object.entries(agg.counts_by_tag ?? {}) as [string, number][];
    if (tagEntries.length > 0) {
      const sorted = tagEntries.sort((a, b) => b[1] - a[1]);
      topTag = sorted[0][0];
      topCount = sorted[0][1];
    }
    const radarEntries = Object.entries(agg.counts_by_radar_category ?? {}) as [string, number][];
    if (radarEntries.length > 0) {
      const sorted = radarEntries.sort((a, b) => b[1] - a[1]);
      topRadarCat = sorted[0][0];
      topRadarCount = sorted[0][1];
    }
  }
  lines.push(`• 🧠 最活跃文明标签：${topTag}（${topCount} 条）`);
  lines.push(`• 📊 最活跃雷达栏目：${topRadarCat}（${topRadarCount} 条）`);
  lines.push("");

  let coverageX = 0;
  let coverageY = 0;
  let nonOkCount = 0;
  if (existsSync(provenancePath)) {
    const prov = JSON.parse(readFileSync(provenancePath, "utf-8"));
    const cov = prov.coverage ?? [];
    coverageY = cov.length;
    coverageX = cov.filter((c: { status?: string }) => (c.status ?? "").toLowerCase() === "ok").length;
    nonOkCount = cov.filter((c: { status?: string }) => (c.status ?? "").toLowerCase() !== "ok").length;
  }
  lines.push(`• 📡 覆盖率：${coverageX}/${coverageY}（${nonOkCount} 个非 OK 来源）`);
  lines.push("");

  lines.push(`🟦 打开 Dashboard：${DASHBOARD_URL_PLACEHOLDER}`);
  lines.push("");
  lines.push("（中文摘要为自动生成，供快速判断）");

  const text = lines.join("\n");
  const zhChars = (text.match(/[\u4e00-\u9fff]/g) || []).length;
  const totalChars = text.replace(/\s/g, "").length;
  const zhRatio = totalChars > 0 ? zhChars / totalChars : 0;
  if (zhRatio < 0.5) {
    lines.push("");
    lines.push(`[中文占比 ${(zhRatio * 100).toFixed(0)}%，需补充]`);
  }

  return lines.join("\n");
}

export function writeTgCoverCard(runDir: string, runId: string): void {
  const generated = generateTgCoverCard(runDir, runId);
  const { text } = ensureDashboardUrlInCoverCard(generated, runId);
  const outPath = resolve(runDir, "tg_cover_card_zh.txt");
  writeFileSync(outPath, text, "utf-8");
}
