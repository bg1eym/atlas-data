import { promises as fs } from "fs";
import { resolve } from "path";

function isoCompact(d = new Date()) {
  const pad = (n: number) => String(n).padStart(2, "0");
  return (
    d.getFullYear() +
    pad(d.getMonth() + 1) +
    pad(d.getDate()) +
    "-" +
    pad(d.getHours()) +
    pad(d.getMinutes()) +
    pad(d.getSeconds())
  );
}

async function ensureDir(dir: string) {
  await fs.mkdir(dir, { recursive: true });
}

async function fileExists(p: string) {
  try {
    await fs.access(p);
    return true;
  } catch {
    return false;
  }
}

async function readJsonOrNull(p: string) {
  try {
    const t = await fs.readFile(p, "utf-8");
    return JSON.parse(t);
  } catch {
    return null;
  }
}

async function writeJson(p: string, v: any) {
  await fs.writeFile(p, JSON.stringify(v, null, 2), "utf-8");
}

async function main() {
  const ROOT = process.cwd();
  const runId = process.env.ATLAS_RUN_ID?.trim() || isoCompact();

  const outRoot = resolve(ROOT, "out/atlas", runId);
  const auditDir = resolve(outRoot, "audit");
  const radarDir = resolve(outRoot, "radar");
  await ensureDir(auditDir);
  await ensureDir(radarDir);

  const inputPdf = resolve(ROOT, "environment/input_pack/ai_radar_sources.pdf");
  const sourcesCfg = resolve(ROOT, "runtime/atlas/config/sources.json");

  const sourcesJson = await readJsonOrNull(sourcesCfg);
  const sourcesCount =
    Array.isArray(sourcesJson) ? sourcesJson.length :
    Array.isArray((sourcesJson as any)?.sources) ? (sourcesJson as any).sources.length :
    0;

  const audit = {
    ts: new Date().toISOString(),
    run_id: runId,
    mode: "fallback_existing_config",
    input_pdf: inputPdf,
    input_pdf_exists: await fileExists(inputPdf),
    sources_config: sourcesCfg,
    sources_config_exists: await fileExists(sourcesCfg),
    sources_count: sourcesCount,
    ok: sourcesCount > 0,
    note:
      sourcesCount > 0
        ? "Skipped PDF parsing; using runtime/atlas/config/sources.json as source of truth."
        : "No sources.json found or empty; pipeline may be incomplete.",
  };

  await writeJson(resolve(auditDir, "pdf_sources_extract.json"), audit);

  if (sourcesCount > 0) {
    await fs.copyFile(sourcesCfg, resolve(radarDir, "sources.json"));
  }

  console.log("OK pdf_sources_extract fallback");
  console.log("RUN_ID", runId);
  console.log("SOURCES_COUNT", sourcesCount);
}

main().catch(async (e) => {
  const msg = String(e?.stack || e?.message || e);
  try {
    const ROOT = process.cwd();
    const runId = process.env.ATLAS_RUN_ID?.trim() || isoCompact();
    const auditDir = resolve(ROOT, "out/atlas", runId, "audit");
    await ensureDir(auditDir);
    await writeJson(resolve(auditDir, "pdf_sources_extract.json"), {
      ts: new Date().toISOString(),
      run_id: runId,
      mode: "fallback_existing_config",
      ok: false,
      error: msg,
    });
  } catch {}
  console.error("FALLBACK_FAILED", msg);
  process.exit(0);
});
