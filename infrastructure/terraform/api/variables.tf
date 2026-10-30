variable "domain_name" {
  description = "Hostname the API serves, e.g. api.example.com."
  type        = string
}

variable "hosted_zone_name" {
  description = "Existing Route53 public hosted zone, in this account, that holds domain_name. Defaults to domain_name itself."
  type        = string
  default     = null
}

variable "aws_region" {
  description = "Region for everything: the function, the API and its certificate."
  type        = string
  default     = "us-west-2"
}

variable "memory_size" {
  description = "Function memory in MB; CPU scales with it."
  type        = number
  default     = 256
}

variable "timeout" {
  description = "Function timeout in seconds. API Gateway gives up after 30 regardless."
  type        = number
  default     = 10
}

variable "throttling_rate_limit" {
  description = "Steady-state requests per second the API accepts before answering 429."
  type        = number
  default     = 50
}

variable "throttling_burst_limit" {
  description = "Requests the API accepts in a burst above the rate limit."
  type        = number
  default     = 100
}

variable "cors_allow_origins" {
  description = "Browser origins allowed to call the API, e.g. [\"https://app.example.com\"]. Empty turns CORS off, which is right for server-to-server callers."
  type        = list(string)
  default     = []
}

variable "log_retention_days" {
  description = "How long function and access logs are kept."
  type        = number
  default     = 30
}

variable "tags" {
  description = "Extra tags for every resource."
  type        = map(string)
  default     = {}
}

locals {
  # Must match local.api_name in bootstrap/variables.tf, which scopes the deploy role to it.
  name = "${substr(replace(var.domain_name, ".", "-"), 0, 40)}-api"

  # coalesce also treats "" as unset, which is what an empty GitHub variable becomes.
  zone_name = coalesce(var.hosted_zone_name, var.domain_name)

  tags = merge({ Api = var.domain_name, ManagedBy = "terraform" }, var.tags)
}
