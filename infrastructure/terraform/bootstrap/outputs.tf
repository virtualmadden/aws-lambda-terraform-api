output "state_bucket" {
  value = aws_s3_bucket.state.id
}

output "deploy_role_arn" {
  value = aws_iam_role.github["deploy"].arn
}

output "plan_role_arn" {
  value = aws_iam_role.github["plan"].arn
}

output "github_variables" {
  description = "Run these to configure the repo's GitHub Actions."
  value = join("\n", compact([
    "gh variable set AWS_REGION --repo ${var.github_repository} --body ${var.aws_region}",
    "gh variable set TF_STATE_BUCKET --repo ${var.github_repository} --body ${aws_s3_bucket.state.id}",
    "gh variable set AWS_DEPLOY_ROLE_ARN --repo ${var.github_repository} --body ${aws_iam_role.github["deploy"].arn}",
    "gh variable set AWS_PLAN_ROLE_ARN --repo ${var.github_repository} --body ${aws_iam_role.github["plan"].arn}",
    "gh variable set DOMAIN_NAME --repo ${var.github_repository} --body ${var.domain_name}",
    var.hosted_zone_name == null ? "" : "gh variable set HOSTED_ZONE_NAME --repo ${var.github_repository} --body ${var.hosted_zone_name}",
  ]))
}
