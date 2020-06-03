# Add a bucket policy to the Terraform remote state backend,
# allowing the pipeline account to read the remote state file.

data "aws_s3_bucket" "terraform_backend" {
  bucket = "${var.project_name}-${var.aws_account_id}-tfstate"
}

data "aws_iam_policy_document" "terraform_backend" {
  statement {
    sid       = "AllowAccessFromPipelineAccount"
    actions   = ["s3:GetObject"]
    resources = ["${data.aws_s3_bucket.terraform_backend.arn}/*"]
    principals {
      type        = "AWS"
      identifiers = [var.pipeline_aws_account_id]
    }
  }
}

resource "aws_s3_bucket_policy" "terraform_backend" {
  bucket = data.aws_s3_bucket.terraform_backend.bucket
  policy = data.aws_iam_policy_document.terraform_backend.json
}
