variable "aws_region" {
  description = "The AWS region where resources will be deployed"
  type        = string
  default     = "eu-north-1"
}

variable "terraform_state_bucket" {
  description = "S3 bucket for storing Terraform state"
  type        = string
  default     = "elian-terraform-s3-state"
}

variable "account_id" {
  description = "The AWS Account ID where resources will be deployed"
  type        = string
  default     = "656732674839"
}

variable "github_org" {
  description = "The GitHub organization or username"
  type        = string
  default     = "elian-cheng"
}

variable "github_repo" {
  description = "The GitHub repository name"
  type        = string
  default     = "rsschool-devops-course-tasks"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for the public subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for the private subnets"
  type        = list(string)
  default     = ["10.0.3.0/24", "10.0.4.0/24"]
}

variable "private_key" {
  description = "The private key used for SSH access to the private instance"
  type        = string
  sensitive   = true # Mark as sensitive to avoid showing the value in logs
}

