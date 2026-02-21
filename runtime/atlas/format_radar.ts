/**
 * Formatter: structured items -> final text. Radar layout.
 * No fp/entry/git/cwd leak. No \r\n, max 1 consecutive blank.
 */

import type { RadarItem } from "./filter_ai_relevance.js";

const URL_RE = /https?:\/\/[^\s)]+/g;

function extractSingleUrl(item: RadarItem): string {
  const urls = (item.url || "").match(URL_RE) || [];
  if (urls.length === 0) return "";
  return urls[0].replace(/[.,;:)]+$/, "");
}

function isValidUrl(s: string): boolean {
  return /^https?:\/\//.test(s) && s.length > 10 && s !== "—" && s.trim() !== "—";
}

function normalizeLine(s: string): string {
  return s
    .replace(/\r\n/g, "\n")
    .replace(/\r/g, "\n")
    .replace(/[ \t]+/g, " ")
    .trim();
}

function shouldDrop(item: RadarItem): boolean {
  const t = (item.title || "").trim();
  const s = (item.summary || "").trim();
  if (/^\(无标题\)|^\(no title\)|抓取失败|Example/i.test(t)) return true;
  if (/抓取失败|example\.com/i.test(s)) return true;
  return false;
}

export function formatRadarItems(items: RadarItem[], runId: string, today: string): { text: string; itemCount: number } {
  const filtered = items.filter((i) => !shouldDrop(i));
  const lines: string[] = [];
  const total = filtered.length;
  const deduped = total;

  lines.push(`📋 Radar ${today}`);
  lines.push(`run_id: ${runId}`);
  lines.push(`总条数: ${total} | 去重: ${deduped}`);
  lines.push("");
  lines.push("🟦 事实");
  lines.push("");

  const byCategory = new Map<string, RadarItem[]>();
  for (const item of filtered) {
    const cat = item.category || "Official AI";
    if (!byCategory.has(cat)) byCategory.set(cat, []);
    byCategory.get(cat)!.push(item);
  }

  const categoryOrder = [
    "Official AI",
    "Mainstream Media",
    "X KOL",
    "Hacker News",
    "Reddit",
    "Reports",
    "Substack",
  ];

  const maxItemsPerCategory = 50;
  for (const cat of categoryOrder) {
    const list = byCategory.get(cat);
    if (!list?.length) continue;
    const displayList = list.slice(0, maxItemsPerCategory);
    const extra = list.length > maxItemsPerCategory ? ` (显示前${maxItemsPerCategory}条，共${list.length}条)` : "";
    lines.push(`${cat}（${list.length}条）${extra}`);
    lines.push("");
    for (const item of displayList) {
      const title = normalizeLine(item.title || "");
      if (!title) continue;
      const url = extractSingleUrl(item);
      if (!isValidUrl(url)) continue;
      const source = normalizeLine(item.source || "") || "—";
      const summary = normalizeLine(item.summary || "") || "—";
      lines.push(title);
      lines.push(`Source: ${source}`);
      lines.push(`Summary: ${summary}`);
      lines.push(url);
      lines.push("");
    }
  }

  let out = lines.join("\n").replace(/\n{3,}/g, "\n\n").trimEnd();
  if (out && !out.endsWith("\n")) out += "\n";
  return { text: out.replace(/\r\n/g, "\n").replace(/\r/g, "\n"), itemCount: total };
}
