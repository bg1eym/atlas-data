#!/usr/bin/env node
/**
 * Generate runtime/atlas/config/sources.json from extracted_sources.json.
 */

import { writeFileSync, mkdirSync } from "node:fs";
import { resolve, dirname } from "node:path";
import { fileURLToPath } from "node:url";
import { getAtlasFetchSources } from "../runtime/radar/sources_catalog.js";
import {
  loadSourcesOverrides,
  loadExtraAllowlist,
  validateOverride,
} from "../runtime/radar/source_overrides.js";

const __dirname = dirname(fileURLToPath(import.meta.url));
const ROOT = resolve(__dirname, "..");
const CONFIG_PATH = resolve(ROOT, "runtime/atlas/config/sources.json");

const allowlist = [
  "openai.com",
  "anthropic.com",
  "deepmind.google",
  "github.com",
  "reuters.com",
  "techcrunch.com",
  "venturebeat.com",
  "brookings.edu",
  "ec.europa.eu",
  "ftc.gov",
  "krebsonsecurity.com",
  "hai.stanford.edu",
  "spectrum.ieee.org",
  "datacenterdynamics.com",
  "arstechnica.com",
  "reddit.com",
  "substack.com",
  "oneusefulthing.substack.com",
  "garymarcus.substack.com",
  "theinformation.com",
  "aipolicy.substack.com",
  "climatetech.substack.com",
];

async function main(): Promise<void> {
  const { readFileSync, existsSync } = await import("node:fs");
  const extractedPath = resolve(ROOT, "out/radar_sources/extracted_sources.json");
  if (!existsSync(extractedPath)) {
    console.error(`FAIL: extracted_sources.json not found. Run: npx tsx runtime/radar/pdf_sources_extract.ts`);
    process.exit(1);
  }
  const extracted = JSON.parse(readFileSync(extractedPath, "utf-8"));

  for (const s of extracted.sources ?? []) {
    if (!s.adapter || !["rss", "html", "github", "x"].includes(s.adapter)) {
      console.error(`FAIL: source ${s.name} has invalid adapter`);
      process.exit(1);
    }
  }

  const byCat = new Map<string, number>();
  for (const s of extracted.sources ?? []) {
    byCat.set(s.category_id, (byCat.get(s.category_id) ?? 0) + 1);
  }
  const minPerCategory = Number(process.env.INPUT_PACK_MIN_SOURCES_PER_CATEGORY ?? 3);
  for (const [cat, n] of byCat) {
    if (n < minPerCategory) {
      console.error(`FAIL: category ${cat} has ${n} sources (need >= ${minPerCategory})`);
      process.exit(1);
    }
  }

  const minKols = Number(process.env.INPUT_PACK_MIN_KOLS ?? 4);
  const kolCount = (extracted.kols ?? []).length;
  if (kolCount < minKols) {
    console.error(`FAIL: KOL count ${kolCount} < ${minKols}`);
    process.exit(1);
  }

  const baseSources = getAtlasFetchSources();
  const extraAllowlist = loadExtraAllowlist();
  const overridesFile = loadSourcesOverrides();
  for (const o of overridesFile.sources) {
    validateOverride(o, allowlist, extraAllowlist);
  }

  const sources = [...baseSources];
  for (const o of overridesFile.sources) {
    const existingIdx = sources.findIndex(
      (s) => s.source_name === o.name && s.category === o.category
    );
    const idBase = `${o.name.toLowerCase().replace(/\s+/g, "-")}-${o.category}`
      .replace(/[^a-z0-9-]/g, "-")
      .slice(0, 45);
    const merged = {
      id: existingIdx >= 0 ? sources[existingIdx].id : `${idBase}-ovr`,
      source_name: o.name,
      url: o.url,
      fetch_type: o.adapter,
      kind: o.kind,
      category: o.category,
      editorial_weight: o.weight ?? (existingIdx >= 0 ? sources[existingIdx].editorial_weight : 50),
      ...(o.selectors ? { selectors: o.selectors } : {}),
      ...(o.headers ? { headers: o.headers } : {}),
      ...(o.rate_limit ? { rate_limit: o.rate_limit } : {}),
      ...(o.kol_profile ? { kol_profile: o.kol_profile } : {}),
    };
    if (existingIdx >= 0) sources[existingIdx] = merged;
    else sources.push(merged);
  }

  const finalAllowlist = Array.from(new Set([...allowlist, ...extraAllowlist])).sort();
  const sortedSources = sources
    .slice()
    .sort((a, b) => {
      if ((b.editorial_weight ?? 0) !== (a.editorial_weight ?? 0)) {
        return (b.editorial_weight ?? 0) - (a.editorial_weight ?? 0);
      }
      return a.id.localeCompare(b.id);
    });
  const config = {
    version: "1.0",
    description: "Generated from extracted_sources.json. AI news, diverse kinds (official/news/community/report/kol).",
    sources: sortedSources.map((s) => ({
      id: s.id,
      type: "ai_news",
      fetch_type: s.fetch_type,
      url: s.url,
      source_name: s.source_name,
      enabled: true,
      coverage_required: false,
      kind: s.kind,
      category: s.category,
      editorial_weight: s.editorial_weight ?? 0,
      ...(s.selectors ? { selectors: s.selectors } : {}),
      ...(s.headers ? { headers: s.headers } : {}),
      ...(s.rate_limit ? { rate_limit: s.rate_limit } : {}),
      ...(s.kol_profile ? { kol_profile: s.kol_profile } : {}),
    })),
    html_domain_allowlist: finalAllowlist,
    coverage_policy: "Diverse source coverage; official_share <= 0.40.",
    provenance: {
      generated_at: new Date().toISOString(),
      input_pack_parser: extracted?._meta?.parser ?? "unknown",
      input_pack_inputs: extracted?._meta?.inputs ?? [],
      base_source_count: baseSources.length,
      override_count: overridesFile.sources.length,
      allowlist_extra_count: extraAllowlist.length,
      overrides_file: "environment/sources_overrides.json",
      allowlist_extra_file: "environment/sources_allowlist_extra.json",
    },
  };
  mkdirSync(resolve(ROOT, "runtime/atlas/config"), { recursive: true });
  writeFileSync(CONFIG_PATH, JSON.stringify(config, null, 2), "utf-8");
  console.log(`sources.json written: ${CONFIG_PATH}`);
  console.log(`  sources: ${sortedSources.length} (base=${baseSources.length}, overrides=${overridesFile.sources.length})`);
}

main().catch((err) => {
  console.error("generate_sources_config FAIL:", err);
  process.exit(1);
});
