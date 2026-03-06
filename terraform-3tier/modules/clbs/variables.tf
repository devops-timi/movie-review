variable "project_name" {
    type = string 
}

variable "vpc_id" {
    type = string 
}

variable "web_subnet_ids" {
    type = list(string) 
}

variable "app_subnet_ids" {
    type = list(string) 
}

variable "public_alb_sg_id" {
    type = string 
}

variable "internal_alb_sg_id" { 
    type = string 
}