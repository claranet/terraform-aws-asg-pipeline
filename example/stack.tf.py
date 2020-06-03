from pretf.api import block
from pretf.aws import provider_aws
from pretf.aws import terraform_backend_s3


def pretf_blocks(var):
    yield block("variable", "aws_account_id", {"type": "string"})
    yield block("variable", "aws_profile", {"type": "string"})
    yield block("variable", "aws_region", {"default": "eu-west-1"})
    yield block("variable", "aws_version", {"default": "2.65.0"})
    yield block("variable", "project_name", {"default": "terraform-aws-asg-codepipeline"})
    yield block("variable", "terraform_stack", {"type": "string"})
    yield block("variable", "terraform_version", {"default": "0.12.26"})

    yield provider_aws(
        allowed_account_ids=[var.aws_account_id],
        profile=var.aws_profile,
        region=var.aws_region,
        version=var.aws_version,
    )

    yield terraform_backend_s3(
        bucket=f"{var.project_name}-{var.aws_account_id}-tfstate",
        dynamodb_table=f"{var.project_name}-{var.aws_account_id}-tfstate",
        key=f"{var.terraform_stack}/terraform.tfstate",
        profile=var.aws_profile,
        region=var.aws_region,
    )

    yield block("terraform", {"required_version": var.terraform_version})
