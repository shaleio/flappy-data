# Flappy Data — provisionable StrataHQ module

This is the "no-kidding" version: Flappy Data packaged as a **real StrataBI module** you publish
to StrataHQ, grant to an account, and install with `stratactl` — exercising the full module
delivery pipeline (entitlement → signed bundle → in-account OpenTofu → registry).

It is intentionally a **UI-only app module** (`module_type: multi_page_app`, `lambdas: []`): no
Lambda, no container, no new infrastructure. The OpenTofu does exactly two things in the customer
account — upload `module.json` to the system bucket and write a row in the module registry — which
is all core needs to discover it (navbar **Apps**) and render it (`/dashboard/apps/flappy-data`).

## Bundle contents

```
stratahq-module/
  stratabi-module.json   # install manifest (runner): module_id, version, entrypoint=tofu,
                         #   state_key, delivery=local, supports_destroy, required_permissions
  module.json            # app manifest (schema-valid multi_page_app; the tofu uploads this to S3)
  llm_context.txt        # module context for the AI builder
  tofu/
    main.tf              # uploads module.json + writes the registry row (no Lambda/infra)
    variables.tf         # the runner-injected contract (system bucket, registry table, …)
```

## 1. Publish to StrataHQ (HQ creds)

`publish_module.sh` reads `module_id`/`version` from `stratabi-module.json`, zips the bundle
(`module.json` at the root, tofu under `tofu/`), uploads it to
`s3://<hq-artifacts>/flappy-data/1.0.0/module.zip`, then signs + catalogs it.

```bash
unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN
export AWS_PROFILE=AdministratorAccess-968077439131   # StrataHQ
aws sso login --profile "$AWS_PROFILE"

bash stratahq/stratahq/seed/publish_module.sh --dir <path>/flappy-data/stratahq-module
# default --tofu-dir is <dir>/tofu, and the tofu reads ../module.json from the bundle root,
# so no --include flags are needed.
```
Expect `✅ published flappy-data#1.0.0`.

## 2. Grant the entitlement to an account

Modules are account-entitled like the platform. Grant `flappy-data#1.0.0` to the target account
(the sandbox/customer AWS account id) in the entitlements table — either via the admin op or a
direct put:

```bash
# direct put (HQ creds) — mirrors how the platform grant was seeded
aws dynamodb put-item --table-name stratahq_entitlements_prod --region us-east-1 --item '{
  "customer_id": {"S": "<CUSTOMER_AWS_ACCOUNT_ID>"},
  "sk":          {"S": "flappy-data#1.0.0"},
  "status":      {"S": "active"},
  "module_id":   {"S": "flappy-data"},
  "version":     {"S": "1.0.0"}
}'
```

## 3. Install into the enterprise account (customer creds)

```bash
export AWS_PROFILE=<the entitled account's profile>
export STRATA_HQ_TOKEN=<that account's license token>

stratactl --region us-east-1 install flappy-data --to 1.0.0
```

The runner checks the entitlement, pulls + verifies the signed bundle, runs the OpenTofu (which
uploads `module.json` and registers the row), and records the install. Then open the app:

- navbar **Apps** → **Flappy Data**, or
- `/dashboard/apps/flappy-data`

## Teardown

```bash
stratactl --region us-east-1 uninstall flappy-data
```
`delivery=local` means the verified bundle was cached in your bucket, so teardown re-runs the tofu
(destroy) offline — removing the registry row and the `module.json` object. Nothing else was
created.

## Notes / reconciliations

- The app manifest uses `module_type: multi_page_app` with a single page. That's the
  **schema-valid** shape for an app whose UI is a dashboard layout (the schema requires `pages` +
  `navigation_type`). A plain `module_type: "app"` is accepted by the schema but the current
  render path reads a top-level `layout` for non-`multi_page_app`, which the schema doesn't allow —
  so `multi_page_app` is the consistent choice. (Flagged upstream.)
- `required_permissions` is limited to `["s3","dynamodb"]` — the only services the tofu touches —
  so the runner's module-scoped deploy role stays least-privilege.
