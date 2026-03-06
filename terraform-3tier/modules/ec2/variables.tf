variable "project_name" { 
    type = string
}

variable "web_subnet_ids" {
    type = list(string) 
}

variable "app_subnet_ids" {
    type = list(string) 
}

variable "web_sg_id" {
    type = string 
}

variable "app_sg_id" {
    type = string 
}

variable "public_clb_name" {
  type = string
}

variable "internal_clb_name" {
  type = string
}

variable "key_name" {
    type = string 
}

variable "web_instance_type" {
    type = string 
}

variable "app_instance_type" {
    type = string 
}

variable "web_ami" {
    type = string 
}

variable "app_ami" {
    type = string 
}