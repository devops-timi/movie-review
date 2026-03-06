# Canonical's AWS account ID — ensures the AMI comes from the official publisher
locals {
  canonical_owner_id = "099720109477"
}

# Latest Ubuntu 24.04 LTS (Noble Numbat) AMI for the web tier
data "aws_ami" "ubuntu_web" {
  most_recent = true
  owners      = [local.canonical_owner_id]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "architecture"
    values = [var.ami_architecture]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

# Latest Ubuntu 24.04 LTS (Noble Numbat) AMI for the app tier
# Separate data source so web and app tiers can diverge (e.g. different
# architecture or region) without affecting each other.
data "aws_ami" "ubuntu_app" {
  most_recent = true
  owners      = [local.canonical_owner_id]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "architecture"
    values = [var.ami_architecture]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}
