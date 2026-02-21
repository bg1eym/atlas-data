/**
 * GitHub Releases/Repo Activity Adapter. Uses Atom RSS (releases.atom).
 */

import Parser from "rss-parser";
import type { RawItem, NormalizedItem, SourceConfig } from "../types.js";

const parser = new Parser({
  timeout: 20000,
  headers: {
    "User-Agent": "Mozilla/5.0 (compatible; Atlas-Radar/1.0; +https://github.com/atlas-radar)",
    Accept: "application/atom+xml, application/xml, */*",
  },
});

function hashId(s: string): string {
  let h = 0;
  for (let i = 0; i < s.length; i++) {
    h = (h << 5) - h + s.charCodeAt(i);
    h = h & h;
  }
  return Math.abs(h).toString(36);
}

export async function fetchGitHub(config: SourceConfig): Promise<RawItem[]> {
  let url = config.url;
  if (!url.includes("/releases.atom") && !url.includes("/commits.atom")) {
    url = url.replace(/\/?$/, "/releases.atom");
  }
  const items: RawItem[] = [];
  try {
    const feed = await parser.parseURL(url);
    for (let i = 0; i < (feed.items?.length ?? 0); i++) {
      const it = feed.items[i];
      const link = it.link ?? it.guid ?? "";
      items.push({
        id: `gh-${config.id}-${hashId(link || it.title || String(i))}`,
        title: it.title ?? "",
        link,
        url: link,
        content: it.content,
        contentSnippet: it.contentSnippet,
        pubDate: it.pubDate,
        isoDate: it.isoDate,
        source: "GitHub",
      });
    }
  } catch (err) {
    throw new Error(`GitHub fetch failed for ${config.id}: ${String(err)}`);
  }
  return items;
}

export function normalizeGitHub(raw: RawItem[], config: SourceConfig): NormalizedItem[] {
  return raw.map((r) => ({
    id: r.id,
    source_id: config.id,
    title: (r.title ?? "").trim() || "(无标题)",
    source_name: config.source_name,
    source_domain: "github.com",
    url: (r.url ?? r.link ?? "").trim(),
    published_at: r.isoDate ?? r.pubDate ?? new Date().toISOString(),
    summary: ((r.contentSnippet ?? r.content ?? "").trim() || (r.title ?? "").trim() || "(no summary)").slice(0, 500),
    language: "en",
    tags: ["github", "release"],
    category_hint: config.category ?? "Official AI",
    kind: config.kind,
  }));
}
