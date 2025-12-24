# This lambda will trigger redeployment if the code in the deployed lambda is modified.
resource "aws_lambda_function" "code_sha256" {
  filename      = data.archive_file.lambda_zip.output_path
  function_name = "code_sha256-trigger-test"
  role          = aws_iam_role.lambda.arn
  handler       = "lambda.handler"
  runtime       = "python3.14"

  # THIS IS THE ARGUMENT THAT WILL READ THE HASH OF THE DEPLOYED CODE.
  # If there is a difference between the deployed code's hash and the hash of
  # the lambda_function.zip, it will trigger an update.
  code_sha256 = data.archive_file.lambda_zip.output_base64sha256
}


# This lambda will NOT trigger redeployment if the code in the deployed lambda is modified.
resource "aws_lambda_function" "source_code_hash" {
  filename      = data.archive_file.lambda_zip.output_path
  function_name = "source_code_hash-trigger-test"
  role          = aws_iam_role.lambda.arn
  handler       = "lambda.handler"
  runtime       = "python3.14"

  # This argument ONLY reads the hash stored in the terraform.tfstate.
  # It is completely unaware of any modifications to the deployed code.
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
}

# Create the zip file used to deploy the lambda function code
data "archive_file" "lambda_zip" {
  type        = "zip"
  output_path = "${path.root}/lambda_function.zip"

  source {
    content  = file("${path.root}/lambda/lambda.py")
    filename = "lambda.py"
  }
}

# Create the IAM role for the lambda. We could have used any dummy role for this experiment.
resource "aws_iam_role" "lambda" {
  name_prefix = "trigger-test-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}
