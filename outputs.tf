output "cluster_id" {
  description = "EKS cluster ID"
  value       = module.eks.cluster_id
}

output "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = module.eks.cluster_endpoint
}

output "cluster_security_group_id" {
  description = "Security group ids attached to the cluster control plane"
  value       = module.eks.cluster_security_group_id
}

output "region" {
  description = "AWS region"
  value       = var.region
}

output "cluster_name" {
  description = "Kubernetes Cluster Name"
  value       = local.cluster_name
}

output "oidc_provider_arn" {
  description = "oidc provider"
  value       =  module.eks.oidc_provider_arn
}

output "oidc_provider" {
  description = "oidc provider"
  value       =  module.eks.oidc_provider
}


output "bastion-public-ip" {
  value = aws_instance.public-bastion-1.public_ip
}