terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "5.39.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

data "aws_caller_identity" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  environment = "Sandbox"
  team_name = "Sion"
  service_name = "Blue"
}

locals {
  default_tags = {
    Environment = local.environment
    Team = local.team_name
    Service = local.service_name
  }
}
