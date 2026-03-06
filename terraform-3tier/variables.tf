variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Prefix for all resource names"
  type        = string
  default     = "movie-review-app"
}

# ── Networking ──────────────────────────────
variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "availability_zones" {
  type    = list(string)
  default = ["us-east-1a", "us-east-1b"]
}

variable "web_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "app_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.11.0/24", "10.0.12.0/24"]
}

variable "db_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.21.0/24", "10.0.22.0/24"]
}

# ── EC2 ─────────────────────────────────────
variable "key_name" {
  description = "infrastructure key"
  type        = string
  default     = "connect"
}

variable "web_instance_type" {
  type    = string
  default = "t3.small"
}

variable "app_instance_type" {
  type    = string
  default = "t3.small"
}

variable "ami_architecture" {
  description = "CPU architecture for Ubuntu 24.04 AMI lookup. Use 'x86_64' for t3/m5/c5 instance families, 'arm64' for t4g/m7g/c7g Graviton instances."
  type        = string
  default     = "x86_64"

  validation {
    condition     = contains(["x86_64", "arm64"], var.ami_architecture)
    error_message = "ami_architecture must be either 'x86_64' or 'arm64'."
  }
}

# ── RDS ─────────────────────────────────────
variable "db_name" {
  type    = string
  default = "moviedb"
}

variable "db_username" {
  type      = string
  sensitive = true 
}

variable "db_password" {
  type      = string
  sensitive = true
}

variable "db_instance_class" {
  type    = string
  default = "db.t3.micro"
}
