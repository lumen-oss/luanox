# design/ - daisyUI → Penpot pipeline

Turns the app's live UI into an importable **Penpot** file, so design work can
happen in Penpot without hand-maintaining a separate source of truth.

No Penpot account, plugin, or MCP is needed to *produce* the file. It is built
offline in the documented `.penpot` (ZIP + JSON) format via `@penpot/library`.

## Pieces

| File | Role |
|------|------|
| `generate_tokens.mjs` | Parses the daisyUI light/dark themes in `luxpkgs/assets/css/app.css`, converts `oklch()`→hex, emits DTCG tokens (sets `core`, `light`, `dark`) → `luxpkgs-tokens.json` |
| `capture.mjs` | Playwright (Firefox) renders each route × theme and serializes the visible DOM (geometry + computed styles + text) → `scenes/<route>.<theme>.json` + `.png` |
| `emit-penpot.mjs` | Maps each scene to a Penpot file (one board per route/theme; DOM → rect/text; colors/gradients/radii/shadows; tokens embedded) → `luxpkgs.penpot` |
| `run.sh` | Runs a node script with nix-provided node + Playwright browsers |

## Run

```bash
# tokens
nix shell nixpkgs#nodejs_22 -c node design/generate_tokens.mjs

# capture (needs the dev server on :4000)
design/run.sh design/capture.mjs

# emit
nix shell nixpkgs#nodejs_22 -c node design/emit-penpot.mjs
```

Env overrides: `BASE_URL`, `ROUTES`/`SCREENS`, `THEMES`, `HEADFUL`, `GAP`.

`scenes/` is regenerable build output and is gitignored. Capturing needs the dev
server on :4000 serving the current UI; re-running reproduces the scenes only if
that HTML and CSS are unchanged.

## Import into Penpot

Penpot's file import only accepts `.penpot`:

1. Open https://design.penpot.app → dashboard → **Import files** → pick
   `design/luxpkgs.penpot`.
2. Each theme becomes a page; each route a board. Tokens arrive in the Tokens
   panel (`core` + `light`/`dark` sets).
3. For correct text, install the fonts into the team: **Nunito**, **Outfit**,
   **Martian Mono** (variable fonts may need static instances).

## Known ceilings (approximations, not bugs)

- Layout is flattened to absolutely-positioned shapes (no Penpot flex/grid).
- `backdrop-filter` and `::before/::after` are not converted.
- `svg`/`img` are rasterized to PNG and embedded as image fills (Penpot has no
  vector SVG import); icons are not editable vectors.
- Gradients/shadows are best-effort; Penpot allows at most one shadow per shape.
- Text is created with Penpot's text engine from a single paragraph per node;
  rich inline formatting is flattened.
