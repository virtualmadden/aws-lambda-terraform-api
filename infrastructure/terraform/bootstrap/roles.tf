data "aws_iam_policy_document" "trust" {
  for_each = {
    # Applies only ever come from main.
    deploy = "repo:${var.github_repository}:ref:refs/heads/main"
    # Pull requests from the repo's own branches; forks get no OIDC token.
    plan = "repo:${var.github_repository}:pull_request"
  }

  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [local.github_oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = [each.value]
    }
  }
}

resource "aws_iam_role" "github" {
  for_each = data.aws_iam_policy_document.trust

  name                 = "${substr(local.repo_slug, 0, 50)}-${each.key}"
  description          = "GitHub Actions ${each.key} for ${var.github_repository}"
  assume_role_policy   = each.value.json
  max_session_duration = 3600
}

# Plans read everything, change nothing, and run with -lock=false.
resource "aws_iam_role_policy_attachment" "plan" {
  role       = aws_iam_role.github["plan"].name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

locals {
  account_id = data.aws_caller_identity.current.account_id
  log_groups = ["/aws/lambda/${local.api_name}", "/aws/apigateway/${local.api_name}"]
}

# Deploys manage only this API: its state, its function and the function's role, its log
# groups, its zone's records, and the API Gateway and ACM resources in its region.
data "aws_iam_policy_document" "deploy" {
  statement {
    sid       = "State"
    actions   = ["s3:ListBucket", "s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = [aws_s3_bucket.state.arn, "${aws_s3_bucket.state.arn}/*"]
  }

  statement {
    sid       = "Function"
    actions   = ["lambda:*"]
    resources = ["arn:aws:lambda:${var.aws_region}:${local.account_id}:function:${local.api_name}"]
  }

  statement {
    sid = "FunctionRole"
    actions = [
      "iam:CreateRole",
      "iam:DeleteRole",
      "iam:GetRole",
      "iam:UpdateRole",
      "iam:UpdateAssumeRolePolicy",
      "iam:TagRole",
      "iam:UntagRole",
      "iam:ListRoleTags",
      "iam:PutRolePolicy",
      "iam:GetRolePolicy",
      "iam:DeleteRolePolicy",
      "iam:ListRolePolicies",
      "iam:ListAttachedRolePolicies",
      "iam:ListInstanceProfilesForRole",
    ]
    resources = ["arn:aws:iam::${local.account_id}:role/${local.api_name}-lambda"]
  }

  statement {
    sid       = "PassFunctionRole"
    actions   = ["iam:PassRole"]
    resources = ["arn:aws:iam::${local.account_id}:role/${local.api_name}-lambda"]

    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["lambda.amazonaws.com"]
    }
  }

  statement {
    sid     = "LogGroups"
    actions = ["logs:*"]
    resources = flatten([
      for group in local.log_groups : [
        "arn:aws:logs:${var.aws_region}:${local.account_id}:log-group:${group}",
        "arn:aws:logs:${var.aws_region}:${local.account_id}:log-group:${group}:*",
      ]
    ])
  }

  # Listing log groups, and the log delivery calls API Gateway makes as the caller when a
  # stage turns on access logging, have no resource-level scoping.
  statement {
    sid = "LogDelivery"
    actions = [
      "logs:DescribeLogGroups",
      "logs:CreateLogDelivery",
      "logs:GetLogDelivery",
      "logs:UpdateLogDelivery",
      "logs:DeleteLogDelivery",
      "logs:ListLogDeliveries",
      "logs:PutResourcePolicy",
      "logs:DescribeResourcePolicies",
    ]
    resources = ["*"]
  }

  # The API, stage, domain name and mapping are created by this stack, so their IDs
  # aren't known up front; this stays within the region.
  statement {
    sid       = "ApiGateway"
    actions   = ["apigateway:*"]
    resources = ["arn:aws:apigateway:${var.aws_region}::/*"]
  }

  statement {
    sid       = "Certificates"
    actions   = ["acm:*"]
    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "aws:RequestedRegion"
      values   = [var.aws_region]
    }
  }

  statement {
    sid       = "Records"
    actions   = ["route53:ChangeResourceRecordSets"]
    resources = [data.aws_route53_zone.api.arn]
  }

  statement {
    sid       = "Route53Read"
    actions   = ["route53:Get*", "route53:List*"]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "deploy" {
  name   = "deploy-api"
  role   = aws_iam_role.github["deploy"].id
  policy = data.aws_iam_policy_document.deploy.json
}
