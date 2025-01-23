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
    EC2      = "arn:aws:iam::aws:policy/AmazonEC2FullAccess"
    S3       = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
    DynamoDB = module.iam_policy_tf_state_locking.arn
  }
  tags = local.tags
}


#########################################
# IAM policy
#########################################

data "aws_iam_policy_document" "dynamodb_policy" {
  statement {
    sid = "AllowDynamoDBAccess"
    actions = [
      "dynamodb:DescribeTable",
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:DeleteItem"
    ]
    resources = ["arn:aws:dynamodb:*:*:table/lucasrod16-tfstate"]
  }
}

module "iam_policy_tf_state_locking" {
  source      = "github.com/terraform-aws-modules/terraform-aws-iam/modules/iam-policy?ref=e803e25ce20a6ebd5579e0896f657fa739f6f03e" # v5.52.2
  name        = "dynamodb-tf-state-locking"
  description = "Policy to give terraform permissions to perform state locking using DynamoDB"
  policy      = data.aws_iam_policy_document.dynamodb_policy.json
  tags        = local.tags
}

data "aws_iam_policy_document" "s3_policy" {
  statement {
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = ["arn:aws:s3:::lucasrod16-tfstate"]
  }

  statement {
    effect  = "Allow"
    actions = ["s3:GetObject", "s3:PutObject"]
    resources = [
      "arn:aws:s3:::lucasrod16-tfstate/github-oidc/tfstate",
      "arn:aws:s3:::lucasrod16-tfstate/github-oidc/tfstate.tflock"
    ]
  }
}

module "iam_policy_tf_state" {
  source      = "github.com/terraform-aws-modules/terraform-aws-iam/modules/iam-policy?ref=e803e25ce20a6ebd5579e0896f657fa739f6f03e" # v5.52.2
  name        = "s3-tf-state"
  description = "Policy to give terraform permissions to store state in S3"
  policy      = data.aws_iam_policy_document.s3_policy.json
  tags        = local.tags
}

output "role_arn" {
  value = module.iam_github_oidc_role.arn
}
