#!/usr/bin/env node

import { existsSync, readFileSync } from "node:fs";
import { resolve, dirname } from "node:path";
import { fileURLToPath } from "node:url";
import { RADAR_CATEGORIES } from "../runtime/atlas/taxonomy/radar_taxonomy.js";
import {
  appendChangeset,
  loadExtraAllowlist,
  loadSourcesOverrides,
  saveSourcesOverrides,
  validateOverride,
  type SourceOverride,
} from "../runtime/radar/source_overrides.js";

const __dirname = dirname(fileURLToPath(import.meta.url));
const ROOT = resolve(__dirname, "..");
const SOURCES_CONFIG_PATH = resolve(ROOT, "runtime/atlas/config/sources.json");
const DEFAULT_ALLOWLIST = [
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

function parseArgs(argv: string[]): Record<string, string> {
  const out: Record<string, string> = {};
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (!a.startsWith("--")) continue;
    const k = a.slice(2);
    const v = argv[i + 1];
    if (v && !v.startsWith("--")) {
      out[k] = v;
      i++;
    } else {
      out[k] = "true";
    }
  }
  return out;
}

function loadBaseAllowlist(): string[] {
  if (!existsSync(SOURCES_CONFIG_PATH)) return DEFAULT_ALLOWLIST;
  try {
    const cfg = JSON.parse(readFileSync(SOURCES_CONFIG_PATH, "utf-8")) as { html_domain_allowlist?: string[] };
    return Array.isArray(cfg.html_domain_allowlist) && cfg.html_domain_allowlist.length > 0
      ? cfg.html_domain_allowlist
      : DEFAULT_ALLOWLIST;
  } catch {
    return DEFAULT_ALLOWLIST;
  }
}

async function main(): Promise<void> {
  const args = parseArgs(process.argv.slice(2));
  const kind = args.kind;
  const name = args.name;
  const url = args.url;
  const adapter = args.adapter;
  const category = args.category;
  const weight = args.weight ? Number(args.weight) : undefined;
  if (!kind || !name || !url || !adapter || !category) {
    console.error("Usage: npm run radar:add-source -- --kind news --name \"...\" --url \"https://...\" --adapter rss|html|github|x --category <radar_category> [--weight N]");
    process.exit(1);
  }
  if (!(RADAR_CATEGORIES as readonly string[]).includes(category)) {
    console.error(`Invalid category: ${category}`);
    process.exit(1);
  }

  const override: SourceOverride = {
    kind: kind as SourceOverride["kind"],
    name,
    url,
    adapter: adapter as SourceOverride["adapter"],
    category,
    ...(weight != null && Number.isFinite(weight) ? { weight } : {}),
    ...(adapter === "x"
      ? {
          kol_profile: {
            platform: "x",
            handle_or_url: url,
            fallback_signal_sources: [],
          },
        }
      : {}),
  };

  const baseAllowlist = loadBaseAllowlist();
  const extraAllowlist = loadExtraAllowlist();
  validateOverride(override, baseAllowlist, extraAllowlist);

  const file = loadSourcesOverrides();
  const idx = file.sources.findIndex((s) => s.name === name && s.category === category);
  if (idx >= 0) file.sources[idx] = override;
  else file.sources.push(override);
  saveSourcesOverrides(file);

  appendChangeset({
    action: idx >= 0 ? "update_source_override" : "add_source_override",
    source: override,
    actor: "cli:radar:add-source",
  });

  console.log(`OK: ${idx >= 0 ? "updated" : "added"} source override`);
  console.log(`  kind=${kind}`);
  console.log(`  name=${name}`);
  console.log(`  url=${url}`);
  console.log(`  adapter=${adapter}`);
  console.log(`  category=${category}`);
}

main().catch((err) => {
  console.error("radar:add-source FAIL:", err);
  process.exit(1);
});
