output "function_name" {
  description = "For `aws logs tail /aws/lambda/<name>` and the Lambda console."
  value       = aws_lambda_function.api.function_name
}

output "url" {
  value = "https://${var.domain_name}"
}
