data "aws_iam_role" "github_actions_role" {
  name = "GithubActionsRole"
}
resource "aws_iam_openid_connect_provider" "GitHub" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["1c58a3a8518e8759bf075b76b750d4f2df264fcd"]
}

resource "aws_iam_role" "GitHub_Actions" {
  count = length(data.aws_iam_role.github_actions_role) == 0 ? 1 : 0
  name  = "GitHub_Actions"

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
                    "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
                },
                "StringLike": {
                    "token.actions.githubusercontent.com:sub": "repo:${var.github_org}/${var.github_repo}:ref:refs/heads/*"
                }
            }
        }
    ]
}
EOF
}

locals {
  policies = [
    "arn:aws:iam::aws:policy/AmazonEC2FullAccess",
    "arn:aws:iam::aws:policy/AmazonRoute53FullAccess",
    "arn:aws:iam::aws:policy/AmazonS3FullAccess",
    "arn:aws:iam::aws:policy/IAMFullAccess",
    "arn:aws:iam::aws:policy/AmazonVPCFullAccess",
    "arn:aws:iam::aws:policy/AmazonSQSFullAccess",
    "arn:aws:iam::aws:policy/AmazonEventBridgeFullAccess",
  ]
}

resource "aws_iam_role_policy_attachment" "github_actions_policies" {
  for_each   = length(data.aws_iam_role.github_actions_role) == 0 ? toset(local.policies) : toset([])
  role       = aws_iam_role.GitHub_Actions[0].name
  policy_arn = each.key
}
