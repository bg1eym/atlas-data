#!/usr/bin/env node
/**
 * Run civilization classification on existing items_normalized.json.
 * Usage: npx tsx scripts/atlas_classify_only.mjs [run_dir]
 * Default run_dir: most recent in out/atlas/
 */
import { readFileSync, writeFileSync, mkdirSync, existsSync, readdirSync } from "node:fs";
import { resolve, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = dirname(fileURLToPath(import.meta.url));
const ROOT = resolve(__dirname, "..");
const ATLAS_OUT = resolve(ROOT, "out/atlas");

let runDir = process.argv[2];
if (!runDir) {
  const dirs = readdirSync(ATLAS_OUT, { withFileTypes: true })
    .filter((d) => d.isDirectory() && d.name !== "DELIVERY_RAW_STDOUT")
    .map((d) => resolve(ATLAS_OUT, d.name))
    .filter((d) => existsSync(resolve(d, "atlas-fetch/items_normalized.json")));
  if (dirs.length === 0) {
    console.error("No run with atlas-fetch/items_normalized.json found.");
    process.exit(1);
  }
  runDir = dirs[dirs.length - 1];
}

const normalizedPath = resolve(runDir, "atlas-fetch/items_normalized.json");
if (!existsSync(normalizedPath)) {
  console.error("Not found:", normalizedPath);
  process.exit(1);
}

const normalized = JSON.parse(readFileSync(normalizedPath, "utf-8"));
const items = (normalized.items ?? []).map((n) => ({
  id: n.id,
  title: n.title,
  source_name: n.source_name,
  summary: n.summary,
  url: n.url,
  published_at: n.published_at,
}));

const { runCivilizationPipeline } = await import("../runtime/atlas/civilization/index.ts");
const runId = runDir.split("/").pop() ?? "";
runCivilizationPipeline(items, runDir, runId);

console.log("Civilization pipeline OK:", runDir, items.length, "items");
