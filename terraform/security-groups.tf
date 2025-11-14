# ==================================================================
# SECURITY GROUPS FOR DATABASE & CACHE SERVICES
# ==================================================================

# PostgreSQL Security Group
module "postgresql_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 5.0"

  name        = "${var.project_name}-postgresql-sg"
  description = "Security group for PostgreSQL RDS"
  vpc_id      = module.vpc.vpc_id

  ingress_with_cidr_blocks = [
    {
      from_port   = 5432
      to_port     = 5432
      protocol    = "tcp"
      cidr_blocks = module.vpc.vpc_cidr_block
      description = "PostgreSQL from VPC"
    }
  ]

  egress_rules = ["all-all"]

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-postgresql-sg"
  })
}

# MongoDB (DocumentDB) Security Group
module "mongodb_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 5.0"

  name        = "${var.project_name}-mongodb-sg"
  description = "Security group for MongoDB DocumentDB"
  vpc_id      = module.vpc.vpc_id

  ingress_with_cidr_blocks = [
    {
      from_port   = 27017
      to_port     = 27017
      protocol    = "tcp"
      cidr_blocks = module.vpc.vpc_cidr_block
      description = "MongoDB from VPC"
    }
  ]

  egress_rules = ["all-all"]

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-mongodb-sg"
  })
}

# Redis (ElastiCache) Security Group
module "redis_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 5.0"

  name        = "${var.project_name}-redis-sg"
  description = "Security group for Redis ElastiCache"
  vpc_id      = module.vpc.vpc_id

  ingress_with_cidr_blocks = [
    {
      from_port   = 6379
      to_port     = 6379
      protocol    = "tcp"
      cidr_blocks = module.vpc.vpc_cidr_block
      description = "Redis from VPC"
    }
  ]

  egress_rules = ["all-all"]

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-redis-sg"
  })
}
