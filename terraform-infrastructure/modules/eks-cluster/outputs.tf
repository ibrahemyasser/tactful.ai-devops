output "cluster_id" {
  description = "The name/id of the EKS cluster"
  value       = aws_eks_cluster.main.id
}

output "cluster_arn" {
  description = "The Amazon Resource Name (ARN) of the cluster"
  value       = aws_eks_cluster.main.arn
}

output "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = aws_eks_cluster.main.endpoint
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data required to communicate with the cluster"
  value       = aws_eks_cluster.main.certificate_authority[0].data
  sensitive   = true
}

output "cluster_version" {
  description = "The Kubernetes server version for the cluster"
  value       = aws_eks_cluster.main.version
}

output "cluster_security_group_id" {
  description = "Security group ID attached to the EKS cluster"
  value       = aws_security_group.cluster.id
}

output "cluster_iam_role_arn" {
  description = "IAM role ARN of the EKS cluster"
  value       = aws_iam_role.cluster.arn
}

output "node_group_iam_role_arn" {
  description = "IAM role ARN of the EKS node group"
  value       = aws_iam_role.node_group.arn
}

output "pod_identity_addon_arn" {
  description = "ARN of the EKS Pod Identity addon"
  value       = aws_eks_addon.pod_identity.arn
}

output "vpc_cni_addon_arn" {
  description = "ARN of the VPC CNI addon"
  value       = aws_eks_addon.vpc_cni.arn
}

output "kube_proxy_addon_arn" {
  description = "ARN of the kube-proxy addon"
  value       = aws_eks_addon.kube_proxy.arn
}

output "coredns_addon_arn" {
  description = "ARN of the CoreDNS addon"
  value       = aws_eks_addon.coredns.arn
}

output "ebs_csi_addon_arn" {
  description = "ARN of the EBS CSI driver addon"
  value       = aws_eks_addon.ebs_csi_driver.arn
}

output "ebs_csi_driver_role_arn" {
  description = "IAM role ARN for EBS CSI driver"
  value       = aws_iam_role.ebs_csi_driver.arn
}

output "node_groups" {
  description = "Outputs from EKS node groups"
  value = {
    for k, v in aws_eks_node_group.main : k => {
      id          = v.id
      arn         = v.arn
      status      = v.status
      capacity_type = v.capacity_type
    }
  }
}
