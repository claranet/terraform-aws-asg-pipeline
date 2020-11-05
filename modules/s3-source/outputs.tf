output "creds" {
  description = "Credentials for uploading to this bucket."
  value = {
    aws_access_key_id     = join("", aws_iam_access_key.this[*].id)
    aws_secret_access_key = join("", aws_iam_access_key.this[*].secret)
  }
}

output "location" {
  description = "Location details for uploading to this bucket."
  value = {
    bucket = aws_s3_bucket.this.id
    key    = var.key
  }
}
