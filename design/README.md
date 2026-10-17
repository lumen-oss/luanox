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
| `emit-penpot.mjs` | Maps each scene to a Penpot file (one page per route with a `dark` board on the left and a `light` board on the right; DOM → rect/text/path; colors/gradients/radii/shadows; toggled overlays and in-page links; tokens embedded) → `luxpkgs.penpot` |
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
   board on the right. Tokens arrive in the Tokens panel (`core` +
   `light`/`dark` sets).
3. For correct text, install the fonts into the team: **Nunito**, **Outfit**,
   **Martian Mono** (variable fonts may need static instances).
4. The account and theme menus are parked off-canvas as overlays, opened by the
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
- Penpot resolves a `navigate` destination against the current page, so links
  between routes open their URL instead of navigating. Clickable route-to-route
  flows would need one file per route.
- The 404 page is not exported: the dev server renders its debug page rather
  than the production template.
