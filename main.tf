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
