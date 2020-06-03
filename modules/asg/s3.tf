# This S3 bucket will contain app releases.
# The pipeline will put app releases here during deployments.

resource "aws_s3_bucket" "app" {
  bucket_prefix = "${var.name}-app-"
  acl           = "private"

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
