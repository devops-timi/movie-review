terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# ─────────────────────────────────────────────
# VPC
# ─────────────────────────────────────────────
module "vpc" {
  source = "./modules/vpc"

  project_name       = var.project_name
  vpc_cidr           = var.vpc_cidr
  availability_zones = var.availability_zones

  web_subnet_cidrs = var.web_subnet_cidrs
  app_subnet_cidrs = var.app_subnet_cidrs
  db_subnet_cidrs  = var.db_subnet_cidrs
}

# ─────────────────────────────────────────────
# SECURITY GROUPS
# ─────────────────────────────────────────────
module "security_groups" {
  source = "./modules/security-groups"

  project_name = var.project_name
  vpc_id       = module.vpc.vpc_id
}

# ─────────────────────────────────────────────
# LOAD BALANCERS
# ─────────────────────────────────────────────
module "alb" {
  source = "./modules/clbs"

  project_name        = var.project_name
  vpc_id              = module.vpc.vpc_id
  web_subnet_ids      = module.vpc.web_subnet_ids
  app_subnet_ids      = module.vpc.app_subnet_ids
  public_alb_sg_id    = module.security_groups.public_alb_sg_id
  internal_alb_sg_id  = module.security_groups.internal_alb_sg_id
}

# ─────────────────────────────────────────────
# EC2 (Web + App tiers)
# ─────────────────────────────────────────────
module "ec2" {
  source = "./modules/ec2"

  project_name          = var.project_name
  web_subnet_ids        = module.vpc.web_subnet_ids
  app_subnet_ids        = module.vpc.app_subnet_ids
  web_sg_id             = module.security_groups.web_sg_id
  app_sg_id             = module.security_groups.app_sg_id
  public_clb_name       = module.alb.public_clb_name
  internal_clb_name     = module.alb.internal_clb_name
  key_name              = var.key_name
  web_instance_type     = var.web_instance_type
  app_instance_type     = var.app_instance_type
  web_ami               = data.aws_ami.ubuntu_web.id
  app_ami               = data.aws_ami.ubuntu_app.id
}

# ─────────────────────────────────────────────
# RDS MySQL (Multi-AZ + Read Replica)
# ─────────────────────────────────────────────
module "rds" {
  source = "./modules/rds"

  project_name     = var.project_name
  db_subnet_ids    = module.vpc.db_subnet_ids
  db_sg_id         = module.security_groups.db_sg_id
  db_name          = var.db_name
  db_username      = var.db_username
  db_password      = var.db_password
  db_instance_class = var.db_instance_class
}
