#!/usr/bin/env node
// Converts captured scene JSON (design/scenes/*.json, produced by capture.mjs)
// into an importable Penpot file (design/luxpkgs.penpot) using @penpot/library.
//
//   nix shell nixpkgs#nodejs_22 -c node design/emit-penpot.mjs
//
// Env: SCREENS ("name=Label,..." default "landing=Landing"),
//      THEMES (default "dark,light"), GAP (px between theme boards, default 200).
import * as penpot from "@penpot/library";
import { createWriteStream, readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { Writable } from "node:stream";
import { fileURLToPath } from "node:url";

const __dirname = dirname(fileURLToPath(import.meta.url));
const SCENES = join(__dirname, "scenes");
const TOKENS = join(__dirname, "luxpkgs-tokens.json");
const OUT = join(__dirname, "luxpkgs.penpot");

const SCREENS = (process.env.SCREENS || "landing=Landing").split(",").map((s) => {
  const [name, label] = s.split("=");
  return { name: name.trim(), label: (label ?? name).trim() };
});
const THEMES = (process.env.THEMES || "dark,light").split(",").map((s) => s.trim());
const GAP = Number(process.env.GAP || 200);

// --- design tokens ---
const TOKEN_SET = JSON.parse(readFileSync(TOKENS, "utf8")).luxpkgs;

function remToPx(value) {
  const match = /^(-?[\d.]+)(rem|em|px)?$/.exec(String(value).trim());
  if (!match) return null;
  const n = Number(match[1]);
  return match[2] && match[2] !== "px" ? n * 16 : n;
}

const colorsByTheme = { dark: new Map(), light: new Map() };
for (const theme of Object.keys(colorsByTheme)) {
  for (const [key, tok] of Object.entries(TOKEN_SET.color[theme])) {
    const hex = String(tok.$value).toLowerCase();
    if (!colorsByTheme[theme].has(hex)) colorsByTheme[theme].set(hex, `color.${theme}.${key}`);
  }
}

// 4px is both radius.selector and radius.box, so only a value with a single
// name (8px = radius.field) can be bound without ambiguity.
const radiusTokenPx = new Map();
for (const [key, tok] of Object.entries(TOKEN_SET.radius)) {
  const px = remToPx(tok.$value);
  radiusTokenPx.set(px, radiusTokenPx.has(px) ? null : `radius.${key}`);
}
const borderTokenPx = remToPx(TOKEN_SET.border.$value);

// Bound only on exact, unambiguous values: a translucent fill would lose its
// alpha and a computed oddity has no token to point at.
function appliedTokensOf(fills, strokes, radii) {
  const applied = {};
  const colors = colorsByTheme[CURRENT_THEME];
  const fill = fills && fills.length === 1 ? fills[0] : null;
  if (fill && fill["fill-color"] && (fill["fill-opacity"] ?? 1) === 1) {
    const name = colors.get(String(fill["fill-color"]).toLowerCase());
    if (name) applied.fill = name;
  }
  const stroke = strokes && strokes.length === 1 ? strokes[0] : null;
  if (stroke && stroke["stroke-color"] && (stroke["stroke-opacity"] ?? 1) === 1) {
    const name = colors.get(String(stroke["stroke-color"]).toLowerCase());
    if (name) applied["stroke-color"] = name;
  }
  if (stroke && stroke["stroke-width"] === borderTokenPx) applied["stroke-width"] = "border";
  for (const [attr, px] of Object.entries(radii || {})) {
    const name = radiusTokenPx.get(px);
    if (name) applied[attr] = name;
  }
  return Object.keys(applied).length ? applied : null;
}

// --- color / geometry helpers ---------------------------------------------
function splitTop(s) {
  const out = [];
  let depth = 0, cur = "";
  for (const ch of s) {
    if (ch === "(") depth++;
    else if (ch === ")") depth--;
    if (ch === "," && depth === 0) {
      out.push(cur);
      cur = "";
    } else cur += ch;
  }
  out.push(cur);
  return out.map((x) => x.trim());
}

function hex3(r, g, b) {
  const h = (n) => Math.max(0, Math.min(255, Math.round(n))).toString(16).padStart(2, "0");
  return "#" + h(r) + h(g) + h(b);
}

function oklabToRgb(l, a, b) {
  const l_ = l + 0.3963377774 * a + 0.2158037573 * b;
  const m_ = l - 0.1055613458 * a - 0.0638541728 * b;
  const s_ = l - 0.0894841775 * a - 1.291485548 * b;
  const L = l_ ** 3, M = m_ ** 3, S = s_ ** 3;
  const rl = 4.0767416621 * L - 3.3077115913 * M + 0.2309699292 * S;
  const gl = -1.2684380046 * L + 2.6097574011 * M - 0.3413193965 * S;
  const bl = -0.0041960863 * L - 0.7034186147 * M + 1.707614701 * S;
  const gamma = (x) => (x <= 0.0031308 ? 12.92 * x : 1.055 * x ** (1 / 2.4) - 0.055);
  const to255 = (x) => Math.max(0, Math.min(255, gamma(x) * 255));
  return [to255(rl), to255(gl), to255(bl)];
}

function parseColor(s) {
  if (!s) return null;
  s = s.trim().toLowerCase();
  if (s === "transparent" || s === "none") return null;
  const a = (v) => (v === undefined ? 1 : Math.max(0, Math.min(1, parseFloat(v))));
  let m;
  if (s.startsWith("#")) {
    if (s.length === 4) return { hex: "#" + [...s.slice(1)].map((c) => c + c).join(""), alpha: 1 };
    if (s.length === 5) return { hex: "#" + [...s.slice(1, 4)].map((c) => c + c).join(""), alpha: a(parseInt(s[4] + s[4], 16) / 255) };
    if (s.length === 9) return { hex: s.slice(0, 7), alpha: a(parseInt(s.slice(7), 16) / 255) };
    return { hex: s.slice(0, 7), alpha: 1 };
  }
  if ((m = s.match(/^rgba?\(([^)]+)\)$/))) {
    const p = m[1].split(/[\s,/]+/).filter(Boolean).map(Number);
    const alpha = a(p.length > 3 ? p[3] : 1);
    if (alpha === 0) return null;
    return { hex: hex3(p[0], p[1], p[2]), alpha };
  }
  if ((m = s.match(/^oklch\(([^)]+)\)$/))) {
    const p = m[1].split(/[\s,/]+/).filter(Boolean);
    const alpha = a(p.length > 3 ? parseFloat(p[3]) : 1);
    if (alpha === 0) return null;
    const l = p[0].endsWith("%") ? parseFloat(p[0]) / 100 : parseFloat(p[0]);
    const c = p[1].endsWith("%") ? (parseFloat(p[1]) / 100) * 0.4 : parseFloat(p[1]);
    const rad = (parseFloat(p[2]) * Math.PI) / 180;
    return { hex: hex3(...oklabToRgb(l, c * Math.cos(rad), c * Math.sin(rad))), alpha };
  }
  if ((m = s.match(/^oklab\(([^)]+)\)$/))) {
    const p = m[1].split(/[\s,/]+/).filter(Boolean);
    const alpha = a(p.length > 3 ? parseFloat(p[3]) : 1);
    if (alpha === 0) return null;
    const l = p[0].endsWith("%") ? parseFloat(p[0]) / 100 : parseFloat(p[0]);
    return { hex: hex3(...oklabToRgb(l, parseFloat(p[1]), parseFloat(p[2]))), alpha };
  }
  if ((m = s.match(/^color\(([^)]+)\)$/))) {
    const p = m[1].split(/[\s/]+/).filter(Boolean);
    p.shift();
    const n = p.map(Number);
    const alpha = a(n.length > 3 ? n[3] : 1);
    if (alpha === 0) return null;
    return { hex: hex3(n[0] * 255, n[1] * 255, n[2] * 255), alpha };
  }
  return null;
}

function parseGradient(bg, w, h) {
  if (!bg || bg === "none") return null;
  // Multiple layers (daisyUI draws the select chevron with two gradients)
  // would garble the stop list, so skip the whole value instead.
  if ((bg.match(/gradient\(/g) || []).length > 1) return null;
  const m = bg.match(/^(linear-gradient|radial-gradient)\(([\s\S]*)\)$/);
  if (!m) return null;
  const type = m[1] === "linear-gradient" ? "linear" : "radial";
  const parts = splitTop(m[2]);
  let angle = 180; // CSS default "to bottom"
  if (type === "linear") {
    const a = parts[0].match(/^([\d.]+)deg$/);
    if (a) angle = parseFloat(a[1]);
    else if (/^to\s+/.test(parts[0])) {
      const dir = parts[0].replace(/^to\s+/, "").replace(/\s+in\s+\S+$/, "").trim();
      const angles = {
        top: 0, right: 90, bottom: 180, left: 270,
        "right top": 45, "top right": 45, "right bottom": 135, "bottom right": 135,
        "bottom left": 225, "left bottom": 225, "top left": 315, "left top": 315,
      };
      angle = angles[dir] ?? 180;
    }
    else parts.unshift("180deg");
  }
  const stops = [];
  for (const p of parts) {
    const cm = p.match(/^(oklch\([^)]*\)|oklab\([^)]*\)|color\([^)]*\)|rgba?\([^)]*\)|#[0-9a-fA-F]{3,8})/);
    if (!cm) continue;
    const c = parseColor(cm[1]);
    if (!c) continue;
    const posm = p.slice(cm[1].length).match(/(-?[\d.]+)%/);
    stops.push({ color: c.hex, opacity: c.alpha, offset: posm ? Math.max(0, Math.min(1, parseFloat(posm[1]) / 100)) : null });
  }
  if (stops.length < 2) return null;
  stops.forEach((s, i) => {
    if (s.offset === null) s.offset = i / (stops.length - 1);
  });
  // Penpot stores the gradient line as fractions of the shape box (the renderer
  // maps it back with x + width * start-x), so the pixel endpoints computed
  // below must be divided by the box size.
  if (type === "linear") {
    const rad = (angle * Math.PI) / 180;
    const dx = Math.sin(rad), dy = -Math.cos(rad);
    const len = Math.abs(w * dx) + Math.abs(h * dy);
    const cx = w / 2, cy = h / 2;
    return {
      type, width: 1,
      "start-x": (cx - (dx * len) / 2) / w, "start-y": (cy - (dy * len) / 2) / h,
      "end-x": (cx + (dx * len) / 2) / w, "end-y": (cy + (dy * len) / 2) / h,
      stops,
    };
  }
  const r = Math.max(w, h) / 2;
  return { type, width: 1, "start-x": 0.5, "start-y": 0.5, "end-x": 0.5 + r / w, "end-y": 0.5, stops };
}

function fillsOf(node) {
  const st = node.style;
  const bg = parseColor(st.backgroundColor);
  if (bg) return [{ "fill-color": bg.hex, "fill-opacity": bg.alpha }];
  const grad = parseGradient(st.backgroundImage, node.rect.w, node.rect.h);
  if (grad) return [{ "fill-color-gradient": grad }];
  return [];
}

function uniformBorder(st) {
  const w = st.borderWidth.map((v) => parseFloat(v) || 0);
  const width = Math.max(...w);
  if (width <= 0) return 0;
  return w.every((v) => v === width) &&
    st.borderStyle.every((s) => s === st.borderStyle[0]) &&
    st.borderColor.every((c) => c === st.borderColor[0])
    ? width
    : 0;
}

function strokesOf(node) {
  const st = node.style;
  const width = uniformBorder(st);
  if (!width) return [];
  if (st.borderStyle[0] === "none" || st.borderStyle[0] === "hidden") return [];
  const color = parseColor(st.borderColor[0]);
  if (!color) return [];
  return [{ "stroke-color": color.hex, "stroke-opacity": color.alpha, "stroke-style": st.borderStyle[0] || "solid", "stroke-width": width, "stroke-alignment": "center" }];
}

// Penpot strokes are all-around only; a partial border (e.g. border-top) is
// drawn as a thin filled rect per bordered side.
// ponytail: no dash/cap fidelity for partial borders; add if a design needs it.
function borderSidesOf(node) {
  const st = node.style;
  if (uniformBorder(st)) return [];
  const { x, y, w: W, h: H } = node.rect;
  const names = ["top", "right", "bottom", "left"];
  const out = [];
  for (let i = 0; i < 4; i++) {
    const bw = parseFloat(st.borderWidth[i]) || 0;
    const style = st.borderStyle[i];
    if (bw <= 0 || style === "none" || style === "hidden") continue;
    const c = parseColor(st.borderColor[i]);
    if (!c) continue;
    const r =
      i === 0 ? { x, y, width: W, height: bw } :
      i === 1 ? { x: x + W - bw, y, width: bw, height: H } :
      i === 2 ? { x, y: y + H - bw, width: W, height: bw } :
                { x, y, width: bw, height: H };
    out.push({ name: nameOf(node) + " (" + names[i] + " border)", ...r, fills: [{ "fill-color": c.hex, "fill-opacity": c.alpha }] });
  }
  return out;
}

// CSS blur() is a filter; Penpot's equivalent is a layer blur on the shape.
function blurOf(node) {
  const m = (node.style.filter || "").match(/blur\(([\d.]+)px\)/);
  return m ? parseFloat(m[1]) : 0;
}

function radiusOf(node) {
  const p = (node.style.borderRadius || "").trim().split(/\s+/).map((v) => parseFloat(v) || 0);
  let r;
  if (p.length === 1) r = [p[0], p[0], p[0], p[0]];
  else if (p.length === 2) r = [p[0], p[1], p[0], p[1]];
  else if (p.length === 3) r = [p[0], p[1], p[2], p[1]];
  else r = [p[0] || 0, p[1] || 0, p[2] || 0, p[3] || 0];
  // Firefox reports an oversized border-radius (a pill's 9999px, a 50% circle)
  // as Float32 max, which Penpot rejects; cap at half the box like the browser.
  const max = Math.min(node.rect.w, node.rect.h) / 2;
  return r.map((v) => Math.min(Math.max(v, 0), max));
}

function shadowOf(node) {
  const s = node.style.boxShadow;
  if (!s || s === "none") return [];
  // CSS lists layers front-to-back. Skip fully transparent layers: daisyUI
  // uses them as no-op resets and they would otherwise draw as opaque black
  // (the old regex missed oklch()/oklab() colors, defaulting to #000).
  for (const layer of splitTop(s)) {
    const inset = /inset/.test(layer);
    const nums = (layer.match(/-?[\d.]+px/g) || []).map(parseFloat);
    const [ox = 0, oy = 0, blur = 0, spread = 0] = nums;
    const colm = layer.match(/(oklch\([^)]*\)|oklab\([^)]*\)|rgba?\([^)]*\)|#[0-9a-fA-F]{3,8})/i);
    const c = colm ? parseColor(colm[1]) : null;
    if (!c) continue;
    return [{ id: crypto.randomUUID(), style: inset ? "inner-shadow" : "drop-shadow", "offset-x": ox, "offset-y": oy, blur, spread, hidden: false, color: { color: c.hex, opacity: c.alpha } }];
  }
  return [];
}

function firstFamily(s) {
  return (s || "").split(",")[0].replace(/['"]/g, "").trim() || "sans-serif";
}

const FONTS = {
  "Nunito Variable":       { id: "gfont-nunito",       family: "Nunito" },
  "Outfit Variable":       { id: "gfont-outfit",       family: "Outfit" },
  "Martian Mono Variable": { id: "gfont-martian-mono", family: "Martian Mono" },
};

const variantOf = (w, it) => (w === 400 ? (it ? "italic" : "regular") : it ? `${w}italic` : String(w));

// The app's text is exactly Tailwind's scale, so the styles are named after it
// (text-sm, text-sm-semibold) and grouped per family in Penpot's Assets panel.
const SIZE_SCALE = {
  12: { token: "xs", line: 16 },
  14: { token: "sm", line: 20 },
  16: { token: "base", line: 24 },
  18: { token: "lg", line: 28 },
  20: { token: "xl", line: 28 },
  24: { token: "2xl", line: 32 },
  30: { token: "3xl", line: 36 },
  36: { token: "4xl", line: 40 },
};
const WEIGHT_SUFFIX = { 400: "", 500: "-medium", 600: "-semibold", 700: "-bold" };
const FAMILY_PATH = {
  "Nunito Variable": "Body",
  "Outfit Variable": "Display",
  "Martian Mono Variable": "Mono",
};
const TYPOGRAPHIES = new Map();

// Only the canonical combinations get a style; a computed line-height or a
// stray size keeps its literal attributes instead.
function typographySpec(node) {
  const st = node.style || {};
  const scale = SIZE_SCALE[Math.round(parseFloat(st.fontSize))];
  if (!scale) return null;
  const weight = parseInt(st.fontWeight, 10) || 400;
  const suffix = WEIGHT_SUFFIX[weight];
  if (suffix === undefined) return null;
  const path = FAMILY_PATH[firstFamily(st.fontFamily)];
  if (!path) return null;
  if (Math.abs(parseFloat(st.lineHeight) - scale.line) > 0.01) return null;
  if (st.letterSpacing && st.letterSpacing !== "normal" && parseFloat(st.letterSpacing)) return null;
  const italic = st.fontStyle === "italic";
  const name = `text-${scale.token}${suffix}${italic ? "-italic" : ""}`;
  return { key: `${path}|${name}`, path, name, family: firstFamily(st.fontFamily), size: Math.round(parseFloat(st.fontSize)), weight, italic, line: scale.line };
}

function registerTypography(node) {
  if (!node.text) return;
  const spec = typographySpec(node);
  if (spec && !TYPOGRAPHIES.has(spec.key)) TYPOGRAPHIES.set(spec.key, spec);
}

function typographyOf(node) {
  const spec = typographySpec(node);
  return spec ? TYPOGRAPHIES.get(spec.key) : null;
}

function walkScene(node, fn) {
  fn(node);
  for (const child of node.children || []) walkScene(child, fn);
}

function fontAttrsOf(st) {
  const cssFamily = firstFamily(st.fontFamily);
  const font = FONTS[cssFamily] || { family: cssFamily };
  const weight = parseInt(st.fontWeight, 10) || 400;
  const italic = st.fontStyle === "italic";
  const size = parseFloat(st.fontSize) || 16;
  const lh = st.lineHeight && st.lineHeight !== "normal" ? parseFloat(st.lineHeight) / size : 1.2;
  const ls = st.letterSpacing && st.letterSpacing !== "normal" ? String(parseFloat(st.letterSpacing) || 0) : "0";
  const align =
    { start: "left", end: "right", left: "left", right: "right", center: "center", justify: "justify" }[st.textAlign] || "left";
  const attrs = {
    "font-family": font.family,
    "font-size": String(size),
    "font-weight": String(weight),
    "font-style": italic ? "italic" : "normal",
    "line-height": String(lh),
    "letter-spacing": ls,
    "text-transform": st.textTransform || "none",
    "text-decoration": st.textDecoration || "none",
    "text-align": align,
    "text-direction": "ltr",
  };
  if (font.id) {
    attrs["font-id"] = font.id;
    attrs["font-variant-id"] = variantOf(weight, italic);
  }
  return attrs;
}

function textContentOf(node, nodeFills, typo) {
  const c = parseColor(node.style.color);
  // A gradient-clipped heading has a transparent color; Penpot resolves the
  // fill per text node, so carry the shape gradient down instead of black.
  const fill =
    nodeFills || [{ "fill-color": c ? c.hex : "#000000", "fill-opacity": c ? c.alpha : 1 }];
  const font = fontAttrsOf(node.style);
  const ref = typo ? { "typography-ref-id": typo.id, "typography-ref-file": FILE_ID } : {};
  // One paragraph per captured visual line (Penpot's canonical line model).
  const paragraphs = String(node.text).split("\n").map((line) => ({
    type: "paragraph",
    ...font,
    ...ref,
    fills: fill,
    children: [{ text: line, ...font, ...ref, fills: fill }],
  }));
  return { type: "root", children: [{ type: "paragraph-set", children: paragraphs }] };
}

const BOARD_IDS = new Map();
const OVERLAY_IDS = new Map();
let FILE_ID = null;
let SUPPRESS_INTERACTIONS = false;
// Overlay frames are parked off-canvas; the viewer ignores a manual overlay's
// own x/y and uses the interaction's "overlay-position" instead.
const OVERLAY_X = -2600;
const OVERLAY_Y = 0;
let BASE = "";
let CURRENT_SCREEN = "";
let CURRENT_THEME = "";
const PATH_TO_SCREEN = new Map();

function resolveUrl(href) {
  if (href.startsWith("#")) return null;
  try {
    return new URL(href, BASE).href;
  } catch {
    return null;
  }
}

function resolvePath(href) {
  const url = resolveUrl(href);
  if (!url) return null;
  try {
    return new URL(url).pathname;
  } catch {
    return null;
  }
}

function collectOverlays(node, out = []) {
  if (node.overlay) {
    out.push(node);
    return out;
  }
  for (const c of node.children || []) collectOverlays(c, out);
  return out;
}

function firstOverlay(node) {
  for (const c of node.children || []) {
    if (c.overlay) return c;
    const nested = firstOverlay(c);
    if (nested) return nested;
  }
  return null;
}

function interactionsOf(node, inOverlay) {
  // A component master is a library asset, not a screen: its links have no
  // destination on the Components page, so they are not emitted at all.
  if (SUPPRESS_INTERACTIONS) return null;
  const out = [];
  if (node.href) {
    // A link to a board on this same Penpot page becomes in-file navigation
    // (Penpot only resolves a destination within the current page); anything
    // else, including another captured route, opens in the browser.
    const screen = PATH_TO_SCREEN.get(resolvePath(node.href));
    const dest = screen === CURRENT_SCREEN && BOARD_IDS.get(`${screen}.${CURRENT_THEME}`);
    if (dest) out.push({ "event-type": "click", "action-type": "navigate", destination: dest });
    else {
      const url = resolveUrl(node.href);
      if (url) out.push({ "event-type": "click", "action-type": "open-url", url });
    }
  }
  if (inOverlay && node.text) {
    const theme = node.text.trim().toLowerCase() === "light" ? "light" : "dark";
    const dest = BOARD_IDS.get(`${CURRENT_SCREEN}.${theme}`);
    if (dest) out.push({ "event-type": "click", "action-type": "navigate", destination: dest });
  }
  if (node.class && /(^|\s)dropdown(\s|$)/.test(node.class)) {
    const ov = firstOverlay(node);
    if (ov)
      out.push({
        "event-type": "click",
        "action-type": "toggle-overlay",
        destination: OVERLAY_IDS.get(ov),
        // Manual overlays render at this point relative to the base frame; the
        // overlay frame's own x/y is ignored by the viewer.
        "overlay-position": { x: ov.rect.x, y: ov.rect.y },
        "overlay-pos-type": "manual",
        "close-click-outside": true,
        animation: { "animation-type": "dissolve", duration: 200, easing: "ease" },
      });
  }
  return out.length ? out : null;
}

// Layer names should read like the page does. Component roles first, then
// plain tag names, then a title-cased class, so nothing shows up as
// "div.flex.items-start.justify-between" in the layers panel.
const UTILITY_PREFIX =
  /^(flex|grid|hidden|block|inline|contents|static|fixed|absolute|relative|sticky|antialiased|truncate|group|peer|sr-only|isolate|visible|invisible|order|columns|float|clear|object|aspect|transform|filter|backdrop|will-change|contain|w|min-w|max-w|h|min-h|max-h|p|px|py|pt|pb|pl|pr|m|mx|my|mt|mb|ml|mr|gap|space|items|justify|self|content|place|z|text|font|leading|tracking|bg|border|rounded|shadow|opacity|transition|duration|ease|delay|animate|overflow|whitespace|break|list|cursor|select|pointer|fill|stroke|top|left|right|bottom|inset|translate|scale|rotate|origin|skew|ring|outline|resize|appearance|accent|caret|decoration|indent|align|vertical|divide|snap|scroll|touch|hue-rotate|saturate|grayscale|invert|sepia|blur|brightness|contrast|mix-blend|line-clamp|prose)(-|$)/;

const TITLES = {
  div: "Container", span: "Text", p: "Text", a: "Link", button: "Button",
  ul: "List", ol: "List", li: "List item", svg: "Icon", img: "Image",
  label: "Label", table: "Table", tr: "Table row", td: "Table cell",
  th: "Table header", thead: "Table head", tbody: "Table body",
  path: "Shape", use: "Shape", small: "Small text", code: "Code",
};

const BUTTON_VARIANTS = [
  "primary", "secondary", "accent", "neutral", "info", "success", "warning",
  "error", "ghost", "outline", "link",
];

const titleCase = (s) => s.replace(/[-_]+/g, " ").replace(/\b\w/g, (m) => m.toUpperCase());

function nameOf(node) {
  const cls = (node.class || "").split(/\s+/).filter(Boolean);
  const has = (c) => cls.includes(c);

  if (cls.includes("btn")) {
    const variant = BUTTON_VARIANTS.find((v) => has("btn-" + v));
    return variant ? `Button ${variant}` : "Button";
  }
  if (node.tag === "a" && /^\/package\//.test(node.href || "")) return "Package box";
  if (has("navbar")) return "Navbar";
  if (has("page-container")) return "Page container";
  if (has("divider") || node.tag === "hr") return "Divider";
  if (has("collapse")) return "Accordion";
  if (has("badge")) return "Badge";
  if (has("toggle")) return "Toggle";
  if (has("dropdown-content")) return "Dropdown menu";
  if (has("dropdown")) return "Dropdown";
  if (node.inputType === "checkbox") return "Checkbox";
  if (node.inputType) return "Input";
  if (node.tag === "svg") return "Icon";
  if (node.tag === "img") return node.alt || "Image";
  if (node.tag === "footer") return "Footer";
  if (node.tag === "header") return "Header";
  if (node.tag === "main") return "Main";
  if (node.tag === "nav") return "Navigation";
  if (node.tag === "section") return "Section";
  if (node.text) return node.text.split("\n")[0].slice(0, 40);
  const meaningful = cls.find((c) => !c.includes(":") && !UTILITY_PREFIX.test(c));
  if (meaningful) return titleCase(meaningful);
  return TITLES[node.tag] || titleCase(node.tag || "Node");
}

// daisyUI draws both the select caret and the collapse arrow in CSS (stacked
// gradients and an ::after pseudo-element), which a capture cannot see, so
// redraw them as a stroked chevron on the right edge.
function chevronOf(node, bx, by) {
  const isSelect = node.tag === "select";
  const isArrow = node.class && /(^|\s)collapse-title(\s|$)/.test(node.class);
  if (!isSelect && !isArrow) return null;
  const { x, y, w, h } = node.rect;
  const cw = 10, ch = 6;
  const X = x + bx + w - (isSelect ? 14 : 24) - cw;
  const Y = y + by + (h - ch) / 2;
  const color = parseColor(node.style.color) || { hex: "#000000", alpha: 1 };
  return {
    name: isSelect ? "select chevron" : "collapse arrow",
    x: X,
    y: Y,
    width: cw,
    height: ch,
    content: `M${X} ${Y} L${X + cw / 2} ${Y + ch} L${X + cw} ${Y}`,
    strokes: [{
      "stroke-color": color.hex,
      "stroke-opacity": color.alpha,
      "stroke-style": "solid",
      "stroke-width": 2,
      "stroke-alignment": "center",
    }],
  };
}

// --- emit -----------------------------------------------------------------
// The shapes a node draws on its own, ignoring its children. Shared with
// willEmit so the group decision cannot drift from what actually gets emitted.
function nodeParts(node) {
  const { w, h } = node.rect;
  const sized = w >= 1 && h >= 1;
  const fills = sized ? fillsOf(node) : [];
  const strokes = sized ? strokesOf(node) : [];
  const borders = sized ? borderSidesOf(node) : [];
  const [r1, r2, r3, r4] = sized ? radiusOf(node) : [0, 0, 0, 0];
  // CSS clips a gradient to its own text (bg-clip-text + a transparent color),
  // which Penpot expresses as a gradient fill on the text shape, not a rect
  // sitting behind a solid-colored text.
  const clipText = !!(sized && node.text && fills.some((f) => f["fill-color-gradient"]) &&
    !parseColor(node.style.color));
  // daisyUI paints the divider with ::before/::after, so the node itself has
  // neither border nor background and would otherwise emit nothing.
  const divider = !!(sized && node.class && /(^|\s)divider(\s|$)/.test(node.class));
  // A radius alone draws nothing (daisyUI ghost buttons are transparent
  // rounded boxes), so only open a rect for an actual fill, stroke or shadow.
  const box = !clipText &&
    (fills.length || strokes.length || shadowOf(node).length);
  return {
    sized, fills, strokes, borders, r1, r2, r3, r4, clipText, divider, box,
    hasBox: box || borders.length || divider,
  };
}

const willEmitCache = new WeakMap();

// A group with no children has no geometry and Penpot rejects it on import,
// so only open a group when the subtree actually draws something. A node that
// merely carries a link (an sr-only skip link, an empty anchor) is not enough.
function willEmit(node) {
  const cached = willEmitCache.get(node);
  if (cached !== undefined) return cached;
  const parts = nodeParts(node);
  const result = parts.hasBox || (parts.sized && (node.img || node.text)) ||
    (node.children || []).some((c) => !c.overlay && willEmit(c));
  willEmitCache.set(node, result);
  return result;
}

function emitNode(context, node, bx, by, inOverlay, clip = [0, 0, 0, 0]) {
  const { x, y, w, h } = node.rect;
  const X = x + bx, Y = y + by;
  const { sized, fills, strokes, borders, r1, r2, r3, r4, clipText, divider, box } =
    nodeParts(node);
  const opacity = parseFloat(node.style.opacity);
  const interactions = interactionsOf(node, inOverlay);
  const draws = willEmit(node);

  // Mirror the DOM: wrap this element's shapes (and its children) in a group.
  if (draws) context.addGroup({ name: nameOf(node), ...(interactions ? { interactions } : {}) });

  if (box) {
    const shape = { name: nameOf(node), x: X, y: Y, width: w, height: h };
    // Always set fills, even empty: the library otherwise defaults rects to an
    // opaque #B1B2B5, which fills transparent/stroked-only shapes gray.
    shape.fills = fills;
    if (strokes.length) shape.strokes = strokes;
    if (r1 || r2 || r3 || r4) Object.assign(shape, { r1, r2, r3, r4 });
    const shadow = shadowOf(node);
    if (shadow.length) shape.shadow = shadow;
    // Blur only compact round blobs: a layer blur on a large overlay layer
    // (the donation card's glow divs) hazes the card content underneath.
    const blur = blurOf(node);
    if (blur > 0 && r1 >= Math.min(w, h) / 2) {
      shape.blur = { id: crypto.randomUUID(), type: "layer-blur", value: blur, hidden: false };
    }
    if (!Number.isNaN(opacity) && opacity < 1) shape.opacity = opacity;
    const applied = appliedTokensOf(fills, strokes, { r1, r2, r3, r4 });
    if (applied) shape["applied-tokens"] = applied;
    context.addRect(shape);
  }

  for (const b of borders) context.addRect({ ...b, x: b.x + bx, y: b.y + by });

  if (divider) {
    // A hairline of base-content at 10% (daisyUI --divider-color), centred.
    const line = parseColor(node.style.color) || { hex: "#000000", alpha: 1 };
    context.addRect({
      name: nameOf(node),
      x: X,
      y: Y + (h - 2) / 2,
      width: w,
      height: 2,
      fills: [{ "fill-color": line.hex, "fill-opacity": line.alpha * 0.1 }],
    });
  }

  if (sized && node.tag === "input" && /(^|\s)toggle(\s|$)/.test(node.class || "")) {
    // daisyUI draws the toggle knob with a pseudo-element: a square at the
    // inset padding, pushed to the right column when checked.
    const k = h - 8;
    const track = parseColor((node.style.borderColor || [])[0]);
    context.addRect({
      name: nameOf(node) + " knob",
      x: node.checked ? X + w - 4 - k : X + 4,
      y: Y + 4,
      width: k,
      height: k,
      r1: 4,
      r2: 4,
      r3: 4,
      r4: 4,
      fills: [{
        "fill-color": track ? track.hex : "#000000",
        "fill-opacity": track ? track.alpha : 1,
      }],
    });
  }

  if (sized && node.img) {
    const bytes = Buffer.from(node.img.split(",")[1], "base64");
    const mediaName = nameOf(node) + ".png";
    const mediaId = context.addFileMedia(
      { name: mediaName, width: w, height: h },
      new Blob([bytes], { type: "image/png" }),
    );
    const imgShape = {
      name: nameOf(node),
      x: X,
      y: Y,
      width: w,
      height: h,
      fills: [
        {
          "fill-image": {
            id: mediaId,
            width: w,
            height: h,
            mtype: "image/png",
            name: mediaName,
            "keep-aspect-ratio": false,
          },
        },
      ],
    };
    // The circle usually sits on an overflow-hidden wrapper while the img
    // itself reports radius 0, so fall back to the clipping radius above.
    const [ir1, ir2, ir3, ir4] = (r1 || r2 || r3 || r4) ? [r1, r2, r3, r4] : clip;
    if (ir1 || ir2 || ir3 || ir4) Object.assign(imgShape, { r1: ir1, r2: ir2, r3: ir3, r4: ir4 });
    if (!Number.isNaN(opacity) && opacity < 1) imgShape.opacity = opacity;
    context.addRect(imgShape);
  }

  if (sized && node.text) {
    // Position at the measured glyph box, not the padded element box, and let
    // the shape size itself so explicit line breaks are never re-wrapped.
    const tb = node.textBox || { x, y, w, h };
    const typo = typographyOf(node);
    context.addText({
      name: nameOf(node),
      x: tb.x + bx,
      y: tb.y + by,
      width: tb.w,
      height: tb.h,
      "grow-type": "auto-width",
      ...(clipText ? { fills } : {}),
      ...(typo ? { "typography-ref-id": typo.id, "typography-ref-file": FILE_ID } : {}),
      content: textContentOf(node, clipText ? fills : undefined, typo),
    });
  }

  const chevron = chevronOf(node, bx, by);
  if (chevron) context.addPath(chevron);

  // CSS clips children to a rounded overflow-hidden box; carry that radius
  // down so nested media is rounded the same way.
  const childClip = node.style.overflow === "hidden" && (r1 || r2 || r3 || r4)
    ? [r1, r2, r3, r4]
    : clip;
  for (const c of node.children || []) {
    if (c.overlay) continue;
    emitNode(context, c, bx, by, inOverlay, childClip);
  }

  if (draws) context.closeGroup();
}

function emitOverlays(context, root, themeIndex) {
  // Park each overlay off-canvas: one column per theme, stacked vertically, so
  // the editor does not draw the dark and light overlays on top of each other.
  // The viewer ignores a manual overlay frame's own x/y anyway.
  const ox = OVERLAY_X - themeIndex * 320;
  let oy = OVERLAY_Y;
  for (const ov of collectOverlays(root)) {
    const { x, y, w, h } = ov.rect;
    const fills = fillsOf(ov);
    const strokes = strokesOf(ov);
    const [r1, r2, r3, r4] = radiusOf(ov);
    context.addBoard({
      id: OVERLAY_IDS.get(ov),
      name: nameOf(ov) + " (overlay)",
      x: ox,
      y: oy,
      width: w,
      height: h,
      fills,
      ...(strokes.length ? { strokes } : {}),
      ...(r1 || r2 || r3 || r4 ? { r1, r2, r3, r4 } : {}),
    });
    for (const c of ov.children || []) emitNode(context, c, ox - x, oy - y, true);
    context.closeBoard();
    oy += h + 40;
  }
}

// --- components ---

const COMPONENT_COLUMN_X = 2560 + GAP;

function nodeHasClass(node, name) {
  return (node.class || "").split(/\s+/).includes(name);
}

function findFirst(node, predicate) {
  if (predicate(node)) return node;
  for (const child of node.children || []) {
    const found = findFirst(child, predicate);
    if (found) return found;
  }
  return null;
}

// One master per reusable piece of the app, taken from the captured scene so a
// change in the app flows into the master. Instances cannot be placed through
// the API, so masters land on their own page for dragging.
const COMPONENT_SPECS = [
  { name: "Navbar", screen: "landing", find: (n) => n.tag === "nav" && nodeHasClass(n, "navbar") },
  { name: "Footer", screen: "landing", find: (n) => n.tag === "footer" },
  {
    name: "Page shell",
    screen: "landing",
    find: (n) => nodeHasClass(n, "min-h-screen"),
    prepare: stubMain,
  },
  {
    name: "Package box",
    screen: "landing",
    find: (n) => n.tag === "a" && String(n.href || "").startsWith("/package/"),
  },
  {
    name: "Section header",
    screen: "landing",
    find: (n) => nodeHasClass(n, "justify-center") && nodeHasClass(n, "space-x-4"),
  },
  {
    name: "CTA card",
    screen: "landing",
    find: (n) => nodeHasClass(n, "rounded-box") && nodeHasClass(n, "py-16"),
  },
  {
    name: "Button primary",
    screen: "landing",
    find: (n) => nodeHasClass(n, "btn") && nodeHasClass(n, "btn-primary"),
  },
  {
    name: "Button ghost",
    screen: "landing",
    find: (n) => n.tag === "a" && nodeHasClass(n, "btn") && nodeHasClass(n, "btn-ghost"),
  },
  {
    name: "Button outline",
    screen: "landing",
    find: (n) => nodeHasClass(n, "btn") && nodeHasClass(n, "btn-outline"),
  },
  {
    name: "Button neutral",
    screen: "settings",
    find: (n) => nodeHasClass(n, "btn") && nodeHasClass(n, "btn-neutral"),
  },
  {
    name: "Button error",
    screen: "keys",
    find: (n) => nodeHasClass(n, "btn") && nodeHasClass(n, "btn-error"),
  },
];

const EMPTY_STYLE = {
  borderWidth: ["0px", "0px", "0px", "0px"],
  borderStyle: ["none", "none", "none", "none"],
  borderColor: ["rgba(0, 0, 0, 0)", "rgba(0, 0, 0, 0)", "rgba(0, 0, 0, 0)", "rgba(0, 0, 0, 0)"],
  opacity: "1",
  overflow: "visible",
};

// The Page shell master ships a stub content area instead of the whole landing
// page, so an instance is navbar + footer + an empty page to fill in. The stub
// replaces the captured children for the duration of one emit, then restores.
function stubMain(node, theme) {
  const main = findFirst(node, (n) => n.tag === "main");
  if (!main) return { node };
  const saved = main.children;
  const r = main.rect;
  const at = (w, h) => ({ x: r.x + r.w / 2 - w / 2, y: r.y + r.h / 2 - h / 2, w, h });
  main.children = [
    {
      tag: "div",
      class: "page-placeholder",
      rect: { ...r },
      style: { ...EMPTY_STYLE, backgroundColor: TOKEN_SET.color[theme]["base-200"].$value },
      children: [
        {
          tag: "p",
          rect: at(320, 24),
          textBox: at(320, 24),
          text: "Page content",
          style: {
            ...EMPTY_STYLE,
            color: TOKEN_SET.color[theme]["base-content"].$value,
            fontFamily: TOKEN_SET.font.sans.$value,
            fontSize: "16px",
            fontWeight: "400",
            lineHeight: "24px",
          },
          children: [],
        },
      ],
    },
  ];
  return {
    node,
    restore: () => {
      main.children = saved;
    },
  };
}

function emitComponents(context, scenes) {
  const pageId = context.genId();
  context.addPage({ id: pageId, name: "Components", background: "#1b1b26" });
  SUPPRESS_INTERACTIONS = true;
  const top = { dark: 0, light: 0 };
  for (const spec of COMPONENT_SPECS) {
    for (const theme of THEMES) {
      const scene = scenes.get(`${spec.screen}.${theme}`);
      const found = scene && findFirst(scene.root, spec.find);
      if (!found) continue;
      CURRENT_THEME = theme;
      const { node, restore } = spec.prepare ? spec.prepare(found, theme) : { node: found };
      const x = theme === "dark" ? 0 : COMPONENT_COLUMN_X;
      const y = top[theme];
      top[theme] = y + node.rect.h + GAP;
      const boardId = context.genId();
      context.addBoard({
        id: boardId,
        name: `${spec.name} / ${theme}`,
        x,
        y,
        width: node.rect.w,
        height: node.rect.h,
        fills: [],
      });
      emitNode(context, node, x - node.rect.x, y - node.rect.y, false);
      context.closeBoard();
      context.addComponent({
        "component-id": context.genId(),
        name: `${spec.name} / ${theme}`,
        "file-id": FILE_ID,
        "page-id": pageId,
        "frame-id": boardId,
      });
      if (restore) restore();
    }
  }
  SUPPRESS_INTERACTIONS = false;
  context.closePage();
}

// --- styleguide page ---

const SG_WIDTH = 1280;
const SG_CARD_W = 280;
const SG_GAP = 32;
const SG_MARGIN = 32;

const SG_FAMILY = {
  sans: "Nunito Variable",
  display: "Outfit Variable",
  mono: "Martian Mono Variable",
};

// Ramps are derived shades, so they have no token to point at. Everything else
// on this page is emitted in a token colour and bound to it.
function sgMix(hex, target, t) {
  const from = parseColor(hex);
  const to = parseColor(target);
  if (!from || !to) return hex;
  const rgb = (h) => [1, 3, 5].map((i) => parseInt(h.slice(i, i + 2), 16));
  const [a, b] = [rgb(from.hex), rgb(to.hex)];
  return `#${a
    .map((n, i) => Math.round(n + (b[i] - n) * t).toString(16).padStart(2, "0"))
    .join("")}`;
}

function emitStyleguide(context, scenes) {
  const token = (theme, key) => TOKEN_SET.color[theme][key].$value;
  context.addPage({ id: context.genId(), name: "Styleguide", background: "#1b1b26" });
  SUPPRESS_INTERACTIONS = true;

  const sgFontAttrs = (family, size, weight, line) => ({
    "font-id": FONTS[family].id,
    "font-family": FONTS[family].family,
    "font-variant-id": variantOf(weight, false),
    "font-size": String(size),
    "font-weight": String(weight),
    "font-style": "normal",
    "line-height": String(Number((line / size).toFixed(4))),
    "letter-spacing": "0",
    "text-transform": "none",
    "text-decoration": "none",
    "text-align": "left",
    "text-direction": "ltr",
  });

  const sgRect = (x, y, w, h, color, name, radius) => {
    const shape = {
      name,
      x,
      y,
      width: w,
      height: h,
      fills: [{ "fill-color": color, "fill-opacity": 1 }],
    };
    if (radius) Object.assign(shape, { r1: radius, r2: radius, r3: radius, r4: radius });
    const applied = appliedTokensOf(
      shape.fills,
      null,
      radius ? { r1: radius, r2: radius, r3: radius, r4: radius } : null,
    );
    if (applied) shape["applied-tokens"] = applied;
    return { kind: "rect", params: shape };
  };

  const sgText = (x, y, str, color, family, size, weight, line, name, typo) => {
    const font = sgFontAttrs(family, size, weight, line);
    const fill = { "fill-color": color, "fill-opacity": 1 };
    const ref = typo ? { "typography-ref-id": typo.id, "typography-ref-file": FILE_ID } : {};
    const applied = appliedTokensOf([fill], null, null);
    return {
      kind: "text",
      params: {
        name,
        x,
        y,
        width: Math.round(str.length * size * 0.62) + 8,
        height: line,
        "grow-type": "auto-width",
        ...(applied ? { "applied-tokens": applied } : {}),
        content: {
          type: "root",
          children: [
            {
              type: "paragraph-set",
              children: [
                {
                  type: "paragraph",
                  ...font,
                  ...ref,
                  fills: [fill],
                  children: [{ text: str, ...font, ...ref, fills: [fill] }],
                },
              ],
            },
          ],
        },
      },
    };
  };

  const COLOR_KEYS = [
    "base-100", "base-200", "base-300", "base-content", "primary", "secondary",
    "accent", "neutral", "info", "success", "warning", "error", "grey",
  ];
  const FONT_KEYS = ["sans", "display", "mono"];
  const CONTROLS = [
    { name: "Button primary", screen: "landing", find: (n) => nodeHasClass(n, "btn") && nodeHasClass(n, "btn-primary") },
    { name: "Button ghost", screen: "landing", find: (n) => n.tag === "a" && nodeHasClass(n, "btn") && nodeHasClass(n, "btn-ghost") },
    { name: "Button outline", screen: "landing", find: (n) => nodeHasClass(n, "btn") && nodeHasClass(n, "btn-outline") },
    { name: "Button neutral", screen: "settings", find: (n) => nodeHasClass(n, "btn") && nodeHasClass(n, "btn-neutral") },
    { name: "Button error", screen: "keys", find: (n) => nodeHasClass(n, "btn") && nodeHasClass(n, "btn-error") },
    { name: "Badge", screen: "packages", find: (n) => nodeHasClass(n, "badge") },
    { name: "Toggle", screen: "settings", find: (n) => n.inputType === "checkbox" && nodeHasClass(n, "toggle") },
    { name: "Input", screen: "settings", find: (n) => n.tag === "input" && n.inputType === "text" },
    { name: "Select", screen: "settings", find: (n) => n.tag === "select" },
  ];
  const styles = [...TYPOGRAPHIES.values()].sort(
    (a, b) => a.path.localeCompare(b.path) || a.size - b.size,
  );

  for (const theme of THEMES) {
    CURRENT_THEME = theme;
    const X0 = theme === "dark" ? 0 : SG_WIDTH + GAP;
    const col = (i) => X0 + SG_MARGIN + i * (SG_CARD_W + SG_GAP);
    const body = token(theme, "base-content");
    const muted = token(theme, "grey");
    const items = [];
    let y = SG_MARGIN;

    const heading = (str) => {
      items.push(sgText(X0 + SG_MARGIN, y, str, body, SG_FAMILY.display, 24, 700, 32, `Heading ${str}`));
      y += 48;
    };

    heading("Colors");
    const CardH = 176;
    COLOR_KEYS.forEach((key, i) => {
      const cx = col(i % 4);
      const cy = y + Math.floor(i / 4) * (CardH + 24);
      const value = token(theme, key);
      items.push(sgRect(cx, cy, SG_CARD_W, CardH, token(theme, "base-200"), `Card ${key}`, 8));
      items.push(sgRect(cx + 16, cy + 44, SG_CARD_W - 32, 64, value, `Swatch ${key}`, 6));
      items.push(sgText(cx + 16, cy + 12, key, body, SG_FAMILY.sans, 14, 600, 20, `Name ${key}`));
      items.push(
        sgText(
          cx + SG_CARD_W - 16 - Math.round(value.length * 12 * 0.62),
          cy + 14,
          value.toUpperCase(),
          muted,
          SG_FAMILY.mono,
          12,
          400,
          16,
          `Hex ${key}`,
        ),
      );
      for (let s = 0; s < 8; s += 1) {
        const blend = s < 4 ? sgMix(value, "#000000", (3 - s) * 0.22) : sgMix(value, "#ffffff", (s - 3) * 0.22);
        const seg = Math.floor((SG_CARD_W - 32) / 8);
        items.push(sgRect(cx + 16 + s * seg, cy + 140, seg, 20, blend, `Ramp ${key} ${s}`, 0));
      }
    });
    y += 4 * (CardH + 24);

    heading("Typography");
    FONT_KEYS.forEach((key, i) => {
      const cx = col(i);
      const family = SG_FAMILY[key];
      items.push(sgRect(cx, y, SG_CARD_W, 168, token(theme, "base-200"), `Card ${key}`, 8));
      items.push(sgText(cx + 16, y + 12, `${family.replace(" Variable", "")} · ${key}`, muted, SG_FAMILY.sans, 12, 400, 16, `Family ${key}`));
      items.push(sgText(cx + 16, y + 40, "Aa", body, family, 40, 700, 48, `Sample ${key}`));
      items.push(sgText(cx + 16, y + 116, "400 · 500 · 600 · 700", body, family, 14, 400, 20, `Weights ${key}`));
    });
    y += 168 + 24;

    heading("Type scale");
    for (const spec of styles) {
      items.push(sgText(X0 + SG_MARGIN, y + 6, spec.name, muted, SG_FAMILY.mono, 12, 400, 16, `Style ${spec.name}`));
      items.push(sgText(X0 + SG_MARGIN + 224, y, "The quick brown fox jumps over", body, spec.family, spec.size, spec.weight, spec.line, `Text ${spec.name}`, spec));
      y += spec.line + 12;
    }
    y += 24;

    heading("Controls");
    let cx = X0 + SG_MARGIN;
    let rowH = 0;
    for (const control of CONTROLS) {
      const scene = scenes.get(`${control.screen}.${theme}`);
      const node = scene && findFirst(scene.root, control.find);
      if (!node) continue;
      if (cx + node.rect.w > X0 + SG_WIDTH - SG_MARGIN) {
        cx = X0 + SG_MARGIN;
        y += rowH + 30;
        rowH = 0;
      }
      items.push({ kind: "node", node, shiftX: cx - node.rect.x, shiftY: y - node.rect.y });
      items.push(sgText(cx, y + node.rect.h + 6, control.name, muted, SG_FAMILY.mono, 12, 400, 16, `Caption ${control.name}`));
      cx += node.rect.w + 24;
      rowH = Math.max(rowH, node.rect.h + 26);
    }
    y += rowH + SG_MARGIN;

    context.addBoard({
      id: context.genId(),
      name: `Styleguide / ${theme}`,
      x: X0,
      y: 0,
      width: SG_WIDTH,
      height: y,
      fills: [{ "fill-color": token(theme, "base-100"), "fill-opacity": 1 }],
      "applied-tokens": { fill: `color.${theme}.base-100` },
      r1: 12,
      r2: 12,
      r3: 12,
      r4: 12,
    });
    for (const item of items) {
      if (item.kind === "rect") context.addRect(item.params);
      else if (item.kind === "text") context.addText(item.params);
      else emitNode(context, item.node, item.shiftX, item.shiftY, false);
    }
    context.closeBoard();
  }

  SUPPRESS_INTERACTIONS = false;
  context.closePage();
}

const context = penpot.createBuildContext({ referer: "luxpkgs-design/emit-penpot" });
context.addFile({ name: "Luxpkgs" });
FILE_ID = typeof context.currentFileId === "function" ? context.currentFileId() : context.currentFileId;

for (const screen of SCREENS)
  for (const theme of THEMES) BOARD_IDS.set(`${screen.name}.${theme}`, context.genId());

const scenes = new Map();
for (const screen of SCREENS)
  for (const theme of THEMES)
    scenes.set(`${screen.name}.${theme}`, JSON.parse(readFileSync(join(SCENES, `${screen.name}.${theme}.json`), "utf8")));

for (const screen of SCREENS)
  for (const theme of THEMES) {
    const scene = scenes.get(`${screen.name}.${theme}`);
    if (scene.route) PATH_TO_SCREEN.set(scene.route, screen.name);
  }

// Text styles are collected from every scene before anything is emitted, so
// text can reference a style that already exists in the file library.
for (const scene of scenes.values()) walkScene(scene.root, registerTypography);
for (const spec of TYPOGRAPHIES.values()) {
  spec.id = context.genId();
  context.addLibraryTypography({
    id: spec.id,
    name: spec.name,
    path: spec.path,
    "font-id": FONTS[spec.family].id,
    "font-family": FONTS[spec.family].family,
    "font-variant-id": variantOf(spec.weight, spec.italic),
    "font-size": String(spec.size),
    "font-weight": String(spec.weight),
    "font-style": spec.italic ? "italic" : "normal",
    "line-height": String(Number((spec.line / spec.size).toFixed(4))),
    "letter-spacing": "0",
    "text-transform": "none",
  });
}

for (const screen of SCREENS) {
  context.addPage({ name: screen.label, background: "#1b1b26" });
  for (const theme of THEMES) {
    const scene = scenes.get(`${screen.name}.${theme}`);
    BASE = scene.base || "";
    CURRENT_SCREEN = screen.name;
    CURRENT_THEME = theme;
    OVERLAY_IDS.clear();
    for (const ov of collectOverlays(scene.root)) OVERLAY_IDS.set(ov, context.genId());
    const boardX = theme === "dark" ? 0 : scene.width + GAP;
    const boardY = 0;
    context.addBoard({
      id: BOARD_IDS.get(`${screen.name}.${theme}`),
      name: `${screen.label} / ${theme}`,
      x: boardX,
      y: boardY,
      width: scene.width,
      height: scene.height,
      fills: [{ "fill-color": theme === "dark" ? "#292939" : "#dddde7", "fill-opacity": 1 }],
    });
    emitNode(context, scene.root, boardX, boardY, false);
    context.closeBoard();
    emitOverlays(context, scene.root, THEMES.indexOf(theme));
  }
  context.closePage();
}

emitComponents(context, scenes);
emitStyleguide(context, scenes);

context.addTokensLib(JSON.parse(readFileSync(TOKENS, "utf8")));
context.closeFile();

await penpot.exportStream(context, Writable.toWeb(createWriteStream(OUT)));
process.stdout.write(`Wrote ${OUT}\n`);
