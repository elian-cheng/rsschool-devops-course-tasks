aws_region             = "eu-north-1"
account_id             = "656732674839"
github_org             = "elian-cheng"
github_repo            = "rsschool-devops-course-tasks"
terraform_state_bucket = "elian-terraform-s3-state"
vpc_cidr               = "10.0.0.0/16"
public_subnet_cidrs    = ["10.0.1.0/24", "10.0.2.0/24"]
private_subnet_cidrs   = ["10.0.3.0/24", "10.0.4.0/24"]
# using GitHub Secrets for the private key
private_key            = ""