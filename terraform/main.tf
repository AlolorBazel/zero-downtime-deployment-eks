# ============================================================================
# Main Terraform Configuration for Zero-Downtime EKS Deployment
# ============================================================================

# Local variables
locals {
  cluster_name = "${var.project_name}-${var.environment}"

  tags = merge(
    var.tags,
    {
      Environment = var.environment
      ClusterName = local.cluster_name
    }
  )
}

# ============================================================================
# VPC Configuration
# ============================================================================
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.16"

  name = "${local.cluster_name}-vpc"
  cidr = var.vpc_cidr

  azs             = var.azs
  private_subnets = var.private_subnets
  public_subnets  = var.public_subnets
  intra_subnets   = var.intra_subnets

  enable_nat_gateway   = var.enable_nat_gateway
  single_nat_gateway   = var.single_nat_gateway
  enable_dns_hostnames = var.enable_dns_hostnames
  enable_dns_support   = var.enable_dns_support

  # Kubernetes-specific tags for subnet discovery
  public_subnet_tags = {
    "kubernetes.io/role/elb"                      = "1"
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb"             = "1"
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    # Karpenter tags (for autoscaling)
    "karpenter.sh/discovery" = local.cluster_name
  }

  tags = local.tags
}

# ============================================================================
# KMS Key for EKS Encryption
# ============================================================================
resource "aws_kms_key" "eks" {
  count = var.enable_kms_encryption ? 1 : 0

  description             = "EKS Secret Encryption Key for ${local.cluster_name}"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = merge(
    local.tags,
    {
      Name = "${local.cluster_name}-eks-secrets"
    }
  )
}

resource "aws_kms_alias" "eks" {
  count = var.enable_kms_encryption ? 1 : 0

  name          = "alias/${local.cluster_name}-eks"
  target_key_id = aws_kms_key.eks[0].key_id
}

# ============================================================================
# EKS Cluster
# ============================================================================
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.31"

  cluster_name    = local.cluster_name
  cluster_version = var.cluster_version

  # Cluster access configuration
  cluster_endpoint_public_access       = var.cluster_endpoint_public_access
  cluster_endpoint_private_access      = var.cluster_endpoint_private_access
  cluster_endpoint_public_access_cidrs = var.cluster_endpoint_public_access_cidrs

  # Enable IRSA (IAM Roles for Service Accounts)
  enable_irsa = var.enable_irsa

  # Encryption configuration
  cluster_encryption_config = var.enable_kms_encryption ? [
    {
      provider_key_arn = aws_kms_key.eks[0].arn
      resources        = ["secrets"]
    }
  ] : []

  # CloudWatch logging
  cluster_enabled_log_types              = var.enable_cloudwatch_logs ? var.cluster_enabled_log_types : []
  cloudwatch_log_group_retention_in_days = var.cloudwatch_log_group_retention_in_days

  # VPC configuration
  vpc_id                   = module.vpc.vpc_id
  subnet_ids               = module.vpc.private_subnets
  control_plane_subnet_ids = var.intra_subnets != [] ? module.vpc.intra_subnets : null

  # Cluster access entry
  enable_cluster_creator_admin_permissions = var.enable_cluster_creator_admin_permissions

  # EKS Managed Node Groups
  eks_managed_node_groups = {
    for k, v in var.node_groups : k => {
      name           = "${local.cluster_name}-${k}"
      instance_types = v.instance_types
      capacity_type  = v.capacity_type

      min_size     = v.min_size
      max_size     = v.max_size
      desired_size = v.desired_size

      disk_size = v.disk_size

      labels = v.labels
      taints = v.taints

      # Enable IMDSv2
      metadata_options = {
        http_endpoint               = "enabled"
        http_tokens                 = "required"
        http_put_response_hop_limit = 2
        instance_metadata_tags      = "enabled"
      }

      # Additional IAM policies for nodes
      iam_role_additional_policies = {
        AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
        CloudWatchAgentServerPolicy  = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
      }

      tags = merge(
        local.tags,
        {
          NodeGroup = k
        }
      )
    }
  }

  # EKS Addons
  cluster_addons = {
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
    }
    aws-ebs-csi-driver = {
      most_recent = true
      service_account_role_arn = module.ebs_csi_driver_irsa.iam_role_arn
    }
  }

  # Node security group additional rules
  node_security_group_additional_rules = {
    ingress_self_all = {
      description = "Node to node all ports/protocols"
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      type        = "ingress"
      self        = true
    }

    ingress_cluster_all = {
      description                   = "Cluster to node all ports/protocols"
      protocol                      = "-1"
      from_port                     = 0
      to_port                       = 0
      type                          = "ingress"
      source_cluster_security_group = true
    }

    egress_all = {
      description      = "Node all egress"
      protocol         = "-1"
      from_port        = 0
      to_port          = 0
      type             = "egress"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
    }
  }

  tags = local.tags
}

# ============================================================================
# AWS Auth ConfigMap (for backwards compatibility)
# ============================================================================
# Note: With EKS access entries (enabled above), this is optional
# Uncomment if you need to manage aws-auth ConfigMap manually

# ============================================================================
# Kubernetes Storage Class for EBS CSI Driver
# ============================================================================
resource "kubernetes_storage_class_v1" "ebs_gp3" {
  metadata {
    name = "ebs-gp3"
    annotations = {
      "storageclass.kubernetes.io/is-default-class" = "true"
    }
  }

  storage_provisioner    = "ebs.csi.aws.com"
  reclaim_policy         = "Delete"
  allow_volume_expansion = true
  volume_binding_mode    = "WaitForFirstConsumer"

  parameters = {
    type      = "gp3"
    encrypted = "true"
    kmsKeyId  = var.enable_kms_encryption ? aws_kms_key.eks[0].arn : ""
  }

  depends_on = [module.eks]
}

# ============================================================================
# Kubernetes Namespaces
# ============================================================================
resource "kubernetes_namespace_v1" "applications" {
  metadata {
    name = "applications"
    labels = {
      name        = "applications"
      environment = var.environment
    }
  }

  depends_on = [module.eks]
}

resource "kubernetes_namespace_v1" "monitoring" {
  metadata {
    name = "monitoring"
    labels = {
      name        = "monitoring"
      environment = var.environment
    }
  }

  depends_on = [module.eks]
}

resource "kubernetes_namespace_v1" "ingress" {
  metadata {
    name = "ingress"
    labels = {
      name        = "ingress"
      environment = var.environment
    }
  }

  depends_on = [module.eks]
}

resource "kubernetes_namespace_v1" "argo_rollouts" {
  metadata {
    name = "argo-rollouts"
    labels = {
      name        = "argo-rollouts"
      environment = var.environment
    }
  }

  depends_on = [module.eks]
}
