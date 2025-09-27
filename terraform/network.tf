locals {
  create_vpc = var.vpc_id == "" && length(var.private_subnet_ids) == 0 && length(var.public_subnet_ids) == 0
}

data "aws_availability_zones" "available" {
  state = "available"
}

module "vpc" {
  count   = local.create_vpc ? 1 : 0
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.9.0"

  name = "${var.project_name}-vpc"
  cidr = "10.20.0.0/16"

  azs = slice(data.aws_availability_zones.available.names, 0, 3)

  private_subnets = [for index in range(3) : cidrsubnet("10.20.0.0/16", 4, index)]
  public_subnets  = [for index in range(3) : cidrsubnet("10.20.0.0/16", 4, index + 8)]

  enable_nat_gateway     = false
  enable_dns_hostnames   = true
  enable_dns_support     = true
  manage_default_security_group = false

  private_subnet_tags = merge(local.default_tags, {
    "kubernetes.io/role/internal-elb" = "1"
  })

  public_subnet_tags = merge(local.default_tags, {
    "kubernetes.io/role/elb" = "1"
  })

  tags     = local.default_tags
  vpc_tags = local.default_tags
}

locals {
  vpc_id = local.create_vpc ? module.vpc[0].vpc_id : var.vpc_id

  private_subnet_ids = local.create_vpc ? module.vpc[0].private_subnets : var.private_subnet_ids
  public_subnet_ids  = local.create_vpc ? module.vpc[0].public_subnets : var.public_subnet_ids
}

