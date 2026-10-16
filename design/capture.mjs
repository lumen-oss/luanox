#!/usr/bin/env node
// Captures rendered pages into scene JSON + PNG using Playwright (Firefox).
// Run via design/run.sh so node & the nix playwright browsers are available.
//
//   design/run.sh design/capture.mjs
//
// Env: BASE_URL (default http://localhost:4000),
//      ROUTES ("name=path,...") to override the default landing-only set,
//      THEMES (default "dark,light"), HEADFUL=1 for a visible browser.
import { firefox } from "playwright-core";
import { mkdirSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = dirname(fileURLToPath(import.meta.url));
const SCENES = join(__dirname, "scenes");
const BASE = process.env.BASE_URL || "http://localhost:4000";
const VIEWPORT = { width: 2560, height: 1440 };

const ROUTES = (process.env.ROUTES || "landing=/")
  .split(",")
  .map((s) => {
    const [name, path] = s.split("=");
    return { name: name.trim(), path: (path ?? "/").trim() };
  });
const THEMES = (process.env.THEMES || "dark,light").split(",").map((s) => s.trim());

// Runs inside the page: serialize the visible DOM into a scene tree.
async function extract() {
  const isVisible = (el) => {
    const r = el.getBoundingClientRect();
    const s = getComputedStyle(el);
    return (
      r.width > 0 &&
      r.height > 0 &&
      s.display !== "none" &&
      s.visibility !== "hidden" &&
      parseFloat(s.opacity) > 0
    );
  };

  const styleOf = (el) => {
    const s = getComputedStyle(el);
    return {
      display: s.display,
      position: s.position,
      backgroundColor: s.backgroundColor,
      backgroundImage: s.backgroundImage,
      color: s.color,
      borderWidth: [s.borderTopWidth, s.borderRightWidth, s.borderBottomWidth, s.borderLeftWidth],
      borderColor: [s.borderTopColor, s.borderRightColor, s.borderBottomColor, s.borderLeftColor],
      borderStyle: [s.borderTopStyle, s.borderRightStyle, s.borderBottomStyle, s.borderLeftStyle],
      borderRadius: s.borderRadius,
      boxShadow: s.boxShadow,
      opacity: s.opacity,
      transform: s.transform,
      fontFamily: s.fontFamily,
      fontSize: s.fontSize,
      fontWeight: s.fontWeight,
      fontStyle: s.fontStyle,
      lineHeight: s.lineHeight,
      letterSpacing: s.letterSpacing,
      textAlign: s.textAlign,
      textTransform: s.textTransform,
      textDecoration: s.textDecorationLine,
      backdropFilter: s.backdropFilter || s.webkitBackdropFilter || "none",
      filter: s.filter,
      mixBlendMode: s.mixBlendMode,
      overflow: s.overflow,
    };
  };

  const sx = window.scrollX;
  const sy = window.scrollY;
  const rectOf = (el) => {
    const r = el.getBoundingClientRect();
    return {
      x: Math.round(r.left + sx),
      y: Math.round(r.top + sy),
      w: Math.round(r.width),
      h: Math.round(r.height),
    };
  };

  const ownText = (el) => {
    let t = "";
    for (const n of el.childNodes) if (n.nodeType === 3) t += n.textContent;
    return t.replace(/\s+/g, " ").trim();
  };

  // Native text metrics: word-level client rects grouped into visual lines.
  // Yields the true glyph box (for centering) and explicit line breaks (so
  // Penpot does not re-wrap), and skips lines clipped by overflow/line-clamp.
  const textOf = (el) => {
    const cs = getComputedStyle(el);
    const clip = /hidden|clip/.test(cs.overflow) ? el.getBoundingClientRect() : null;
    const pieces = [];
    const visit = (n) => {
      if (n.nodeType === 3) {
        const re = /\S+/g;
        let m;
        while ((m = re.exec(n.textContent))) {
          const r = document.createRange();
          r.setStart(n, m.index);
          r.setEnd(n, m.index + m[0].length);
          const b = r.getBoundingClientRect();
          if (!b.width && !b.height) continue;
          if (clip) {
            const cy = b.top + b.height / 2;
            const cx = b.left + b.width / 2;
            if (cy < clip.top - 1 || cy > clip.bottom + 1 || cx < clip.left - 1 || cx > clip.right + 1) continue;
          }
          pieces.push({ text: m[0], top: b.top + sy, left: b.left + sx, right: b.right + sx, bottom: b.bottom + sy });
        }
      } else if (n.nodeType === 1) {
        const c = getComputedStyle(n);
        if (c.display === "none" || c.visibility === "hidden" || parseFloat(c.opacity) === 0) return;
        for (const k of n.childNodes) visit(k);
      }
    };
    visit(el);
    if (!pieces.length) return null;
    pieces.sort((a, b) => a.top - b.top || a.left - b.left);
    const lines = [];
    for (const p of pieces) {
      const line = lines[lines.length - 1];
      if (!line || Math.abs(p.top - line.top) >= (p.bottom - p.top) * 0.6) {
        lines.push({ top: p.top, bottom: p.bottom, left: p.left, right: p.right, words: [p.text] });
      } else {
        line.bottom = Math.max(line.bottom, p.bottom);
        line.left = Math.min(line.left, p.left);
        line.right = Math.max(line.right, p.right);
        line.words.push(p.text);
      }
    }
    return {
      text: lines.map((l) => l.words.join(" ")).join("\n"),
      box: {
        x: Math.round(Math.min(...lines.map((l) => l.left))),
        y: Math.round(Math.min(...lines.map((l) => l.top))),
        w: Math.round(Math.max(...lines.map((l) => l.right)) - Math.min(...lines.map((l) => l.left))),
        h: Math.round(Math.max(...lines.map((l) => l.bottom)) - Math.min(...lines.map((l) => l.top))),
      },
    };
  };

  // Inputs/textarea render their placeholder (no text node to range over), so
  // approximate its box from the content box and centre the line vertically.
  const placeholderBox = (el) => {
    const s = getComputedStyle(el);
    const r = el.getBoundingClientRect();
    const px = (v) => parseFloat(v) || 0;
    const bl = px(s.borderLeftWidth), br = px(s.borderRightWidth);
    const bt = px(s.borderTopWidth), bb = px(s.borderBottomWidth);
    const pl = px(s.paddingLeft), pr = px(s.paddingRight);
    const pt = px(s.paddingTop), pb = px(s.paddingBottom);
    const left = r.left + sx + bl + pl;
    const top = r.top + sy + bt + pt;
    const w = Math.max(0, r.width - bl - br - pl - pr);
    const h = Math.max(0, r.height - bt - bb - pt - pb);
    const fs = parseFloat(s.fontSize) || 16;
    const lh = s.lineHeight !== "normal" ? parseFloat(s.lineHeight) : fs * 1.2;
    const y = top + Math.max(0, (h - lh) / 2);
    return { x: Math.round(left), y: Math.round(y), w: Math.round(w), h: Math.round(lh) };
  };

  const visibleKids = (el) => {
    const out = [];
    for (const c of el.children) {
      if (getComputedStyle(c).display === "contents") out.push(...visibleKids(c));
      else if (isVisible(c)) out.push(c);
    }
    return out;
  };

  // Penpot has no vector SVG import, so rasterize icons (svg/img) to a PNG
  // data URL, baking in the resolved currentColor.
  const rasterize = async (el) => {
    const r = el.getBoundingClientRect();
    const w = Math.max(1, Math.round(r.width));
    const h = Math.max(1, Math.round(r.height));
    let drawable = el;
    if (el.tagName.toLowerCase() !== "img") {
      const clone = el.cloneNode(true);
      clone.setAttribute("xmlns", "http://www.w3.org/2000/svg");
      clone.setAttribute("width", w);
      clone.setAttribute("height", h);
      clone.style.color = getComputedStyle(el).color;
      const svgStr = new XMLSerializer().serializeToString(clone);
      const url = "data:image/svg+xml;charset=utf-8," + encodeURIComponent(svgStr);
      const img = new Image();
      await new Promise((res, rej) => {
        img.onload = res;
        img.onerror = rej;
        img.src = url;
      });
      drawable = img;
    }
    const canvas = document.createElement("canvas");
    canvas.width = w * 2;
    canvas.height = h * 2;
    canvas.getContext("2d").drawImage(drawable, 0, 0, canvas.width, canvas.height);
    return canvas.toDataURL("image/png");
  };

  // Media-only subtree scan: keeps svg/img descendants (as rasterized shapes)
  // without re-emitting overlapping text nodes for their ancestors.
  const collectMedia = async (el, out) => {
    for (const c of visibleKids(el)) {
      if (c.tagName === "svg" || c.tagName === "IMG") {
        const node = { tag: c.tagName.toLowerCase(), rect: rectOf(c), style: styleOf(c), text: "", children: [] };
        try {
          node.img = await rasterize(c);
        } catch {}
        out.push(node);
      } else {
        await collectMedia(c, out);
      }
    }
    return out;
  };

  const walk = async (el) => {
    const node = {
      tag: el.tagName.toLowerCase(),
      rect: rectOf(el),
      style: styleOf(el),
      text: "",
      children: [],
    };
    if (el.id) node.id = el.id;
    const cls = (el.getAttribute("class") || "").trim();
    if (cls) node.class = cls;
    if (el.tagName === "svg" || el.tagName === "IMG") {
      try {
        node.img = await rasterize(el);
      } catch {}
    }
    const ph = el.tagName === "INPUT" || el.tagName === "TEXTAREA" ? el.placeholder : "";
    if (ph) {
      node.text = ph;
      node.textBox = placeholderBox(el);
      try {
        const pc = getComputedStyle(el, "::placeholder").color;
        if (pc) node.style.color = pc;
      } catch {}
      return node;
    }
    if (ownText(el)) {
      // A node with direct text is one visual text block: merge all inline
      // runs (child spans/links) into a single text shape instead of emitting
      // overlapping per-run shapes. Media descendants (icons) are kept.
      const t = textOf(el);
      if (t) {
        node.text = t.text;
        node.textBox = t.box;
      }
      node.children = await collectMedia(el, []);
      return node;
    }
    for (const c of visibleKids(el)) node.children.push(await walk(c));
    return node;
  };

  return {
    title: document.title,
    theme: document.documentElement.getAttribute("data-theme"),
    width: document.documentElement.scrollWidth,
    height: document.documentElement.scrollHeight,
    root: await walk(document.body),
  };
}

const browser = await firefox.launch({ headless: !process.env.HEADFUL });
mkdirSync(SCENES, { recursive: true });

for (const route of ROUTES) {
  for (const theme of THEMES) {
    const context = await browser.newContext({
      viewport: VIEWPORT,
      deviceScaleFactor: 1,
      reducedMotion: "reduce",
    });
    await context.addInitScript((t) => {
      try {
        localStorage.setItem("phx:theme", t);
      } catch {}
    }, theme);
    const page = await context.newPage();
    await page.goto(BASE + route.path, { waitUntil: "networkidle" });
    await page.evaluate(() => document.fonts.ready);
    await page.addStyleTag({
      content:
        "*,*::before,*::after{animation:none!important;transition:none!important;caret-color:transparent!important}",
    });
    await page.waitForTimeout(400);

    const scene = await page.evaluate(extract);
    const stem = `${route.name}.${theme}`;
    writeFileSync(
      join(SCENES, `${stem}.json`),
      JSON.stringify({ route: route.path, base: BASE, viewport: VIEWPORT, ...scene }, null, 2) + "\n",
    );
    await page.screenshot({ path: join(SCENES, `${stem}.png`), fullPage: false });

    process.stdout.write(
      `${route.name} [${theme}] theme=${scene.theme} ${scene.width}x${scene.height}\n`,
    );
    await context.close();
  }
}

await browser.close();
