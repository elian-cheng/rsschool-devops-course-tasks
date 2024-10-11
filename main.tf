provider "aws" {
  region = "eu-north-1"
}

terraform {
  backend "s3" {
    bucket = "elian-terraform-s3-state"
    key    = "terraform.tfstate"
    region = "eu-north-1"
  }
}

data "aws_availability_zones" "available" {}

locals {
  name   = "${basename(path.cwd)}"
  region = "eu-north-1"

  vpc_cidr = var.vpc_cidr
  azs      = slice(data.aws_availability_zones.available.names, 0, 3)

  tags = {
    Project    = local.name
    GithubRepo = var.github_repo
    GithubOrg  = var.github_org
  }
}