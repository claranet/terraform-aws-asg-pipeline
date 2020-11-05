variable "bucket" {
  description = "The name of the S3 bucket to create."
  type        = string
  default     = null
}

variable "bucket_prefix" {
  description = "The name prefix of the S3 bucket to create."
  type        = string
  default     = null
}

variable "force_destroy" {
  description = "Allow 'terraform destroy' to delete objects when deleting the bucket."
  type        = bool
  default     = false
}

variable "key" {
  description = "The key of the S3 object. A user will be created with permission to upload to this location. The pipeline should use this location as its source."
  type        = string
  default     = "app.zip"
}

variable "user_name" {
  description = "The name of the IAM user to create. If not provided, no user is created."
  type        = string
  default     = null
}
