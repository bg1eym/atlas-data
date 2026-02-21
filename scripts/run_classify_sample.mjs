#!/usr/bin/env node
/**
 * Run civilization classification on items_normalized.json sample.
 * Usage: node scripts/run_classify_sample.mjs <run_dir>
 * Writes civilization/items_civ.json
 */
import { readFileSync, writeFileSync, mkdirSync } from "node:fs";
import { resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { createRequire } from "node:module";

const __dirname = fileURLToPath(new URL(".", import.meta.url));
const require = createRequire(import.meta.url);
const ROOT = resolve(__dirname, "..");

const runDir = process.argv[2] || resolve(ROOT, "out/atlas");
const normalizedPath = resolve(runDir, "atlas-fetch/items_normalized.json");

let items;
try {
  const raw = JSON.parse(readFileSync(normalizedPath, "utf-8"));
  items = (raw.items ?? []).slice(0, 500);
} catch (e) {
  console.error("Failed to read", normalizedPath, e.message);
  process.exit(1);
}

const normItems = items.map((n) => ({
  id: n.id,
  title: n.title,
  source_name: n.source_name,
  summary: n.summary,
  url: n.url,
  published_at: n.published_at,
}));

const { classifyItems } = await import("../runtime/atlas/civilization/classify.ts");
const enriched = classifyItems(normItems);

const civDir = resolve(runDir, "civilization");
mkdirSync(civDir, { recursive: true });
writeFileSync(
  resolve(civDir, "items_civ.json"),
  JSON.stringify({ run_id: "", items: enriched }, null, 2),
  "utf-8"
);
console.log("Wrote", civDir, "items_civ.json", enriched.length, "items");
