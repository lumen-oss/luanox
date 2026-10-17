# design/ - daisyUI → Penpot pipeline

Turns the app's live UI into an importable **Penpot** file, so design work can
happen in Penpot without hand-maintaining a separate source of truth.

No Penpot account, plugin, or MCP is needed to *produce* the file. It is built
offline in the documented `.penpot` (ZIP + JSON) format via `@penpot/library`.

## Pieces

| File | Role |
|------|------|
| `generate_tokens.mjs` | Parses the daisyUI light/dark themes in `luxpkgs/assets/css/app.css`, converts `oklch()`→hex, emits multi-set DTCG tokens (`$themes` + `$metadata` + one set `luxpkgs`) with names that never collide across themes (`color.light.*`, `color.dark.*`, `radius.*`, `size.*`, `border`, `depth`, `noise`, `font.*`) → `luxpkgs-tokens.json` |
| `capture.mjs` | Playwright (Firefox) renders each route × theme and serializes the visible DOM (geometry + computed styles + text) → `scenes/<route>.<theme>.json` + `.png` |
| `emit-penpot.mjs` | Maps each scene to a Penpot file: one page per route with a `dark` board on the left and a `light` board on the right, plus a `Components` page and a `Styleguide` page. DOM → rect/text/path with semantic layer names, tokens applied to matching shapes, 22 Tailwind text styles, component masters, toggled overlays and in-page links (tokens embedded) → `luxpkgs.penpot` |
| `run.sh` | Runs a node script with nix-provided node + Playwright browsers |

## Run

```bash
# tokens (emit reads luxpkgs-tokens.json, so run this first)
nix shell nixpkgs#nodejs_22 -c node design/generate_tokens.mjs

# capture (needs the dev server on :4000)
design/run.sh design/capture.mjs

# emit
nix shell nixpkgs#nodejs_22 -c node design/emit-penpot.mjs
```

Env overrides: `BASE_URL`, `ROUTES` (capture), `SCREENS` (emit), `THEMES`,
`HEADFUL`, `GAP`, `SESSION_COOKIE`.

Both scripts default to the landing page alone. A full export lists every
route, and `ROUTES` and `SCREENS` have to agree on the names, since the capture
writes `scenes/<name>.<theme>.json` and the emitter looks those up:

```bash
ROUTES="landing=/,packages=/packages,package=/package/<name>,donate=/donate,users=/users/<username>,login=/login,provide-email=/provide-email,setup-totp=/setup-totp,settings=/settings,keys=/keys" \
  design/run.sh design/capture.mjs

SCREENS="landing=Landing,packages=Packages,package=Package,donate=Donate,users=Profile,login=Log In,provide-email=Email Required,setup-totp=Set Up 2FA,settings=Settings,keys=API Keys" \
  nix shell nixpkgs#nodejs_22 -c node design/emit-penpot.mjs
```

`scenes/` is regenerable build output and is gitignored. Capturing needs the dev
server on :4000 serving the current UI; re-running reproduces the scenes only if
that HTML and CSS are unchanged. Capture does not clean `scenes/`, so an
authenticated route can be re-shot on its own with a narrower `ROUTES` without
losing the rest.

## Design tokens

Tokens live in one set, `luxpkgs`, written in multi-set DTCG form: the file also
carries `$themes` (a `Dark` and a `Light` theme, both enabling the set) and
`$metadata`, which activates them. Without `$themes`/`$metadata` Penpot reads the
file as a single anonymous set named after the file and leaves it out of every
active theme, so the shapes' `applied-tokens` resolve to nothing. The names are
per-theme (`color.light.primary` next to `color.dark.primary`) because Penpot
merges every active set into a single namespace and a file carries one active
theme, so a bare `primary` could not resolve differently on the dark and the
light board.

The emitter applies a token to a shape only when the value matches exactly and
unambiguously: a single opaque `fill`, a single opaque `stroke-color`, a
`stroke-width` equal to the `border` token, and radii that map to one radius
token (`4px` is both `radius.selector` and `radius.box`, so only `8px`, the
field radius, is bound). Gradients, translucent fills and computed strays such
as `21.7833px` stay literal values.

Text styles are the canonical Tailwind scale (`text-xs` through `text-4xl`, with
`-medium`, `-semibold`, `-bold`, `-italic` suffixes), grouped in Penpot under
`Body`, `Display` and `Mono`. Only combinations that occur in the captured
screens get a style. Text nodes also keep their resolved font attributes, so
text renders even if a style reference does not resolve, which shows the style
as applied with overrides in the sidebar.

## Components

The `Components` page holds one master per theme for the pieces that repeat:
Navbar, Footer, Page shell (navbar, placeholder content area, footer), Package
box, Section header, CTA card, and the primary, ghost, outline, neutral and
error buttons. Each master is a transparent board promoted to a component,
built from the subtree the capture found on a real page. The Page shell master
is the one exception: its captured `<main>` content is swapped for a placeholder
block, so an instance is a page skeleton to fill in rather than the whole
landing page.

Penpot's API cannot place instances, so drag them from the Assets panel. A
master keeps the text of the instance it was built from; that is what overrides
are for. Links inside a master are dropped, since it has no destination on the
Components page.

## Styleguide

The `Styleguide` page has a dark and a light board showing the palette (name,
hex, swatch and an eight step tint/shade ramp), the three font families with a
large `Aa` and a weight ladder, every text style rendered as a type specimen,
and a controls row that re-emits the real captured nodes (buttons, badge,
toggle, input, select). Shapes here carry `applied-tokens` wherever a token
matches exactly; the ramps are derived blends, so they stay literal.

## Authenticated routes

`settings` and `keys` sit behind login. Without a session the dev server renders
the "reauthenticate" screen instead, which is silently captured as a short page
(settings come out `2560x1440` rather than `2560x1668`), so check the printed
height after a re-capture. `setup-totp` needs an account *without* TOTP enrolled
and `provide-email` needs an `oauth_signup_token` in the session, so those two
are captured separately with their own cookie.

Pass the `_luxpkgs_key` value through `SESSION_COOKIE`, for example by copying
it out of devtools after signing in, or by minting one:

```elixir
sc = Plug.Session.init(store: Plug.Session.COOKIE, key: "_luxpkgs_key", signing_salt: "WW0lz5ZY").store_config
conn = %Plug.Conn{secret_key_base: LuxpkgsWeb.Endpoint.config(:secret_key_base)}
user = Luxpkgs.Repo.get_by(Luxpkgs.Accounts.User, username: "<username>")
val = Plug.Session.COOKIE.put(conn, nil, %{"user_token" => Luxpkgs.Accounts.generate_user_session_token(user)}, sc)
```

The session expires with the sudo window (minutes), so capture right after
minting. A cookie is a credential: keep it out of the repo, and out of the
scenes, which is why it is passed per-run instead of stored.

## Import into Penpot

Penpot's file import only accepts `.penpot`:

1. Open https://design.penpot.app → dashboard → **Import files** → pick
   `design/luxpkgs.penpot`.
2. Each route becomes a page, holding a `dark` board on the left and a `light`
   board on the right, followed by the `Components` and `Styleguide` pages.
   Tokens arrive in the Tokens panel as the single `luxpkgs` set.
3. For correct text, install the fonts into the team: **Nunito**, **Outfit**,
   **Martian Mono** (variable fonts may need static instances).
4. Text styles and component masters appear in the Assets panel; the masters sit
   on the `Components` page and are dragged in by hand.
5. The account and theme menus are parked off-canvas as overlays, opened by the
   avatar and theme buttons through `toggle-overlay`. Links inside a page
   navigate; links to another route open their URL, see the ceilings below.

## Known ceilings (approximations, not bugs)

- Layout is flattened to absolutely-positioned shapes (no Penpot flex/grid).
- `backdrop-filter` is ignored. The controls CSS draws itself (select carets,
  collapse arrows, toggle knobs, divider hairlines) are redrawn by the emitter;
  any other `::before/::after` content is not converted.
- `svg`/`img` are rasterized to PNG and embedded as image fills (Penpot has no
  vector SVG import); icons are not editable vectors.
- `iframe` embeds, such as the OpenCollective widget on `donate`, arrive as an
  empty box.
- A `select` is a static label with a redrawn caret, not a Penpot control, so
  its options are not present in the file.
- Gradients/shadows are best-effort; Penpot allows at most one shadow per shape.
- Text is created with Penpot's text engine from a single paragraph per node;
  rich inline formatting is flattened.
- Token binding is exact-match only, so gradients, translucent fills and derived
  blends (the styleguide ramps) stay literal.
- Component instances can only be placed by hand; the build API has no call for
  it. Masters also carry the text of the page they were captured from.
- Penpot resolves a `navigate` destination against the current page, so links
  between routes open their URL instead of navigating. Clickable route-to-route
  flows would need one file per route.
- The 404 page is not exported: the dev server renders its debug page rather
  than the production template.
