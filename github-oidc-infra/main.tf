terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
  backend "s3" {
    bucket         = "lucasrod16-tfstate"
    key            = "github-oidc/tfstate"
    region         = "us-east-2"
    dynamodb_table = "lucasrod16-tfstate"
  }
}

provider "aws" {
  region = "us-east-2"
}

locals {
  name = "github-oidc"
  tags = {
    Category = local.name
  }
}

################################################################################
# GitHub OIDC Provider
# Note: This is one per AWS account
################################################################################

module "iam_github_oidc_provider" {
  source = "github.com/terraform-aws-modules/terraform-aws-iam/modules/iam-github-oidc-provider?ref=e803e25ce20a6ebd5579e0896f657fa739f6f03e" # v5.52.2
  tags   = local.tags
}

################################################################################
# GitHub OIDC Role
################################################################################

module "iam_github_oidc_role" {
  source = "github.com/terraform-aws-modules/terraform-aws-iam/modules/iam-github-oidc-role?ref=e803e25ce20a6ebd5579e0896f657fa739f6f03e" # v5.52.2
  name   = local.name
  subjects = [
    "repo:lucasrod16/self-hosted-llm:*",
  ]
  policies = {
    EC2        = "arn:aws:iam::aws:policy/AmazonEC2FullAccess"
    S3ReadOnly = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
  }
  tags = local.tags
}

output "role_arn" {
  value = module.iam_github_oidc_role.arn
}
