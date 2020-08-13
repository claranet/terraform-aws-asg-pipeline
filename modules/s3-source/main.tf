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
  name = coalesce(var.user_name, aws_s3_bucket.this.id)
}

data "aws_iam_policy_document" "this" {
  statement {
    actions   = ["s3:PutObject*"]
    resources = ["${aws_s3_bucket.this.arn}/${var.key}"]
  }
}

resource "aws_iam_user_policy" "this" {
  user   = aws_iam_user.this.name
  policy = data.aws_iam_policy_document.this.json
}

resource "aws_iam_access_key" "this" {
  user = aws_iam_user.this.name
}
