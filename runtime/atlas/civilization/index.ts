/**
 * Civilization pipeline: classify -> render_highlights -> write outputs.
 */

import { writeFileSync, mkdirSync } from "node:fs";
import { resolve } from "node:path";
import { classifyItems } from "./classify.js";
import { renderHighlights, renderAggregates } from "./render_highlights.js";
import type { NormalizedItem } from "./classify.js";
import type { CivEnrichedItem } from "./classify.js";
import { RADAR_CATEGORIES } from "../taxonomy/radar_taxonomy.js";
import { CIV_FACTIONS } from "./taxonomy.js";

export function runCivilizationPipeline(
  items: NormalizedItem[],
  outDir: string,
  runId = ""
): void {
  const civDir = resolve(outDir, "civilization");
  mkdirSync(civDir, { recursive: true });

  const enriched = classifyItems(items);
  const highlights = renderHighlights(enriched);
  const aggregates = renderAggregates(enriched);

  const countsByRadar: Record<string, number> = {};
  for (const id of RADAR_CATEGORIES) countsByRadar[id] = 0;
  const countsByCivTag: Record<string, number> = {};
  for (const tag of CIV_FACTIONS) countsByCivTag[tag] = 0;
  const bySource: Record<string, number> = {};
  for (const it of enriched as CivEnrichedItem[]) {
    const rc = it.radar_categories?.[0]?.id;
    if (rc) countsByRadar[rc] = (countsByRadar[rc] ?? 0) + 1;
    const tag = it.civ_primary_tag ?? "";
    if (tag) countsByCivTag[tag] = (countsByCivTag[tag] ?? 0) + 1;
    const src = it.source_name ?? "unknown";
    bySource[src] = (bySource[src] ?? 0) + 1;
  }
  const total = enriched.length;
  const top1Radar = Object.entries(countsByRadar).sort((a, b) => b[1] - a[1])[0];
  const top1Civ = Object.entries(countsByCivTag).sort((a, b) => b[1] - a[1])[0];
  const top1Source = Object.entries(bySource).sort((a, b) => b[1] - a[1])[0];
  const classificationDistribution = {
    run_id: runId,
    total_items: total,
    counts_by_radar_category: countsByRadar,
    counts_by_civ_tag: countsByCivTag,
    counts_by_source: bySource,
    top1_radar: top1Radar ? { id: top1Radar[0], count: top1Radar[1], share: total > 0 ? top1Radar[1] / total : 0 } : null,
    top1_civ_tag: top1Civ ? { tag: top1Civ[0], count: top1Civ[1], share: total > 0 ? top1Civ[1] / total : 0 } : null,
    top1_source: top1Source ? { source: top1Source[0], count: top1Source[1], share: total > 0 ? top1Source[1] / total : 0 } : null,
  };

  writeFileSync(
    resolve(civDir, "items_civ.json"),
    JSON.stringify({ run_id: runId, items: enriched }, null, 2),
    "utf-8"
  );
  writeFileSync(
    resolve(civDir, "highlights.json"),
    JSON.stringify(highlights, null, 2),
    "utf-8"
  );
  writeFileSync(
    resolve(civDir, "aggregates.json"),
    JSON.stringify(aggregates, null, 2),
    "utf-8"
  );
  writeFileSync(
    resolve(outDir, "classification_distribution.json"),
    JSON.stringify(classificationDistribution, null, 2),
    "utf-8"
  );
}
