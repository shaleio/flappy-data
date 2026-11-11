# Flappy Data — UI-only "app" module registration.
#
# No Lambda, no container, no new infrastructure. This tofu does exactly two things:
#   1. upload the app's module.json to the StrataBI system bucket, and
#   2. write a row into the module registry (hash key module_id),
# which is all StrataBI core needs to discover (Apps modal) and render
# (/dashboard/apps/flappy-data) the app. Delivery is "local", so teardown works offline.

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws  = { source = "hashicorp/aws", version = ">= 5.0" }
    time = { source = "hashicorp/time", version = ">= 0.11" }
  }
}

provider "aws" {
  region = var.aws_region
}

locals {
  module_id     = "flappy-data"
  module_s3_key = "${trim(var.module_prefix, "/")}/${local.module_id}/module.json"
  module_s3_uri = "s3://${var.stratabi_system_bucket}/${local.module_s3_key}"
  module_json   = jsondecode(file("${path.module}/../module.json"))
}

resource "time_static" "registered_on" {}

resource "aws_s3_object" "module_json" {
  bucket       = var.stratabi_system_bucket
  key          = local.module_s3_key
  source       = "${path.module}/../module.json"
  content_type = "application/json"
  etag         = filemd5("${path.module}/../module.json")
}

resource "aws_dynamodb_table_item" "module_registry" {
  table_name = var.module_registry_table
  hash_key   = "module_id"

  item = jsonencode({
    module_id        = { S = local.module_id }
    version          = { S = try(local.module_json.version, "1.0.0") }
    label            = { S = local.module_json.label }
    module_type      = { S = local.module_json.module_type }
    module_s3_bucket = { S = var.stratabi_system_bucket }
    module_s3_key    = { S = aws_s3_object.module_json.key }
    module_s3_uri    = { S = local.module_s3_uri }
    registered_on    = { S = time_static.registered_on.rfc3339 }
    updated_on       = { S = timestamp() }
    module_json      = { S = file("${path.module}/../module.json") }
    metadata         = { S = jsonencode(try(local.module_json.metadata, {})) }
  })
}

output "module_id" { value = local.module_id }
output "module_s3_uri" { value = local.module_s3_uri }
output "module_registry_table" { value = var.module_registry_table }
