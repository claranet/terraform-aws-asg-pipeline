# Create a KMS key to use for the pipeline artifacts.
# This must be shared with the target accounts so they
# can decrypt the artifacts too.

data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "this" {
  statement {
    sid = "EnableIAMUserPermissions"
    actions = [
      "kms:*",
    ]
    resources = [
      "*",
    ]
    principals {
      type        = "AWS"
      identifiers = [data.aws_caller_identity.current.account_id]
    }
  }

  statement {
    sid = "AllowAccessFromTargetAccounts"
    actions = [
      "kms:DescribeKey",
      "kms:GenerateDataKey*",
      "kms:Encrypt",
      "kms:ReEncrypt*",
      "kms:Decrypt"
    ]
    resources = [
      "*",
    ]
    principals {
      type        = "AWS"
      identifiers = [for target in var.targets : target.assume_role.arn]
    }
  }
}

resource "aws_kms_key" "this" {
  deletion_window_in_days = 7
  description             = var.name
  policy                  = data.aws_iam_policy_document.this.json
}
