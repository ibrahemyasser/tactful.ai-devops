# Private EKS Cluster Module
# Creates a private EKS cluster with private API endpoint

resource "aws_eks_cluster" "main" {
  name     = var.cluster_name
  version  = var.cluster_version
  role_arn = aws_iam_role.cluster.arn

  vpc_config {
    subnet_ids              = var.private_subnet_ids
    endpoint_private_access = true
    endpoint_public_access  = var.endpoint_public_access
    public_access_cidrs     = var.endpoint_public_access ? var.public_access_cidrs : []
    security_group_ids      = [aws_security_group.cluster.id]
  }

  enabled_cluster_log_types = var.cluster_log_types

  encryption_config {
    provider {
      key_arn = var.kms_key_arn != "" ? var.kms_key_arn : aws_kms_key.eks[0].arn
    }
    resources = ["secrets"]
  }

  # Enable API-based access management for EKS Access Entries
  access_config {
    authentication_mode                         = "API_AND_CONFIG_MAP"
    bootstrap_cluster_creator_admin_permissions = true
  }

  depends_on = [
    aws_iam_role_policy_attachment.cluster_policy,
    aws_iam_role_policy_attachment.cluster_service_policy,
    aws_cloudwatch_log_group.cluster
  ]

  tags = var.tags
}

# CloudWatch Log Group for EKS cluster logs
resource "aws_cloudwatch_log_group" "cluster" {
  name              = "/aws/eks/${var.cluster_name}/cluster"
  retention_in_days = var.log_retention_days

  tags = var.tags
}

# KMS Key for secrets encryption
resource "aws_kms_key" "eks" {
  count = var.kms_key_arn == "" ? 1 : 0

  description             = "EKS ${var.cluster_name} encryption key"
  deletion_window_in_days = 10
  enable_key_rotation     = true

  tags = merge(
    var.tags,
    {
      Name = "${var.cluster_name}-eks-encryption"
    }
  )
}

resource "aws_kms_alias" "eks" {
  count = var.kms_key_arn == "" ? 1 : 0

  name          = "alias/eks/${var.cluster_name}"
  target_key_id = aws_kms_key.eks[0].key_id
}

# IAM Role for EKS Cluster
resource "aws_iam_role" "cluster" {
  name = "${var.cluster_name}-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.cluster.name
}

resource "aws_iam_role_policy_attachment" "cluster_service_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
  role       = aws_iam_role.cluster.name
}

# Security Group for EKS Cluster
resource "aws_security_group" "cluster" {
  name_prefix = "${var.cluster_name}-cluster-sg"
  description = "Security group for EKS cluster control plane"
  vpc_id      = var.vpc_id

  tags = merge(
    var.tags,
    {
      Name = "${var.cluster_name}-cluster-sg"
    }
  )
}

resource "aws_security_group_rule" "cluster_ingress_workstation_https" {
  count = length(var.allowed_cidr_blocks) > 0 ? 1 : 0

  description       = "Allow workstation to communicate with the cluster API Server"
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = var.allowed_cidr_blocks
  security_group_id = aws_security_group.cluster.id
}

resource "aws_security_group_rule" "cluster_egress_all" {
  description       = "Allow cluster egress access to the Internet"
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.cluster.id
}

# Data sources for EKS addon versions
data "aws_eks_addon_version" "pod_identity" {
  addon_name         = "eks-pod-identity-agent"
  kubernetes_version = aws_eks_cluster.main.version
  most_recent        = true
}

data "aws_eks_addon_version" "vpc_cni" {
  addon_name         = "vpc-cni"
  kubernetes_version = aws_eks_cluster.main.version
  most_recent        = true
}

data "aws_eks_addon_version" "kube_proxy" {
  addon_name         = "kube-proxy"
  kubernetes_version = aws_eks_cluster.main.version
  most_recent        = true
}

data "aws_eks_addon_version" "coredns" {
  addon_name         = "coredns"
  kubernetes_version = aws_eks_cluster.main.version
  most_recent        = true
}

data "aws_eks_addon_version" "ebs_csi" {
  addon_name         = "aws-ebs-csi-driver"
  kubernetes_version = aws_eks_cluster.main.version
  most_recent        = true
}

# EKS Node Groups
resource "aws_eks_node_group" "main" {
  for_each = var.node_groups

  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.cluster_name}-${each.key}"
  node_role_arn   = aws_iam_role.node_group.arn
  subnet_ids      = var.private_subnet_ids

  instance_types = each.value.instance_types
  capacity_type  = lookup(each.value, "capacity_type", "ON_DEMAND")
  disk_size      = lookup(each.value, "disk_size", 20)

  scaling_config {
    desired_size = each.value.desired_size
    max_size     = each.value.max_size
    min_size     = each.value.min_size
  }

  update_config {
    max_unavailable = 1
  }

  labels = lookup(each.value, "labels", {})

  tags = merge(
    var.tags,
    {
      Name = "${var.cluster_name}-${each.key}-node"
    }
  )

  depends_on = [
    aws_iam_role_policy_attachment.node_group_policy,
    aws_iam_role_policy_attachment.node_group_cni_policy,
    aws_iam_role_policy_attachment.node_group_ecr_policy,
  ]

  lifecycle {
    create_before_destroy = true
    ignore_changes        = [scaling_config[0].desired_size]
  }
}

# IAM Role for Node Group
resource "aws_iam_role" "node_group" {
  name = "${var.cluster_name}-node-group-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "node_group_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.node_group.name
}

resource "aws_iam_role_policy_attachment" "node_group_cni_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.node_group.name
}

resource "aws_iam_role_policy_attachment" "node_group_ecr_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.node_group.name
}

# EKS Pod Identity Agent Addon
resource "aws_eks_addon" "pod_identity" {
  cluster_name  = aws_eks_cluster.main.name
  addon_name    = "eks-pod-identity-agent"
  addon_version = data.aws_eks_addon_version.pod_identity.version

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  tags = var.tags

  depends_on = [aws_eks_node_group.main]
}

# VPC CNI Addon
resource "aws_eks_addon" "vpc_cni" {
  cluster_name  = aws_eks_cluster.main.name
  addon_name    = "vpc-cni"
  addon_version = data.aws_eks_addon_version.vpc_cni.version

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  configuration_values = jsonencode({
    env = {
      ENABLE_PREFIX_DELEGATION = "true"
      WARM_PREFIX_TARGET       = "1"
    }
  })

  tags = var.tags

  depends_on = [aws_eks_node_group.main]
}

# kube-proxy Addon
resource "aws_eks_addon" "kube_proxy" {
  cluster_name  = aws_eks_cluster.main.name
  addon_name    = "kube-proxy"
  addon_version = data.aws_eks_addon_version.kube_proxy.version

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  tags = var.tags

  depends_on = [aws_eks_node_group.main]
}

# CoreDNS Addon
resource "aws_eks_addon" "coredns" {
  cluster_name  = aws_eks_cluster.main.name
  addon_name    = "coredns"
  addon_version = data.aws_eks_addon_version.coredns.version

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  tags = var.tags

  depends_on = [aws_eks_node_group.main]
}

# IAM Role for EBS CSI Driver with Pod Identity
resource "aws_iam_role" "ebs_csi_driver" {
  name = "${var.cluster_name}-ebs-csi-driver-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "pods.eks.amazonaws.com"
      }
      Action = [
        "sts:AssumeRole",
        "sts:TagSession"
      ]
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "ebs_csi_driver" {
  role       = aws_iam_role.ebs_csi_driver.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

# Pod Identity Association for EBS CSI Driver
resource "aws_eks_pod_identity_association" "ebs_csi_driver" {
  cluster_name    = aws_eks_cluster.main.name
  namespace       = "kube-system"
  service_account = "ebs-csi-controller-sa"
  role_arn        = aws_iam_role.ebs_csi_driver.arn

  tags = merge(
    var.tags,
    {
      Name = "${var.cluster_name}-ebs-csi-driver-pod-identity"
    }
  )

  depends_on = [aws_eks_cluster.main]
}

# EBS CSI Driver Addon
resource "aws_eks_addon" "ebs_csi_driver" {
  cluster_name                = aws_eks_cluster.main.name
  addon_name                  = "aws-ebs-csi-driver"
  addon_version               = data.aws_eks_addon_version.ebs_csi.version
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  tags = var.tags

  depends_on = [
    aws_eks_node_group.main,
    aws_eks_pod_identity_association.ebs_csi_driver
  ]
}

# Pod Identity Association for External Secrets Operator
# This is created here but the IAM role is managed by the secrets-manager module
resource "aws_eks_pod_identity_association" "external_secrets" {
  count = var.external_secrets_role_arn != "" ? 1 : 0

  cluster_name    = aws_eks_cluster.main.name
  namespace       = "external-secrets-system"
  service_account = "external-secrets"
  role_arn        = var.external_secrets_role_arn

  tags = merge(
    var.tags,
    {
      Name = "${var.cluster_name}-external-secrets-pod-identity"
    }
  )

  depends_on = [aws_eks_cluster.main]
}
