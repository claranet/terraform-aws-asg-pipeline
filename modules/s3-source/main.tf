resource "aws_s3_bucket" "this" {
  acl           = "private"
  bucket        = var.bucket
  bucket_prefix = var.bucket_prefix
  force_destroy = var.force_destroy

  versioning {
    enabled = true
  }
}

resource "aws_iam_user" "this" {
  count = var.user_name != null ? 1 : 0
  name  = var.user_name
}

data "aws_iam_policy_document" "this" {
  count = var.user_name != null ? 1 : 0
  statement {
    actions   = ["s3:PutObject*"]
    resources = ["${aws_s3_bucket.this.arn}/${var.key}"]
  }
}

resource "aws_iam_user_policy" "this" {
  count  = var.user_name != null ? 1 : 0
  user   = aws_iam_user.this[0].name
  policy = data.aws_iam_policy_document.this[0].json
}

resource "aws_iam_access_key" "this" {
  count = var.user_name != null ? 1 : 0
  user  = aws_iam_user.this[0].name
}
