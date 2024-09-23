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
  default = "656732674839"
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
