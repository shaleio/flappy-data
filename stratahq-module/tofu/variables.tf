variable "aws_region" {
  type        = string
  description = "AWS region for the provider."
}
variable "aws_account_id" {
  type        = string
  default     = ""
  description = "Caller account id (unused by this UI-only module; declared for runner compatibility)."
}
variable "stratabi_system_bucket" {
  type        = string
  description = "Existing StrataBI system bucket where module.json is uploaded."
}
variable "module_registry_table" {
  type        = string
  default     = "stratabi_module_registry"
  description = "Existing DynamoDB table StrataBI core scans to discover modules. Hash key is module_id."
}
variable "module_prefix" {
  type        = string
  default     = "analyst/modules"
  description = "S3 prefix for module discovery; must match core STRATABI_MODULE_PREFIX. module_id is the child prefix."
}
variable "name_prefix" {
  type        = string
  default     = "stratabi"
  description = "Prefix for AWS resource names (unused here; declared for runner compatibility)."
}
