#!/usr/bin/env node
// Parses the daisyUI light/dark themes in app.css and emits Penpot-importable
// multi-set DTCG tokens ($themes + $metadata + the `luxpkgs` set). oklch() is
// converted to hex because Penpot's token import rejects oklch.
//
// Usage: node design/generate_tokens.mjs
import { readFileSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = dirname(fileURLToPath(import.meta.url));
const APP_CSS = join(__dirname, "..", "luxpkgs", "assets", "css", "app.css");
const OUT = join(__dirname, "luxpkgs-tokens.json");

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

// One set with unique names: Penpot merges every active set into a single
// namespace, so a light and a dark "primary" would otherwise shadow each other.
const sets = {};

const token = (type, value) => ({ $type: type, $value: value });

function colorGroup(themeName) {
  const src = themes[themeName];
  const group = {};
  for (const key of COLOR_KEYS) {
    const raw = src[`color-${key}`];
    if (!raw) continue;
    const hex = parseOklch(raw);
    if (!hex) throw new Error(`Could not parse oklch for ${themeName}/${key}: ${raw}`);
    group[key] = token("color", hex);
  }
  return group;
}

sets.luxpkgs = {
  color: { light: colorGroup("light"), dark: colorGroup("dark") },
  radius: {
    selector: token("borderRadius", themes.dark["radius-selector"]),
    field: token("borderRadius", themes.dark["radius-field"]),
    box: token("borderRadius", themes.dark["radius-box"]),
  },
  size: {
    selector: token("dimension", themes.dark["size-selector"]),
    field: token("dimension", themes.dark["size-field"]),
  },
  border: token("dimension", themes.dark["border"]),
  depth: token("number", Number(themes.dark["depth"])),
  noise: token("number", Number(themes.dark["noise"])),
  font: {
    sans: token("fontFamily", parseThemeVar("font-sans")),
    display: token("fontFamily", parseThemeVar("font-display")),
    mono: token("fontFamily", parseThemeVar("font-mono")),
  },
};

// Without `$themes`/`$metadata` Penpot reads the file as one anonymous set
// named after the file and leaves it out of every active theme; the multi-set
// shape keeps the `luxpkgs` name and activates it through a theme.
const themesMeta = [
  {
    id: "mode-dark",
    name: "Dark",
    description: "",
    isSource: true,
    selectedTokenSets: { luxpkgs: "enabled" },
  },
  {
    id: "mode-light",
    name: "Light",
    description: "",
    isSource: false,
    selectedTokenSets: { luxpkgs: "enabled" },
  },
];

const doc = {
  $themes: themesMeta,
  $metadata: {
    tokenSetOrder: ["luxpkgs"],
    activeThemes: ["Dark"],
    activeSets: ["luxpkgs"],
  },
  luxpkgs: sets.luxpkgs,
};

// --- self-check -----------------------------------------------------------
function assert(cond, msg) {
  if (!cond) throw new Error(`self-check failed: ${msg}`);
}
assert(oklchToHex(1, 0, 0) === "#ffffff", "white");
assert(oklchToHex(0, 0, 0) === "#000000", "black");
assert(parseOklch("oklch(0.29 0.029 284.46)")?.length === 7, "parse dark base-100");
assert(Object.keys(sets.luxpkgs.color.light).length === 21, "21 light colors");
assert(Object.keys(sets.luxpkgs.color.dark).length === 21, "21 dark colors");

// --- write ----------------------------------------------------------------
writeFileSync(OUT, JSON.stringify(doc, null, 2) + "\n");

const count = (o) => JSON.stringify(o).match(/"\$value"/g)?.length ?? 0;
process.stdout.write(
  `Wrote ${OUT} (luxpkgs=${count(doc.luxpkgs)})\n`,
);
