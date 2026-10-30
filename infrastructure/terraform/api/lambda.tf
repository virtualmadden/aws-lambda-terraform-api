# `yarn build` bundles the handler into dist/; Terraform zips it and redeploys whenever
# the zip's hash changes.
data "archive_file" "function" {
  type             = "zip"
  source_dir       = "${path.module}/../../../dist"
  output_path      = "${path.module}/.terraform/function.zip"
  output_file_mode = "0644"
}

# Created before the function so Lambda logs here, with retention, rather than to a
# group it creates itself that keeps logs forever.
resource "aws_cloudwatch_log_group" "function" {
  name              = "/aws/lambda/${local.name}"
  retention_in_days = var.log_retention_days
}

data "aws_iam_policy_document" "function_trust" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "function" {
  name               = "${local.name}-lambda"
  assume_role_policy = data.aws_iam_policy_document.function_trust.json
}

# Only writing its own logs. Grant anything else the handler calls here.
data "aws_iam_policy_document" "function" {
  statement {
    actions   = ["logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["${aws_cloudwatch_log_group.function.arn}:*"]
  }
}

resource "aws_iam_role_policy" "function" {
  name   = "function"
  role   = aws_iam_role.function.id
  policy = data.aws_iam_policy_document.function.json
}

resource "aws_lambda_function" "api" {
  function_name    = local.name
  role             = aws_iam_role.function.arn
  runtime          = "nodejs24.x"
  architectures    = ["arm64"]
  handler          = "index.handler"
  filename         = data.archive_file.function.output_path
  source_code_hash = data.archive_file.function.output_base64sha256
  memory_size      = var.memory_size
  timeout          = var.timeout

  environment {
    variables = {
      # Stack traces point at src/, not the bundle.
      NODE_OPTIONS = "--enable-source-maps"
    }
  }

  logging_config {
    log_format = "JSON"
    log_group  = aws_cloudwatch_log_group.function.name
  }

  depends_on = [aws_iam_role_policy.function]
}
