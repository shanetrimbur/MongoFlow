# main.tf - MongoFlow Terraform configuration

# Create a MongoDB Atlas Project
resource "mongodbatlas_project" "mongoflow_project" {
  name   = var.project_name
  org_id = var.atlas_org_id
}

# Create a MongoDB Atlas Cluster with M0 free tier
resource "mongodbatlas_cluster" "mongoflow_cluster" {
  project_id = mongodbatlas_project.mongoflow_project.id
  name       = var.cluster_name

  # Free tier M0 settings
  provider_name               = "TENANT"
  backing_provider_name       = "AWS"
  provider_region_name        = var.atlas_region
  provider_instance_size_name = "M0"

  # MongoDB version
  mongo_db_major_version = "6.0"

  # Backup settings
  auto_scaling_disk_gb_enabled = false
  
  # Advanced configurations
  advanced_configuration {
    javascript_enabled = true
    minimum_enabled_tls_protocol = "TLS1_2"
  }
}

# Additional resources omitted for brevity
