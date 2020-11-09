data "aws_kms_key" "default_aws_s3_key" {
  key_id = "alias/aws/s3"
}
