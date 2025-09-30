variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs where EKS cluster should run"
  type        = list(string)
}

variable "tags" {
  description = "Common tags to apply"
  type        = map(string)
  default     = {}
}

variable "node_configs" {
  type = object({
    instance_type = string
    scaling = object({
      desired = number
      min = number
      max = number
    })
  })
}

# variable "vault_unseal_kms_key_alias" {
#   type = string
# }

variable "ecr_kms_key_id" {
  type = string
}