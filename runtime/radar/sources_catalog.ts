/**
 * Sources catalog from canonical extracted_sources.json.
 */

import { readFileSync, existsSync } from "node:fs";
import { resolve, dirname } from "node:path";
import { fileURLToPath } from "node:url";
import type { RadarCategoryId } from "../atlas/taxonomy/radar_taxonomy.js";
import { RADAR_CATEGORIES } from "../atlas/taxonomy/radar_taxonomy.js";
import type { ExtractedSource, ExtractedSourcesJson, ExtractedKol } from "./pdf_sources_extract.js";

const __dirname = dirname(fileURLToPath(import.meta.url));
const ROOT = resolve(__dirname, "../..");
const EXTRACTED_PATH = resolve(ROOT, "out/radar_sources/extracted_sources.json");

export type SourceKind = "news" | "community" | "report" | "official" | "kol";

export type CatalogSource = {
  id: string;
  label: string;
  kind: SourceKind;
  default_enabled: boolean;
  category_tags: RadarCategoryId[];
  url?: string;
  adapter_hint: string;
};

function loadExtracted(): ExtractedSourcesJson {
  if (!existsSync(EXTRACTED_PATH)) {
    throw new Error(
      `extracted_sources.json not found at ${EXTRACTED_PATH}. Run: npx tsx runtime/radar/pdf_sources_extract.ts`
    );
  }
  const raw = readFileSync(EXTRACTED_PATH, "utf-8");
  return JSON.parse(raw) as ExtractedSourcesJson;
}

function toCatalogSource(s: ExtractedSource): CatalogSource {
  const id = `${s.category_id}-${s.name.toLowerCase().replace(/\s+/g, "-")}-${s.url.slice(0, 30)}`;
  return {
    id: id.replace(/[^a-z0-9-]/g, "-").slice(0, 60),
    label: s.name,
    kind: s.kind,
    default_enabled: ["rss", "html", "github", "x"].includes(s.adapter),
    category_tags: [s.category_id],
    url: s.url,
    adapter_hint: s.adapter,
  };
}

let _catalog: Record<RadarCategoryId, CatalogSource[]> | null = null;

function buildCatalog(): Record<RadarCategoryId, CatalogSource[]> {
  if (_catalog) return _catalog;
  const extracted = loadExtracted();
  const byCat: Record<string, CatalogSource[]> = {};
  for (const cat of RADAR_CATEGORIES) {
    byCat[cat] = [];
  }
  const seen = new Set<string>();
  for (const s of extracted.sources) {
    const key = `${s.category_id}:${s.name}:${s.url}`;
    if (seen.has(key)) continue;
    seen.add(key);
    const cs = toCatalogSource(s);
    if (byCat[s.category_id]) {
      byCat[s.category_id].push(cs);
    }
  }
  _catalog = byCat as Record<RadarCategoryId, CatalogSource[]>;
  return _catalog;
}

export function getSOURCES_CATALOG(): Record<RadarCategoryId, CatalogSource[]> {
  return buildCatalog();
}

export function getSourcesForCategory(cat: RadarCategoryId): CatalogSource[] {
  return getSOURCES_CATALOG()[cat] ?? [];
}

export function countSourcesPerCategory(): Record<RadarCategoryId, number> {
  const out: Partial<Record<RadarCategoryId, number>> = {};
  for (const cat of RADAR_CATEGORIES) {
    const arr = getSOURCES_CATALOG()[cat] ?? [];
    const uniq = new Set(arr.map((s) => s.id));
    out[cat] = uniq.size;
  }
  return out as Record<RadarCategoryId, number>;
}

/** Get sources config for atlas-fetch: only rss/html/github (substack->rss). Flat list, deduped by url. */
export function getAtlasFetchSources(): Array<{
  id: string;
  source_name: string;
  url: string;
  fetch_type: "rss" | "html" | "github" | "x";
  kind: SourceKind;
  category: RadarCategoryId;
  editorial_weight: number;
  selectors?: string[];
  headers?: Record<string, string>;
  rate_limit?: { rps?: number; burst?: number };
  kol_profile?: {
    platform: "x" | "rss" | "blog" | "substack" | "github" | "hn" | "reddit";
    handle_or_url: string;
    fallback_signal_sources?: Array<{
      kind: "rss" | "blog" | "substack" | "github" | "hn" | "reddit";
      label: string;
      url: string;
    }>;
  };
}> {
  const extracted = loadExtracted();
  const supported = ["rss", "html", "github", "x"] as const;
  const seen = new Set<string>();
  const out: Array<{
    id: string;
    source_name: string;
    url: string;
    fetch_type: "rss" | "html" | "github" | "x";
    kind: SourceKind;
    category: RadarCategoryId;
    editorial_weight: number;
    selectors?: string[];
    headers?: Record<string, string>;
    rate_limit?: { rps?: number; burst?: number };
    kol_profile?: {
      platform: "x" | "rss" | "blog" | "substack" | "github" | "hn" | "reddit";
      handle_or_url: string;
      fallback_signal_sources?: Array<{
        kind: "rss" | "blog" | "substack" | "github" | "hn" | "reddit";
        label: string;
        url: string;
      }>;
    };
  }> = [];
  const defaultWeightByKind: Record<SourceKind, number> = {
    news: 100,
    report: 90,
    kol: 80,
    official: 70,
    community: 85,
  };
  for (const s of extracted.sources) {
    if (!supported.includes(s.adapter as "rss")) continue;
    const fetchType: "rss" | "html" | "github" | "x" =
      s.adapter === "github"
          ? "github"
          : s.adapter === "html"
            ? "html"
            : s.adapter === "x"
              ? "x"
              : "rss";
    const url = s.url;
    const key = `${s.name}:${url}`;
    if (seen.has(key)) continue;
    seen.add(key);
    const id = `${s.name.toLowerCase().replace(/\s+/g, "-")}-${s.category_id}`.replace(/[^a-z0-9-]/g, "-").slice(0, 45);
    const editorialWeight = Number.isFinite(s.weight) ? Number(s.weight) : defaultWeightByKind[s.kind];
    const kolProfile =
      s.kind === "kol"
        ? {
            platform:
              s.adapter === "x"
                ? ("x" as const)
                : s.adapter === "github"
                    ? ("github" as const)
                    : s.adapter === "rss"
                          ? ("rss" as const)
                          : ("blog" as const),
            handle_or_url: s.url,
            fallback_signal_sources: [],
          }
        : undefined;
    out.push({
      id: `${id}-${seen.size}`,
      source_name: s.name,
      url,
      fetch_type: fetchType,
      kind: s.kind,
      category: s.category_id,
      editorial_weight: editorialWeight,
      ...(Array.isArray(s.selectors) && s.selectors.length ? { selectors: s.selectors } : {}),
      ...(s.headers ? { headers: s.headers } : {}),
      ...(s.rate_limit ? { rate_limit: s.rate_limit } : {}),
      ...(kolProfile ? { kol_profile: kolProfile } : {}),
    });
  }
  for (const k of extracted.kols as ExtractedKol[]) {
    const key = `${k.name}:${k.handle_or_url}`;
    if (seen.has(key)) continue;
    seen.add(key);
    const sourceId = `${k.kol_id || k.name.toLowerCase().replace(/\s+/g, "-")}-${k.category_id}`.replace(/[^a-z0-9-]/g, "-").slice(0, 45);
    out.push({
      id: `${sourceId}-${seen.size}`,
      source_name: k.name,
      url: k.handle_or_url,
      fetch_type: k.adapter === "x" ? "x" : k.adapter === "html" ? "html" : "rss",
      kind: "kol",
      category: k.category_id,
      editorial_weight: Number.isFinite(k.weight) ? Number(k.weight) : 80,
      kol_profile: {
        platform: k.adapter === "x" ? "x" : "rss",
        handle_or_url: k.handle_or_url,
        fallback_signal_sources:
          k.adapter === "x"
            ? [{ kind: "rss", label: "fallback rss/blog", url: k.handle_or_url }]
            : [],
      },
    });
  }
  return out;
}
