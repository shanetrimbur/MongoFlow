# variables.tf - MongoFlow Terraform variables

variable "project_name" {
  description = "The name of the MongoDB Atlas project"
  type        = string
  default     = "MongoFlow"
}

variable "atlas_org_id" {
  description = "MongoDB Atlas organization ID"
  type        = string
  sensitive   = true
}

variable "cluster_name" {
  description = "The name of the MongoDB Atlas cluster"
  type        = string
  default     = "mongoflow-cluster"
}

variable "atlas_region" {
  description = "The region where the MongoDB Atlas cluster will be deployed"
  type        = string
  default     = "US_EAST_1"
}

# Additional variables omitted for brevity
