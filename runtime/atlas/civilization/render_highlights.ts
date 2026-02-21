/**
 * Render structural events and aggregates from civ-enriched items.
 */

import type { CivEnrichedItem } from "./classify.js";
import { CIV_FACTIONS } from "./taxonomy.js";
import { RADAR_CATEGORIES } from "../taxonomy/radar_taxonomy.js";

export type Highlight = {
  item_id: string;
  title: string;
  source_name: string;
  url: string;
  civ_primary_tag: string;
  radar_category?: string;
  score_total: number;
  summary_zh: string;
  published_at?: string;
};

export type HighlightsOutput = {
  structural_events: Highlight[];
  threshold: number;
  generated_at: string;
};

export type AggregatesOutput = {
  counts_by_tag: Record<string, number>;
  counts_by_radar_category: Record<string, number>;
  structural_count_by_tag: Record<string, number>;
  avg_score_by_tag: Record<string, number>;
  counts_by_source: Record<string, number>;
  structural_count: number;
  total_count: number;
};

const DEFAULT_THRESHOLD = 7;
const DEFAULT_TOP_N = 8;

export function renderHighlights(
  items: CivEnrichedItem[],
  opts: { threshold?: number; topN?: number } = {}
): HighlightsOutput {
  const threshold = opts.threshold ?? DEFAULT_THRESHOLD;
  const topN = opts.topN ?? DEFAULT_TOP_N;

  const structural = items
    .filter((i) => i.score_total >= threshold)
    .sort((a, b) => {
      const sc = b.score_total - a.score_total;
      if (sc !== 0) return sc;
      const da = a.published_at ?? "";
      const db = b.published_at ?? "";
      return db.localeCompare(da);
    });

  const byTag = new Map<string, CivEnrichedItem[]>();
  for (const item of structural) {
    const tag = item.civ_primary_tag;
    if (!byTag.has(tag)) byTag.set(tag, []);
    byTag.get(tag)!.push(item);
  }

  const picked: Highlight[] = [];
  const seen = new Set<string>();
  for (const tag of CIV_FACTIONS) {
    const list = byTag.get(tag) ?? [];
    for (const item of list.slice(0, 2)) {
      if (picked.length >= topN) break;
      const id = item.id ?? item.url ?? item.title;
      if (seen.has(id)) continue;
      seen.add(id);
      picked.push({
        item_id: id,
        title: item.title,
        source_name: item.source_name ?? "",
        url: item.url ?? "",
        civ_primary_tag: item.civ_primary_tag,
        radar_category: item.radar_categories?.[0]?.id,
        score_total: item.score_total,
        summary_zh: item.summary_zh,
        published_at: item.published_at,
      });
    }
  }

  const remaining = structural.filter((i) => !seen.has(i.id ?? i.url ?? i.title));
  for (const item of remaining) {
    if (picked.length >= topN) break;
    picked.push({
      item_id: item.id ?? item.url ?? item.title,
      title: item.title,
      source_name: item.source_name ?? "",
      url: item.url ?? "",
      civ_primary_tag: item.civ_primary_tag,
      radar_category: item.radar_categories?.[0]?.id,
      score_total: item.score_total,
      summary_zh: item.summary_zh,
      published_at: item.published_at,
    });
  }

  return {
    structural_events: picked,
    threshold,
    generated_at: new Date().toISOString(),
  };
}

export function renderAggregates(items: CivEnrichedItem[]): AggregatesOutput {
  const counts_by_tag: Record<string, number> = {};
  const counts_by_radar_category: Record<string, number> = {};
  const structural_count_by_tag: Record<string, number> = {};
  const sum_by_tag: Record<string, number> = {};
  const counts_by_source: Record<string, number> = {};

  for (const tag of CIV_FACTIONS) {
    counts_by_tag[tag] = 0;
    structural_count_by_tag[tag] = 0;
    sum_by_tag[tag] = 0;
  }
  for (const id of RADAR_CATEGORIES) {
    counts_by_radar_category[id] = 0;
  }

  let structural_count = 0;
  for (const item of items) {
    counts_by_tag[item.civ_primary_tag] = (counts_by_tag[item.civ_primary_tag] ?? 0) + 1;
    sum_by_tag[item.civ_primary_tag] =
      (sum_by_tag[item.civ_primary_tag] ?? 0) + item.score_total;
    const topRadar = item.radar_categories?.[0]?.id;
    if (topRadar) counts_by_radar_category[topRadar] = (counts_by_radar_category[topRadar] ?? 0) + 1;
    const src = item.source_name ?? "unknown";
    counts_by_source[src] = (counts_by_source[src] ?? 0) + 1;
    if (item.score_total >= 7) {
      structural_count++;
      structural_count_by_tag[item.civ_primary_tag] =
        (structural_count_by_tag[item.civ_primary_tag] ?? 0) + 1;
    }
  }

  const avg_score_by_tag: Record<string, number> = {};
  for (const tag of CIV_FACTIONS) {
    const n = counts_by_tag[tag] ?? 0;
    avg_score_by_tag[tag] = n > 0 ? Math.round((sum_by_tag[tag]! / n) * 10) / 10 : 0;
  }

  return {
    counts_by_tag,
    counts_by_radar_category,
    structural_count_by_tag,
    avg_score_by_tag,
    counts_by_source,
    structural_count,
    total_count: items.length,
  };
}
