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

function textContentOf(node, nodeFills) {
  const c = parseColor(node.style.color);
  // A gradient-clipped heading has a transparent color; Penpot resolves the
  // fill per text node, so carry the shape gradient down instead of black.
  const fill =
    nodeFills || [{ "fill-color": c ? c.hex : "#000000", "fill-opacity": c ? c.alpha : 1 }];
  const font = fontAttrsOf(node.style);
  // One paragraph per captured visual line (Penpot's canonical line model).
  const paragraphs = String(node.text).split("\n").map((line) => ({
    type: "paragraph",
    ...font,
    fills: fill,
    children: [{ text: line, ...font, fills: fill }],
  }));
  return { type: "root", children: [{ type: "paragraph-set", children: paragraphs }] };
}

const BOARD_IDS = new Map();
const OVERLAY_IDS = new Map();
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
  const out = [];
  if (node.href) {
    // A link to another captured route becomes in-file navigation; anything
    // else (Docs, GitHub, ...) opens in the browser.
    const screen = PATH_TO_SCREEN.get(resolvePath(node.href));
    const dest = screen && BOARD_IDS.get(`${screen}.${CURRENT_THEME}`);
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

function nameOf(node) {
  const cls = (node.class || "").split(/\s+/).filter(Boolean).slice(0, 2).join(".");
  if (node.text) return node.text.split("\n")[0].slice(0, 40);
  return node.tag + (cls ? "." + cls : "");
}

// --- emit -----------------------------------------------------------------
function emitNode(context, node, bx, by, inOverlay) {
  const { x, y, w, h } = node.rect;
  const X = x + bx, Y = y + by;
  const sized = w >= 1 && h >= 1;

  const fills = sized ? fillsOf(node) : [];
  const strokes = sized ? strokesOf(node) : [];
  const borders = sized ? borderSidesOf(node) : [];
  const [r1, r2, r3, r4] = sized ? radiusOf(node) : [0, 0, 0, 0];
  const opacity = parseFloat(node.style.opacity);
  // CSS clips a gradient to its own text (bg-clip-text + a transparent color),
  // which Penpot expresses as a gradient fill on the text shape, not a rect
  // sitting behind a solid-colored text.
  const clipText = !!(sized && node.text && fills.some((f) => f["fill-color-gradient"]) &&
    !parseColor(node.style.color));
  const box = !clipText && (fills.length || strokes.length || r1 || r2 || r3 || r4);
  const hasBox = box || borders.length;
  const interactions = interactionsOf(node, inOverlay);
  const draws = hasBox || (sized && (node.img || node.text)) || !!interactions;

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
    context.addRect(shape);
  }

  for (const b of borders) context.addRect({ ...b, x: b.x + bx, y: b.y + by });

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
    if (r1 || r2 || r3 || r4) Object.assign(imgShape, { r1, r2, r3, r4 });
    if (!Number.isNaN(opacity) && opacity < 1) imgShape.opacity = opacity;
    context.addRect(imgShape);
  }

  if (sized && node.text) {
    // Position at the measured glyph box, not the padded element box, and let
    // the shape size itself so explicit line breaks are never re-wrapped.
    const tb = node.textBox || { x, y, w, h };
    context.addText({
      name: nameOf(node),
      x: tb.x + bx,
      y: tb.y + by,
      width: tb.w,
      height: tb.h,
      "grow-type": "auto-width",
      ...(clipText ? { fills } : {}),
      content: textContentOf(node, clipText ? fills : undefined),
    });
  }

  for (const c of node.children || []) {
    if (c.overlay) continue;
    emitNode(context, c, bx, by, inOverlay);
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

const context = penpot.createBuildContext({ referer: "luxpkgs-design/emit-penpot" });
context.addFile({ name: "Luxpkgs" });

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

context.addTokensLib(JSON.parse(readFileSync(TOKENS, "utf8")));
context.closeFile();

await penpot.exportStream(context, Writable.toWeb(createWriteStream(OUT)));
process.stdout.write(`Wrote ${OUT}\n`);
