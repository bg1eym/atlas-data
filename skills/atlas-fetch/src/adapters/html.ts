/**
 * HTML Feed Adapter. For pages without RSS. Domain allowlist required.
 */

import type { RawItem, NormalizedItem, SourceConfig } from "../types.js";

function extractDomain(url: string): string {
  try {
    const u = new URL(url);
    return u.hostname.replace(/^www\./, "");
  } catch {
    return "";
  }
}

function hashId(s: string): string {
  let h = 0;
  for (let i = 0; i < s.length; i++) {
    h = (h << 5) - h + s.charCodeAt(i);
    h = h & h;
  }
  return Math.abs(h).toString(36);
}

/** Extract title and meta description from HTML. Minimal parser. */
function parseHtml(html: string, pageUrl: string): { title: string; summary: string } {
  const titleMatch = html.match(/<title[^>]*>([^<]+)<\/title>/i);
  const metaMatch = html.match(/<meta[^>]+name=["']description["'][^>]+content=["']([^"']+)["']/i)
    ?? html.match(/<meta[^>]+content=["']([^"']+)["'][^>]+name=["']description["']/i);
  return {
    title: (titleMatch?.[1] ?? "").trim().replace(/&[^;]+;/g, " ") || "(无标题)",
    summary: (metaMatch?.[1] ?? "").trim().slice(0, 500).replace(/&[^;]+;/g, " "),
  };
}

export async function fetchHtml(
  config: SourceConfig,
  allowlist: string[]
): Promise<RawItem[]> {
  if (!Array.isArray(config.selectors) || config.selectors.length === 0) {
    throw new Error(`HTML adapter requires selectors for ${config.id}`);
  }
  const domain = extractDomain(config.url);
  if (!allowlist.includes(domain)) {
    throw new Error(`Domain ${domain} not in allowlist (blocked_by_policy)`);
  }
  const res = await fetch(config.url, {
    headers: {
      "User-Agent": "Mozilla/5.0 (compatible; Atlas-Radar/1.0; +https://github.com/atlas-radar)",
      Accept: "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
    },
    signal: AbortSignal.timeout(20000),
  });
  if (!res.ok) {
    throw new Error(`HTTP ${res.status} for ${config.id}`);
  }
  const html = await res.text();
  const { title, summary } = parseHtml(html, config.url);
  return [
    {
      id: `html-${config.id}-${hashId(config.url)}`,
      title,
      url: config.url,
      link: config.url,
      content: summary,
      contentSnippet: summary,
      pubDate: new Date().toISOString(),
    },
  ];
}

export function normalizeHtml(raw: RawItem[], config: SourceConfig): NormalizedItem[] {
  const domain = extractDomain(config.url);
  return raw.map((r) => ({
    id: r.id,
    source_id: config.id,
    title: (r.title ?? "").trim() || "(无标题)",
    source_name: config.source_name,
    source_domain: domain,
    url: (r.url ?? r.link ?? config.url).trim(),
    published_at: r.pubDate ?? new Date().toISOString(),
    summary: ((r.contentSnippet ?? r.content ?? "").trim() || (r.title ?? "").trim() || "(no summary)").slice(0, 500),
    language: "en",
    tags: [],
    category_hint: config.category ?? "Official AI",
    kind: config.kind,
  }));
}
