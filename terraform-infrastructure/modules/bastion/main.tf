# Data source for latest Amazon Linux 2023 AMI
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Security group for bastion host
resource "aws_security_group" "bastion" {
  name_prefix = "${var.name_prefix}-bastion-"
  description = "Security group for bastion host (SSM access only)"
  vpc_id      = var.vpc_id

  # No inbound rules needed - access via SSM Session Manager

  # Outbound to internet
  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.name_prefix}-bastion-sg"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# IAM role for bastion host
resource "aws_iam_role" "bastion" {
  name_prefix = "${var.name_prefix}-bastion-"

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

  tags = {
    Name = "${var.name_prefix}-bastion-role"
  }
}

# Attach SSM managed policy for session manager access
resource "aws_iam_role_policy_attachment" "bastion_ssm" {
  role       = aws_iam_role.bastion.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Attach policies for EKS access
resource "aws_iam_role_policy" "bastion_eks_access" {
  name_prefix = "${var.name_prefix}-bastion-eks-"
  role        = aws_iam_role.bastion.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "eks:DescribeCluster",
          "eks:ListClusters",
          "eks:DescribeNodegroup",
          "eks:ListNodegroups",
          "eks:AccessKubernetesApi"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "ec2:DescribeNetworkInterfaces"
        ]
        Resource = "*"
      }
    ]
  })
}

# IAM instance profile
resource "aws_iam_instance_profile" "bastion" {
  name_prefix = "${var.name_prefix}-bastion-"
  role        = aws_iam_role.bastion.name

  tags = {
    Name = "${var.name_prefix}-bastion-profile"
  }
}

# User data script to install kubectl, helm, and configure access
locals {
  user_data = <<-EOF
    #!/bin/bash
    set -e
    
    # Update system
    dnf update -y
    
    # Install required packages
    dnf install -y git jq tar gzip
    
    # Install kubectl
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    chmod +x kubectl
    mv kubectl /usr/local/bin/
    
    # Install helm
    curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
    
    # Install AWS CLI v2
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip awscliv2.zip
    ./aws/install
    rm -rf aws awscliv2.zip
    
    # Get region from instance metadata
    REGION=$(ec2-metadata --availability-zone | sed 's/.$//')
    
    # Configure kubectl for EKS for root user
    mkdir -p /root/.kube
    aws eks update-kubeconfig --region $REGION --name ${var.cluster_name} --kubeconfig /root/.kube/config
    
    # Configure kubectl for ec2-user
    mkdir -p /home/ec2-user/.kube
    aws eks update-kubeconfig --region $REGION --name ${var.cluster_name} --kubeconfig /home/ec2-user/.kube/config
    chown -R ec2-user:ec2-user /home/ec2-user/.kube
    chmod 600 /home/ec2-user/.kube/config
    
    # Configure kubectl for ssm-user (used by SSM Session Manager)
    mkdir -p /home/ssm-user/.kube
    aws eks update-kubeconfig --region $REGION --name ${var.cluster_name} --kubeconfig /home/ssm-user/.kube/config
    chown -R ssm-user:ssm-user /home/ssm-user/.kube 2>/dev/null || true
    chmod 600 /home/ssm-user/.kube/config 2>/dev/null || true
    
    # Create shared kubeconfig that all users can access
    mkdir -p /etc/kube
    aws eks update-kubeconfig --region $REGION --name ${var.cluster_name} --kubeconfig /etc/kube/config
    chmod 644 /etc/kube/config
    
    # Install helm repositories
    helm repo add bitnami https://charts.bitnami.com/bitnami
    helm repo add eks https://aws.github.io/eks-charts
    helm repo update
    
    # Create directory for manifests
    mkdir -p /home/ec2-user/k8s-manifests
    chown -R ec2-user:ec2-user /home/ec2-user/k8s-manifests
    
    # Add helpful aliases and environment for ec2-user
    cat >> /home/ec2-user/.bashrc <<'BASHRC'
alias k='kubectl'
alias kgp='kubectl get pods'
alias kgs='kubectl get svc'
alias kga='kubectl get all'
alias kgn='kubectl get nodes'
alias kn='kubectl config set-context --current --namespace'
export KUBECONFIG=/home/ec2-user/.kube/config
BASHRC
    
    # Add helpful aliases and environment for ssm-user
    cat >> /home/ssm-user/.bashrc <<'BASHRC'
alias k='kubectl'
alias kgp='kubectl get pods'
alias kgs='kubectl get svc'
alias kga='kubectl get all'
alias kgn='kubectl get nodes'
alias kn='kubectl config set-context --current --namespace'
export KUBECONFIG=/home/ssm-user/.kube/config
BASHRC
    
    # Global environment for all users
    echo 'export KUBECONFIG=/etc/kube/config' >> /etc/profile.d/kubectl.sh
    chmod +x /etc/profile.d/kubectl.sh
    
    echo "Bastion host setup complete!" > /var/log/user-data-complete.log
  EOF
}

# Bastion EC2 instance
resource "aws_instance" "bastion" {
  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = var.instance_type
  subnet_id              = var.private_subnet_id
  vpc_security_group_ids = [aws_security_group.bastion.id]
  iam_instance_profile   = aws_iam_instance_profile.bastion.name

  user_data                   = local.user_data
  user_data_replace_on_change = true

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 20
    encrypted             = true
    delete_on_termination = true
  }

  tags = {
    Name = "${var.name_prefix}-bastion"
  }
}

# Note: No EIP needed - bastion is in private subnet, access via SSM Session Manager
# To connect: aws ssm start-session --target <instance-id> --region <region>
