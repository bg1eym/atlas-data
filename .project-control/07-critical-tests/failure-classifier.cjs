#!/usr/bin/env node
/**
 * ACTF Failure Classifier — Evidence JSON → machine failure_mode
 * Input: _out/structural-evidence.json, _out/execution-evidence.json
 * Output: _out/classification.json
 */

const fs = require("fs");
const path = require("path");

const ROOT = process.env.PCK_ROOT || process.cwd();
const ACTF_DIR = path.join(ROOT, ".project-control/07-critical-tests");
const OUT_DIR = path.join(ACTF_DIR, "_out");
const STRUCTURAL_PATH = path.join(OUT_DIR, "structural-evidence.json");
const EXECUTION_PATH = path.join(OUT_DIR, "execution-evidence.json");
const ATLAS_RESULT_PATH = path.join(OUT_DIR, "atlas-result-evidence.json");
const CLASSIFICATION_PATH = path.join(OUT_DIR, "classification.json");

function loadJson(filePath) {
  try {
    const raw = fs.readFileSync(filePath, "utf8");
    return JSON.parse(raw);
  } catch {
    return null;
  }
}

const structural = loadJson(STRUCTURAL_PATH);
const execution = loadJson(EXECUTION_PATH);
const atlasResult = loadJson(ATLAS_RESULT_PATH);

let failure_mode = "OK";
let confidence = 1;
const signals = [];
let recommended_fix = "";

// Rule: structural required env missing → ENV_MISSING
if (structural && structural.required_fail) {
  if (structural.checks && structural.checks.env_presence && !structural.checks.env_presence.ok) {
    failure_mode = "ENV_MISSING";
    confidence = 0.95;
    signals.push("structural.env_presence.fail");
    recommended_fix = "Set required env keys from ACTF_REQUIRED_ENV_KEYS";
  } else if (structural.checks && structural.checks.root_path && !structural.checks.root_path.ok) {
    failure_mode = "ROOT_MISSING";
    confidence = 0.95;
    signals.push("structural.root_path.fail");
    recommended_fix = "Set ACTF_ROOT_DIR to valid project root";
  } else if (structural.checks && structural.checks.cwd_access && !structural.checks.cwd_access.ok) {
    failure_mode = "PERMISSION_DENIED";
    confidence = 0.9;
    signals.push("structural.cwd_access.fail");
    recommended_fix = "Ensure cwd is readable";
  } else {
    failure_mode = "ROOT_MISSING";
    confidence = 0.8;
    signals.push("structural.required_fail");
    recommended_fix = "Fix structural checks (env, root, cwd)";
  }
}

// Rule: execution stderr contains ENOENT + binary → BINARY_NOT_FOUND or SPAWN_ENOENT
if (failure_mode === "OK" && execution && execution.exit_code !== null && execution.exit_code !== 0) {
  const stderr = (execution.stderr_truncated || "").toLowerCase();
  const cmd = (execution.cmd || "").toLowerCase();

  if (stderr.includes("enoent") || stderr.includes("command not found") || stderr.includes("Command not found")) {
    if (stderr.includes("spawn") || cmd.includes("spawn")) {
      failure_mode = "SPAWN_ENOENT";
      confidence = 0.9;
      signals.push("execution.stderr.enoent");
      signals.push("execution.stderr.spawn");
      recommended_fix = "Binary not found in PATH; use absolute path or set PATH";
    } else {
      failure_mode = "BINARY_NOT_FOUND";
      confidence = 0.85;
      signals.push("execution.stderr.enoent_or_not_found");
      recommended_fix = "Binary not found; check PATH or use absolute path";
    }
  } else if (stderr.includes("atlas") && stderr.includes("exit")) {
    failure_mode = "ATLAS_PIPELINE_FAILED";
    confidence = 0.85;
    signals.push("execution.atlas_exit_nonzero");
    recommended_fix = "atlas:run failed; check stderr";
  } else if (stderr.includes("eacces")) {
    failure_mode = "PERMISSION_DENIED";
    confidence = 0.9;
    signals.push("execution.stderr.eacces");
    recommended_fix = "Permission denied; check file permissions";
  } else {
    failure_mode = "UNKNOWN";
    confidence = 0.5;
    signals.push("execution.exit_nonzero");
    recommended_fix = "Check stderr for details";
  }
}

// Rule: atlas-result-evidence — EVIDENCE_MISSING, ATLAS_EMPTY
if (failure_mode === "OK" && atlasResult) {
  if (atlasResult.error === "EVIDENCE_MISSING") {
    failure_mode = "EVIDENCE_MISSING";
    confidence = 0.9;
    signals.push("atlas_result.missing");
    recommended_fix = "result.json not found; run atlas:run first";
  } else if (atlasResult.error === "ATLAS_EMPTY") {
    failure_mode = "ATLAS_EMPTY";
    confidence = 0.9;
    signals.push("atlas_result.empty");
    recommended_fix = "items_count and categories_count both 0";
  }
}

// Rule: structural all pass + (execution exit 0 or probe) → OK
if (failure_mode === "OK") {
  const execOk = !execution || execution.exit_code === 0 || execution.exit_code === null;
  const structOk = !structural || !structural.required_fail;
  if (structOk && execOk) {
    failure_mode = "OK";
    confidence = 1;
    if (signals.length === 0) signals.push("all_checks_pass");
    recommended_fix = "";
  } else if (structural && structural.required_fail && signals.length === 0) {
    failure_mode = "ROOT_MISSING";
    confidence = 0.7;
    signals.push("structural.required_fail");
    recommended_fix = "Fix structural checks";
  }
}

const classification = {
  failure_mode,
  confidence,
  signals,
  recommended_fix,
};

fs.mkdirSync(OUT_DIR, { recursive: true });
fs.writeFileSync(CLASSIFICATION_PATH, JSON.stringify(classification, null, 2));
console.log(JSON.stringify(classification));
