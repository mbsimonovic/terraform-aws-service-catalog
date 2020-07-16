# Example website

This folder contains a simple "Hello, World" static website. It is used solely to demonstrate that S3/CloudFront are
working. When you go to deploy your real static content, you should delete this folder and the `aws_s3_bucket_object`
resource in `../main.tf` that uploads the `index.html` file in this folder!