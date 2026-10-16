#!/usr/bin/env node
// Parses the daisyUI light/dark themes in app.css and emits Penpot-importable
// DTCG tokens (first-level keys = token sets). oklch() is converted to hex
// because Penpot's token import rejects oklch.
//
// Usage: node design/generate_tokens.mjs
import { readFileSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = dirname(fileURLToPath(import.meta.url));
const APP_CSS = join(__dirname, "..", "luxpkgs", "assets", "css", "app.css");
const OUT = join(__dirname, "luxpkgs-tokens.json");
const OUT_THEMES = join(__dirname, "luxpkgs-tokens.$themes.json");

// --- oklch -> hex ---------------------------------------------------------
function oklchToHex(l, c, h) {
  const hr = (h * Math.PI) / 180;
  const a = c * Math.cos(hr);
  const b = c * Math.sin(hr);
  const l_ = l + 0.3963377774 * a + 0.2158037573 * b;
  const m_ = l - 0.1055613458 * a - 0.0638541728 * b;
  const s_ = l - 0.0894841775 * a - 1.291485548 * b;
  const L = l_ ** 3;
  const M = m_ ** 3;
  const S = s_ ** 3;
  const rl = 4.0767416621 * L - 3.3077115913 * M + 0.2309699292 * S;
  const gl = -1.2684380046 * L + 2.6097574011 * M - 0.3413193965 * S;
  const bl = -0.0041960863 * L - 0.7034186147 * M + 1.707614701 * S;
  const gamma = (x) => (x <= 0.0031308 ? 12.92 * x : 1.055 * x ** (1 / 2.4) - 0.055);
  const to255 = (x) => Math.round(Math.min(1, Math.max(0, gamma(x))) * 255);
  return (
    "#" +
    [to255(rl), to255(gl), to255(bl)].map((n) => n.toString(16).padStart(2, "0")).join("")
  );
}

function parseOklch(value) {
  const m = value.match(/oklch\(\s*([\d.]+%?)\s+([\d.]+%?)\s+([\d.]+%?)/i);
  if (!m) return null;
  const l = m[1].endsWith("%") ? parseFloat(m[1]) / 100 : parseFloat(m[1]);
  const c = m[2].endsWith("%") ? (parseFloat(m[2]) / 100) * 0.4 : parseFloat(m[2]);
  const h = parseFloat(m[3]);
  return oklchToHex(l, c, h);
}

// --- app.css parsing ------------------------------------------------------
const css = readFileSync(APP_CSS, "utf8");

function parseDecls(block) {
  const decls = {};
  for (const m of block.matchAll(/--([a-z0-9-]+)\s*:\s*([^;]+);/g)) decls[m[1]] = m[2].trim();
  return decls;
}

const themes = {};
for (const m of css.matchAll(/@plugin\s+"\.\.\/vendor\/daisyui-theme"\s*\{([^}]*)\}/g)) {
  const block = m[1];
  const name = block.match(/name:\s*"([^"]+)"/)?.[1];
  if (name) themes[name] = parseDecls(block);
}

function parseThemeVar(name) {
  const m = css.match(new RegExp(`--${name}\\s*:\\s*([^;]+);`, "s"));
  return m ? m[1].replace(/\s+/g, " ").trim() : null;
}

// --- build sets -----------------------------------------------------------
const COLOR_KEYS = [
  "base-100", "base-200", "base-300", "base-content",
  "primary", "primary-content", "secondary", "secondary-content",
  "accent", "accent-content", "neutral", "neutral-content",
  "info", "info-content", "success", "success-content",
  "warning", "warning-content", "error", "error-content",
  "grey",
];

const sets = {};

sets.core = {
  font: {
    sans: { $type: "fontFamily", $value: parseThemeVar("font-sans") },
    display: { $type: "fontFamily", $value: parseThemeVar("font-display") },
    mono: { $type: "fontFamily", $value: parseThemeVar("font-mono") },
  },
  radius: {
    selector: { $type: "borderRadius", $value: themes.dark["radius-selector"] },
    field: { $type: "borderRadius", $value: themes.dark["radius-field"] },
    box: { $type: "borderRadius", $value: themes.dark["radius-box"] },
  },
  size: {
    selector: { $type: "dimension", $value: themes.dark["size-selector"] },
    field: { $type: "dimension", $value: themes.dark["size-field"] },
  },
  border: { $type: "dimension", $value: themes.dark["border"] },
  depth: { $type: "number", $value: Number(themes.dark["depth"]) },
  noise: { $type: "number", $value: Number(themes.dark["noise"]) },
};

function colorSet(themeName) {
  const src = themes[themeName];
  const set = {};
  for (const key of COLOR_KEYS) {
    const raw = src[`color-${key}`];
    if (!raw) continue;
    const hex = parseOklch(raw);
    if (!hex) throw new Error(`Could not parse oklch for ${themeName}/${key}: ${raw}`);
    set[key] = { $type: "color", $value: hex };
  }
  return set;
}

sets.light = colorSet("light");
sets.dark = colorSet("dark");

// Tokens-Studio style theme groups (best-effort; Penpot may ignore this file).
const themeGroups = [
  { id: "mode-light", name: "Light", selectedTokenSets: { core: "enabled", light: "enabled", dark: "disabled" } },
  { id: "mode-dark", name: "Dark", selectedTokenSets: { core: "enabled", light: "disabled", dark: "enabled" } },
];

// --- self-check -----------------------------------------------------------
function assert(cond, msg) {
  if (!cond) throw new Error(`self-check failed: ${msg}`);
}
assert(oklchToHex(1, 0, 0) === "#ffffff", "white");
assert(oklchToHex(0, 0, 0) === "#000000", "black");
assert(parseOklch("oklch(0.29 0.029 284.46)")?.length === 7, "parse dark base-100");

// --- write ----------------------------------------------------------------
writeFileSync(OUT, JSON.stringify(sets, null, 2) + "\n");
writeFileSync(OUT_THEMES, JSON.stringify(themeGroups, null, 2) + "\n");

const count = (o) => JSON.stringify(o).match(/"\$value"/g)?.length ?? 0;
process.stdout.write(
  `Wrote ${OUT} (core=${count(sets.core)}, light=${count(sets.light)}, dark=${count(sets.dark)})\n`,
);
process.stdout.write(`Wrote ${OUT_THEMES}\n`);
