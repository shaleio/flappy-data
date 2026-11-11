#!/usr/bin/env bash
# Register "Flappy Data" as an APP MODULE in a StrataBI ENTERPRISE install, the normal way:
#   - module.json -> system S3 bucket   (load_module_json reads it to render the app)
#   - a row       -> module registry    (scan_app_modules lists it in the navbar Apps modal)
# It is a UI-only app (a raw_html tile) — no Lambda, no container, no infra. Idempotent.
#
#   STRATABI_SYSTEM_BUCKET=<install system bucket> \
#   STRATABI_MODULE_REGISTRY_TABLE=<name_prefix>_module_registry \
#   AWS_REGION=us-east-1 ./register-enterprise-app.sh
set -euo pipefail
: "${STRATABI_SYSTEM_BUCKET:?set to the install's system S3 bucket}"
: "${STRATABI_MODULE_REGISTRY_TABLE:?set to <name_prefix>_module_registry}"
PREFIX="${STRATABI_MODULE_PREFIX:-analyst/modules}"
REGION="${AWS_REGION:-us-east-1}"
HERE="$(cd "$(dirname "$0")" && pwd)"

echo "→ upload module.json → s3://$STRATABI_SYSTEM_BUCKET/$PREFIX/flappy-data/module.json"
aws s3 cp "$HERE/flappy-data.module.json" \
  "s3://$STRATABI_SYSTEM_BUCKET/$PREFIX/flappy-data/module.json" --region "$REGION"

echo "→ put registry row → $STRATABI_MODULE_REGISTRY_TABLE (hash key module_id)"
aws dynamodb put-item --table-name "$STRATABI_MODULE_REGISTRY_TABLE" --region "$REGION" --item '{
  "module_id":   {"S": "flappy-data"},
  "module_type": {"S": "app"},
  "label":       {"S": "Flappy Data"},
  "description": {"S": "A self-contained HTML game in a raw_html tile — proof StrataBI hosts interactive apps with no backend, container, or infrastructure change."},
  "version":     {"S": "1.0.0"}
}'
echo "✅ registered — open the navbar Apps button → Flappy Data, or /dashboard/apps/flappy-data"
echo "   remove:"
echo "     aws dynamodb delete-item --table-name $STRATABI_MODULE_REGISTRY_TABLE --region $REGION --key '{\"module_id\":{\"S\":\"flappy-data\"}}'"
echo "     aws s3 rm s3://$STRATABI_SYSTEM_BUCKET/$PREFIX/flappy-data/module.json --region $REGION"
