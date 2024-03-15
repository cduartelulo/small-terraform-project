terraform {
  required_version = "~> 1.2"
  backend "s3" {
    bucket         = "sion-terraform-dojo"
    key            = "terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-locks"
    profile        = var.aws_profile
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.40"
    }
  }
}

provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile
}

#resource "aws_s3_bucket_versioning" "terraform_remote_state_versioning" {
#  bucket = aws_s3_bucket.terraform_remote_state_bucket.id
#  versioning_configuration {
#    status = "Enabled"
#  }
#}
#
#resource "aws_s3_bucket" "terraform_remote_state_bucket" {
#  bucket = "sion-terraform-dojo"
#  tags = {
#    Team =  "Sion"
#  }
#}
#
#resource "aws_dynamodb_table" "terraform-locks" {
#  name = "TerraformLock"
#  billing_mode = "PAY_PER_REQUEST"
#  hash_key = "LockID"
#}