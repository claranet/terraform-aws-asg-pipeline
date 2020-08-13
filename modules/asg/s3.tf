# This S3 bucket will contain app releases.
# The pipeline will put app releases here during deployments.

resource "aws_s3_bucket" "app" {
  acl           = "private"
  bucket_prefix = "${var.name}-app-"
  force_destroy = true

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }

  versioning {
    enabled = true
  }
}
