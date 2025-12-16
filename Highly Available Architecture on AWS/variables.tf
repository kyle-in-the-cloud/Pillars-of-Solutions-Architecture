variable "project" {
  type = string
  default = "medicare"
}

variable "region" {
  type = string
  default = "us-east-1"
  description = "AWS Region"
}

variable "vpcciderblock" {
  default = "10.1.0.0/16"
}

variable "instance_type" {
  default = "t2.micro"
}

variable "ami_id" {
  default = "ami-068c0051b15cdb816"
}

variable "key_name" {
  default = "bastion-host-key"
}

variable "environment" {
  type = string
  default = "dev"
}

variable "db_engine" {
  type = string
  default = "mysql"
}

variable "engine_version" {
  type = string
  default = "8.0"
}

variable "instance_class" {
  type    = string
  default = "db.m5.large"
}

variable "storage_type" {
  default = "gp3"
}

variable "allocated_storage" {
  type    = number
  default = 20
}

variable "max_allocated_storage" {
  type    = number
  default = 100
}

variable "db_username" {
  type        = string
  description = "Master database username"
  default     = "admin"
}

variable "db_password" {
  type        = string
  sensitive   = true
  description = "Master database password"
}

variable "db_port" {
  type    = number
  default = 3306
}

variable "multi_az" {
  type    = bool
  default = true
}

variable "route53_domain" {
  default = "awstower.click"
}