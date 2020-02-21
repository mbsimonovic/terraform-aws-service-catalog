data "aws_kms_key" "dedicated_test_key" {
  // If you get an error like "AccessDeniedException: The specified KMS key does not exist or is not
  // allowed to be used with LogGroup, you need to check if the key has the right permissions.
  //  principals {
  //      type = "Service"
  //      identifiers = [
  //        "delivery.logs.amazonaws.com",
  //        "logs.${aws-region}.amazonaws.com",
  //      ]
  //    }

  key_id = "alias/dedicated-test-key"
}

