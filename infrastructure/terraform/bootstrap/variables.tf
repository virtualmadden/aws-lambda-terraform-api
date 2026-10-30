variable "github_repository" {
  description = "The repo that deploys the API, as owner/name."
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$", var.github_repository))
    error_message = "github_repository must look like owner/name."
  }
}

variable "domain_name" {
  description = "Hostname the API serves; must match the api root's domain_name."
  type        = string
}

variable "hosted_zone_name" {
  description = "Existing Route53 public hosted zone that holds domain_name. Defaults to domain_name itself."
  type        = string
  default     = null
}

variable "aws_region" {
  description = "Region for the state bucket; use the same one for the API, since the deploy role is scoped to it."
  type        = string
  default     = "us-west-2"
}

variable "create_github_oidc_provider" {
  description = "Create the account's GitHub Actions OIDC provider. Set false if the account already has one; there can be only one."
  type        = bool
  default     = true
}

locals {
  repo_slug = lower(replace(split("/", var.github_repository)[1], "/[^a-z0-9-]/", "-"))

  # Must match local.name in api/variables.tf, so the deploy role reaches only this API.
  api_name = "${substr(replace(var.domain_name, ".", "-"), 0, 40)}-api"
}
