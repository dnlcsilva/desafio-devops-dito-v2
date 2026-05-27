locals {
  oidc_provider = replace(var.oidc_provider_url, "https://", "")
}

resource "aws_iam_role" "workload" {
  name = var.name
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = var.oidc_provider_arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${local.oidc_provider}:aud" = "sts.amazonaws.com"
          "${local.oidc_provider}:sub" = "system:serviceaccount:${var.namespace}:${var.service_account_name}"
        }
      }
    }]
  })
  tags = var.tags
}

resource "aws_iam_policy" "read_secret" {
  name        = "${var.name}-read-secret"
  description = "Allow workload to read only the required application secret."
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
      Resource = var.secret_arn
    }]
  })
  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "read_secret" {
  role       = aws_iam_role.workload.name
  policy_arn = aws_iam_policy.read_secret.arn
}
