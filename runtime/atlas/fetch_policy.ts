/**
 * Fetch policy: per_source_limit, per_category_cap, global_cap.
 * Aligns with situation-monitor: NewsPanel items.slice(0,15), GDELT maxrecords=20.
 * See PARITY_MAP: vendor/situation-monitor rank/limit capability.
 */

export interface FetchPolicy {
  per_source_limit: number;
  per_category_cap: number;
  global_cap: number;
  sort_by: "published_at_desc" | "published_at_asc";
}

export const DEFAULT_FETCH_POLICY: FetchPolicy = {
  per_source_limit: 20,
  per_category_cap: 60,
  global_cap: 240,
  sort_by: "published_at_desc",
};

/**
 * Apply policy: sort by published_at desc, then limit per source, per category, global.
 * Selection: take top N per source (by time), merge, dedupe by url, then cap per category and global.
 */
export function applyFetchPolicy<T extends { published_at?: string; url?: string; source_name?: string }>(
  items: T[],
  policy: FetchPolicy,
  getCategory?: (item: T) => string
): T[] {
  const sorted = [...items].sort((a, b) => {
    const ta = a.published_at ? new Date(a.published_at).getTime() : 0;
    const tb = b.published_at ? new Date(b.published_at).getTime() : 0;
    return policy.sort_by === "published_at_desc" ? tb - ta : ta - tb;
  });

  const bySource = new Map<string, T[]>();
  for (const it of sorted) {
    const src = it.source_name ?? "unknown";
    const arr = bySource.get(src) ?? [];
    if (arr.length < policy.per_source_limit) {
      arr.push(it);
      bySource.set(src, arr);
    }
  }

  const merged: T[] = [];
  const seenUrl = new Set<string>();
  for (const arr of bySource.values()) {
    for (const it of arr) {
      const url = it.url ?? it.id ?? "";
      if (seenUrl.has(url)) continue;
      seenUrl.add(url);
      merged.push(it);
    }
  }

  const byCat = getCategory
    ? new Map<string, T[]>()
    : null;
  if (byCat) {
    for (const it of merged) {
      const cat = getCategory(it) ?? "uncategorized";
      const arr = byCat.get(cat) ?? [];
      arr.push(it);
      byCat.set(cat, arr);
    }
  }

  const result: T[] = [];
  const catCounts = new Map<string, number>();
  for (const it of merged) {
    if (result.length >= policy.global_cap) break;
    const cat = getCategory ? (getCategory(it) ?? "uncategorized") : "default";
    const count = catCounts.get(cat) ?? 0;
    if (count >= policy.per_category_cap) continue;
    result.push(it);
    catCounts.set(cat, count + 1);
  }

  return result.sort((a, b) => {
    const ta = a.published_at ? new Date(a.published_at).getTime() : 0;
    const tb = b.published_at ? new Date(b.published_at).getTime() : 0;
    return policy.sort_by === "published_at_desc" ? tb - ta : ta - tb;
  });
}
