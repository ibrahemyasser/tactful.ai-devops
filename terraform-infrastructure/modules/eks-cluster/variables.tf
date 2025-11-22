variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "cluster_version" {
  description = "Kubernetes version for EKS cluster"
  type        = string
  default     = "1.34"
}

variable "vpc_id" {
  description = "VPC ID where EKS cluster will be deployed"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for EKS cluster and nodes"
  type        = list(string)
}

variable "endpoint_public_access" {
  description = "Enable public access to cluster API endpoint"
  type        = bool
  default     = false
}

variable "public_access_cidrs" {
  description = "List of CIDR blocks that can access the public API endpoint"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "allowed_cidr_blocks" {
  description = "List of CIDR blocks allowed to access cluster (via bastion/VPN)"
  type        = list(string)
  default     = []
}

variable "cluster_log_types" {
  description = "List of control plane logging types to enable"
  type        = list(string)
  default     = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
}

variable "log_retention_days" {
  description = "Number of days to retain cluster logs"
  type        = number
  default     = 7
}

variable "kms_key_arn" {
  description = "ARN of KMS key for secrets encryption (creates new if empty)"
  type        = string
  default     = ""
}

variable "node_groups" {
  description = "Map of node group configurations"
  type = map(object({
    instance_types = list(string)
    min_size       = number
    max_size       = number
    desired_size   = number
    capacity_type  = optional(string)
    disk_size      = optional(number)
    labels         = optional(map(string))
  }))
  default = {
    general = {
      instance_types = ["t3.medium"]
      min_size       = 1
      max_size       = 3
      desired_size   = 2
    }
  }
}

variable "pod_identity_version" {
  description = "Version of the EKS Pod Identity addon"
  type        = string
  default     = ""
}

variable "vpc_cni_version" {
  description = "Version of the VPC CNI addon"
  type        = string
  default     = ""
}

variable "kube_proxy_version" {
  description = "Version of the kube-proxy addon"
  type        = string
  default     = ""
}

variable "coredns_version" {
  description = "Version of the CoreDNS addon"
  type        = string
  default     = ""
}

variable "ebs_csi_version" {
  description = "Version of the EBS CSI driver addon"
  type        = string
  default     = ""
}

variable "external_secrets_role_arn" {
  description = "IAM role ARN for External Secrets Operator (empty to skip Pod Identity association)"
  type        = string
  default     = ""
}

variable "alb_controller_role_arn" {
  description = "IAM role ARN for AWS Load Balancer Controller (empty to skip Pod Identity association)"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
