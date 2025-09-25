module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "20.18.0"

  cluster_name    = var.cluster_name
  cluster_version = var.eks_version
  cluster_enabled_log_types = ["api", "audit", "authenticator"]

  cluster_tags = local.default_tags

  access_config = {
    authentication_mode                         = "API_AND_CONFIG_MAP"
    bootstrap_cluster_creator_admin_permissions = true
  }

  vpc_id     = local.vpc_id
  subnet_ids = concat(local.private_subnet_ids, local.public_subnet_ids)

  create_cluster_security_group = true
  cluster_security_group_name    = "${var.cluster_name}-cluster-sg"
  cluster_security_group_tags    = local.default_tags

  cluster_endpoint_public_access = true
  cluster_endpoint_private_access = true

  enable_irsa = true

  eks_managed_node_groups = {
    default = {
      name                = var.node_group_name
      instance_types      = [var.node_instance_type]
      min_size            = var.node_min_size
      max_size            = var.node_max_size
      desired_size        = var.node_desired_size
      capacity_type       = "SPOT"
      subnet_ids          = local.private_subnet_ids
      force_update_version = true

      tags = local.default_tags

      labels = {
        node_class         = "general-purpose"
        cost_optimization  = "spot"
      }

      block_device_mappings = {
        xvda = {
          ebs = {
            volume_size           = 20
            volume_type           = "gp3"
            delete_on_termination = true
          }
        }
      }
    }
  }

  tags = local.default_tags
}

