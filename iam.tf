data "aws_iam_role" "github_actions_role" {
  name = "GithubActionsRole"
}

resource "aws_iam_role" "github_actions_role" {
  # Only create if the data source doesn't return a role
  count = length(data.aws_iam_role.github_actions_role) == 0 ? 1 : 0
  name  = "GithubActionsRole"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::${var.account_id}:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.amazonaws.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.amazonaws.com:sub": "repo:${var.github_org}/${var.github_repo}:ref:refs/heads/*"
        }
      }
    }
  ]
}
EOF
}
