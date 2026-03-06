variable "project_name" { 
    type = string
}

variable "vpc_cidr" {
    type = string 
}

variable "availability_zones" {
    type = list(string) 
}

variable "web_subnet_cidrs" {
    type = list(string) 
}

variable "app_subnet_cidrs" {
    type = list(string) 
}

variable "db_subnet_cidrs" {
    type = list(string) 
}