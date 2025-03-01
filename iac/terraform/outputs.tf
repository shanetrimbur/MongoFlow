# outputs.tf - MongoFlow Terraform outputs

output "mongodb_connection_string" {
  value     = mongodbatlas_cluster.mongoflow_cluster.connection_strings[0].standard
  sensitive = true
}

output "cluster_id" {
  value = mongodbatlas_cluster.mongoflow_cluster.id
}
