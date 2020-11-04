"""
This file is used by Pretf to generate stack.tf.json.

The reason for using Pretf is that our AWS profiles have MFA prompts,
which is not supported by Terraform. We're using multiple AWS profiles
in these examples to manage resources in multiple AWS accounts, so we
can't use simple environment variables for AWS credentials. Pretf solves
this and also manages the S3 backend resources.

"""

from pretf.api import block
from pretf.aws import provider_aws, terraform_backend_s3


def pretf_blocks(var):
    yield block("variable", "aws_region", {"default": "eu-west-1"})
    yield block("variable", "aws_version", {"default": "3.1.0"})
    yield block("variable", "terraform_version", {"default": "0.12.26"})

    yield provider_aws(
        alias="nonprod",
        profile="bashton-playgroundRW",
        region=var.aws_region,
        version=var.aws_version,
    )

    yield provider_aws(
        alias="prod",
        profile="bashton-secondplaygroundRW",
        region=var.aws_region,
        version=var.aws_version,
    )

    yield provider_aws(
        alias="management",
        profile="claranetuk-thirdplaygroundRW",
        region=var.aws_region,
        version=var.aws_version,
    )

    yield terraform_backend_s3(
        bucket="terraform-aws-asg-codepipeline-tfstate",
        dynamodb_table="terraform-aws-asg-codepipeline-tfstate",
        key="full.tfstate",
        profile="claranetuk-thirdplaygroundRW",
        region=var.aws_region,
    )

    yield block("terraform", {"required_version": var.terraform_version})
