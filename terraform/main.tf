# ================================================================
# COMET BROWSER - LAYER 1 INFRASTRUCTURE FOUNDATION
# Complete Cloud Infrastructure as Code (IaC)
# Multi-Cloud Support: AWS, Azure, GCP
# ================================================================

terraform {
  required_version = ">= 1.6.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.11"
    }
  }
  
  backend "s3" {
    bucket         = "comet-terraform-state"
    key            = "layer1/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-lock"
  }
}

# ================================================================
# VARIABLES
# ================================================================

variable "environment" {
  description = "Environment name (dev, staging, production)"
  type        = string
  default     = "production"
}

variable "project_name" {
  description = "Project name for resource tagging"
  type        = string
  default     = "comet-browser"
}

variable "region" {
  description = "Primary deployment region"
  type        = string
  default     = "us-east-1"
}

variable "kubernetes_version" {
  description = "Kubernetes cluster version"
  type        = string
  default     = "1.28"
}

# ================================================================
# AWS PROVIDER CONFIGURATION
# ================================================================

provider "aws" {
  region = var.region
  
  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
      Layer       = "1-Infrastructure"
    }
  }
}

# ================================================================
# NETWORKING - VPC & SUBNETS
# ================================================================

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"
  
  name = "${var.project_name}-vpc"
  cidr = "10.0.0.0/16"
  
  azs             = ["${var.region}a", "${var.region}b", "${var.region}c"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
  
  enable_nat_gateway   = true
  single_nat_gateway   = false
  enable_dns_hostnames = true
  enable_dns_support   = true
  
  tags = {
    "kubernetes.io/cluster/${var.project_name}-eks" = "shared"
  }
}

# ================================================================
# KUBERNETES - EKS CLUSTER
# ================================================================

module "eks" {
  source = "terraform-aws-modules/eks/aws"
  
  cluster_name    = "${var.project_name}-eks"
  cluster_version = var.kubernetes_version
  
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets
  
  cluster_endpoint_public_access = true
  
  eks_managed_node_groups = {
    general = {
      desired_size = 3
      min_size     = 2
      max_size     = 10
      
      instance_types = ["t3.xlarge"]
      capacity_type  = "ON_DEMAND"
      
      labels = {
        role = "general"
      }
    }
    
    compute = {
      desired_size = 2
      min_size     = 1
      max_size     = 5
      
      instance_types = ["c5.2xlarge"]
      capacity_type  = "SPOT"
      
      labels = {
        role = "compute-intensive"
      }
    }
  }
}

# ================================================================
# DATABASE - RDS POSTGRESQL
# ================================================================

module "rds_postgresql" {
  source = "terraform-aws-modules/rds/aws"
  
  identifier = "${var.project_name}-postgres"
  
  engine               = "postgres"
  engine_version       = "15.4"
  family               = "postgres15"
  major_engine_version = "15"
  instance_class       = "db.r6g.xlarge"
  
  allocated_storage     = 100
  max_allocated_storage = 500
  storage_encrypted     = true
  
  db_name  = "cometdb"
  username = "cometadmin"
  port     = 5432
  
  multi_az               = true
  db_subnet_group_name   = module.vpc.database_subnet_group_name
  vpc_security_group_ids = [module.postgresql_sg.security_group_id]
  
  backup_retention_period = 30
  backup_window           = "03:00-04:00"
  maintenance_window      = "Mon:04:00-Mon:05:00"
  
  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]
  
  tags = {
    Database = "PostgreSQL"
  }
}

# Random password for MongoDB
resource "random_password" "mongodb_password" {
  length  = 32
  special = true
}

# ================================================================
# DATABASE - MONGODB (DocumentDB)
# ================================================================

resource "aws_docdb_cluster" "mongodb" {
  cluster_identifier      = "${var.project_name}-mongodb"
  engine                  = "docdb"
  master_username         = "cometadmin"
  master_password         = random_password.mongodb_password.result
  backup_retention_period = 30
  preferred_backup_window = "03:00-04:00"
  skip_final_snapshot     = false
  final_snapshot_identifier = "${var.project_name}-mongodb-final"
  
  vpc_security_group_ids = [module.mongodb_sg.security_group_id]
  db_subnet_group_name   = module.vpc.database_subnet_group_name
  
  enabled_cloudwatch_logs_exports = ["audit", "profiler"]
  
  tags = {
    Database = "MongoDB"
  }
}

resource "aws_docdb_cluster_instance" "mongodb_instances" {
  count              = 3
  identifier         = "${var.project_name}-mongodb-${count.index}"
  cluster_identifier = aws_docdb_cluster.mongodb.id
  instance_class     = "db.r6g.large"
}

# ================================================================
# CACHE - ELASTICACHE REDIS
# ================================================================

module "redis" {
  source = "terraform-aws-modules/elasticache/aws"
  
  cluster_id           = "${var.project_name}-redis"
  engine               = "redis"
  engine_version       = "7.0"
  node_type            = "cache.r6g.large"
  num_cache_nodes      = 3
  parameter_group_name = "default.redis7"
  port                 = 6379
  
  subnet_group_name = module.vpc.elasticache_subnet_group_name
  security_group_ids = [module.redis_sg.security_group_id]
  
  snapshot_retention_limit = 7
  snapshot_window          = "03:00-05:00"
  maintenance_window       = "sun:05:00-sun:07:00"
  
  at_rest_encryption_enabled = true
  transit_encryption_enabled = true
  
  tags = {
    Cache = "Redis"
  }
}

# ================================================================
# OUTPUTS
# ================================================================

output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "eks_cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = module.eks.cluster_endpoint
}

output "postgresql_endpoint" {
  description = "PostgreSQL endpoint"
  value       = module.rds_postgresql.db_instance_endpoint
  sensitive   = true
}

output "mongodb_endpoint" {
  description = "MongoDB cluster endpoint"
  value       = aws_docdb_cluster.mongodb.endpoint
  sensitive   = true
}

output "redis_endpoint" {
  description = "Redis endpoint"
  value       = module.redis.cluster_cache_nodes
  sensitive   = true
}
