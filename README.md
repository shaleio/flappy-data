# Flappy Data — StrataBI Extensibility Demo

A deliberately ridiculous Flappy Bird-style game where the **official Shaleio logo** flies
through obstacles made of connected data nodes — running entirely inside an existing StrataBI
dashboard tile.

**The game is ridiculous. The architecture behind it is not.** The point is that a complete
interactive application runs on the platform with **no new backend, no Lambda, no container or
image rebuild, and no new AWS infrastructure** — just a `raw_html` tile.

This repo is published as an **open, inspectable sample** (MIT) so anyone can see exactly how a
custom app rides on StrataBI — from a one-file dashboard tile all the way to a provisionable,
entitlement-gated module. Nothing here is obfuscated; read `flappy-data.html` and the manifests
top to bottom.

## Repository layout

```
flappy-data/
├── flappy-data.html                 # the complete self-contained game (HTML/CSS/JS, logo inlined)
├── extensibility-playground.json    # schema-valid dashboard: explanation tile + game tile
├── LICENSE                          # MIT
├── README.md                        # this file
├── enterprise/                      # register it directly in an existing install (no publish)
│   ├── flappy-data.module.json      #   schema-valid app manifest (multi_page_app)
│   └── register-enterprise-app.sh   #   uploads module.json to S3 + writes the registry row
└── stratahq-module/                 # the "no-kidding" provisionable StrataHQ module
    ├── stratabi-module.json         #   install manifest (runner): state_key, delivery, perms
    ├── module.json                  #   app manifest (uploaded to S3 by the tofu)
    ├── llm_context.txt
    ├── tofu/{main.tf,variables.tf}  #   uploads module.json + registry row (no Lambda/infra)
    └── README.md                    #   publish → grant → install walkthrough
```

Three levels of integration, smallest to largest:

1. **A dashboard tile** — `extensibility-playground.json`, loadable as-is.
2. **A registered app (direct)** — `enterprise/` puts the app in an existing install's registry +
   S3 so it shows under the navbar **Apps** button, no module pipeline.
3. **A provisionable module** — `stratahq-module/` publishes to StrataHQ, is entitlement-gated,
   and installs with `stratactl install flappy-data`. See its README.

## What's here

| File | What it is |
|------|-----------|
| `flappy-data.html` | The complete, self-contained game. HTML + CSS + vanilla JS, one file, no dependencies, no network. The Shaleio logo is embedded as a `data:` URI. |
| `extensibility-playground.json` | A schema-valid StrataBI dashboard with two tiles: a `markdown` explanation and the `raw_html` game. |
| `enterprise/`, `stratahq-module/` | Register it as an app, or publish it as a real module (see "Also available as an App" below). |
| `LICENSE` | MIT. |

## The architectural point

StrataBI dashboards are **declarative JSON** ("Dashboards as Code"). A `raw_html` tile renders
trusted HTML inside a sandboxed `<iframe>`. That's the whole hosting mechanism — so any
self-contained web app (a custom visualization, an interactive simulation, an operational tool,
a specialized business UI) can live inside a dashboard with zero platform changes. AI can
generate the app; StrataBI gives it a place to run.

## How it runs inside StrataBI (and how it stays secure)

The game is placed in a `raw_html` block's `config.html`. The runtime renders it with
`html.Iframe(srcDoc=…)`, which means:

- **It runs in a null origin.** The default iframe sandbox is `allow-scripts allow-popups` —
  scripts run (the game needs canvas + JS), but **`allow-same-origin` is deliberately omitted**,
  so the game cannot read the parent app's cookies, `localStorage`, or same-origin APIs.
- **No network, no credentials.** The game makes no external requests, uses no storage, and
  never sees AWS credentials. The logo is inlined as a data URI.
- **No global policy changes.** No CSP or RBAC changes are required.

### Note on the `sandbox` field (schema vs. runtime)

The public Blocks docs mention a `sandbox` option, but the published `dashboard.schema.json`
does **not** list `sandbox` under `block_raw_html.config` (the config is `additionalProperties:
false`). The runtime (`stratabi/blocks/raw_html.py`) *does* read an optional `sandbox` key, and
**defaults it to `allow-scripts allow-popups`** when absent.

Reconciliation: this dashboard **omits `sandbox` entirely**, so it (a) passes schema validation
and (b) gets the secure default — scripts allowed, no same-origin. We do not add an unsupported
JSON field and we do not weaken the sandbox.

## Controls

- **Desktop:** Space or ↑ to flap; click to start / flap / retry.
- **Mobile:** tap anywhere in the playfield to flap; large Start / Retry buttons.

Input is only swallowed inside the playfield, so the parent page scrolls normally everywhere
else. No audio, no autoplay, no persistence (session high score lives in memory).

## Technical notes

- HTML5 Canvas, `requestAnimationFrame`, **delta-time** physics (consistent across frame rates),
  **device-pixel-ratio** scaling for sharp visuals, responsive canvas that re-fits on resize.
- Obstacle objects are **recycled** (no per-frame allocation in the loop); background node field
  is capped and precomputed.
- **Pauses when not visible** — `visibilitychange` and an `IntersectionObserver` on the stage —
  so it doesn't burn CPU when the tile is scrolled off or the tab is hidden.
- The playfield is centered with a `max-width` so it looks right on a wide desktop iframe and
  fills the width in phone portrait.

## Deploy into the demo

The demo's curated dashboards live in `stratabi/data/samples/*.json` (the same place as
`revenue-pulse.json`, `operations.json`, `product-growth.json`). Registering the playground is
additive — drop the JSON in alongside them and it surfaces through the demo's existing dashboard
listing on the next demo publish. **No image rebuild is required for the game to work** (it's
data in an existing renderer); it ships with the demo's normal content refresh, exactly like the
other sample dashboards. Existing dashboards are untouched and the default landing is unchanged.

```
cp extensibility-playground.json  <stratabi>/stratabi/data/samples/
```

If your demo serves git-registered dashboards from S3 instead, publish it with the existing
dashboard sync (`stratactl dashboards push --new --git-registered`) rather than rebuilding the
image.

## Testing

- **Validated:** dashboard JSON passes `dashboard.schema.json` (jsonschema). Game renders in the
  `raw_html` iframe model; start screen, branding, and background confirmed via screenshot.
- **Manual pass recommended (live):** start/flap/score/collision/game-over/restart; Space + ↑ +
  touch; Chrome / Edge / Firefox / mobile Chrome & Safari; portrait at ~375/430px and desktop at
  1366/1920px; confirm no horizontal scroll and no iframe focus/clipping issues inside the tile.

## Also available as an "App" (navbar Apps modal)

Beyond the sample dashboard, Flappy Data is wired as an **app module** so it shows up under
the navbar **Apps** button and is navigable like any module at `/dashboard/apps/flappy-data`.
An "app" here is just a registry entry whose page `layout` is tiles — so this app is the same
`raw_html` game tile, **no Lambda, no container, no infra**.

Apps are discovered in **two layers**, and both are wired:

1. **Demo / registry-less (bundled).** The Apps modal (`scan_app_modules`) and the app route
   (`load_module_json`) normally read a DynamoDB registry + S3 `module.json`. The demo has
   neither (locked-down, empty task role). So `stratabi/core/demo_apps.py` provides a bundled
   fallback: when no registry is configured, the modal lists the bundled apps and the route
   renders them without S3. Ships in the demo image — nothing else to do.

2. **Enterprise (real registry + S3).** A normal install has the registry table and system
   bucket, so register it the normal way with `enterprise/register-enterprise-app.sh`:

   ```bash
   STRATABI_SYSTEM_BUCKET=<install system bucket> \
   STRATABI_MODULE_REGISTRY_TABLE=<name_prefix>_module_registry \
   AWS_REGION=us-east-1 ./enterprise/register-enterprise-app.sh
   ```

   It uploads `enterprise/flappy-data.module.json` to `s3://<bucket>/analyst/modules/flappy-data/module.json`
   and puts a `module_type: "app"` row (hash key `module_id`) in the registry. Then it appears
   in the enterprise Apps modal and renders at `/dashboard/apps/flappy-data` — a clean way to
   exercise the module discovery + render path end to end. (The script prints the removal
   commands too.)

Code touched for the app wiring (both tiny, enterprise path unchanged):
`stratabi/core/demo_apps.py` (new bundled fallback), `stratabi/app.py` (`scan_app_modules`
falls back to bundled when there's no registry), `stratabi/pages/dashboard.py`
(`load_dashboard_config` tries a bundled app before S3).

## Constraints honored

No new backend · no Lambda · no new ECS task/image · no new AWS infra · no Python deps · no JS
frameworks · no changes to the module contract · existing iframe sandbox preserved. One game.
Two tiles. Existing platform.
