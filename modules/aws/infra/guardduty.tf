
data "aws_vpc_endpoint_service" "guardduty" {
  service_type = "Interface"
  filter {
    name   = "service-name"
    values = ["com.amazonaws.${var.region}.guardduty-data"]
  }
}

resource "aws_vpc_endpoint" "eks_vpc_guardduty" {
  vpc_id            = local.network[0].indico_vpc_id
  service_name      = data.aws_vpc_endpoint_service.guardduty.service_name
  vpc_endpoint_type = "Interface"

  policy = data.aws_iam_policy_document.eks_vpc_guardduty.json

  security_group_ids  = [aws_security_group.eks_vpc_endpoint_guardduty.id]
  subnet_ids          = local.network[0].public_subnet_ids
  private_dns_enabled = true
}

resource "aws_security_group" "eks_vpc_endpoint_guardduty" {
  name_prefix = "${var.label}-vpc-endpoint-guardduty-sg-"
  description = "Security Group used by VPC Endpoints."
  vpc_id      = local.network[0].indico_vpc_id

  tags = {
    "Name"             = "${var.label}-vpc-endpoint-guardduty-sg-"
    "GuardDutyManaged" = "false"
  }

  lifecycle {
    create_before_destroy = true
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

data "aws_iam_policy_document" "eks_vpc_guardduty" {
  statement {
    actions = ["*"]

    effect = "Allow"

    resources = ["*"]

    principals {
      type        = "AWS"
      identifiers = ["*"]
    }
  }

  statement {
    actions = ["*"]

    effect = "Deny"

    resources = ["*"]

    principals {
      type        = "AWS"
      identifiers = ["*"]
    }

    condition {
      test     = "StringNotEquals"
      variable = "aws:PrincipalAccount"

      values = [data.aws_caller_identity.current.account_id]
    }
  }
}
resource "aws_eks_addon" "guardduty" {
  depends_on = [
    module.cluster
  ]
  count = var.eks_addon_version_guardduty != null ? 1 : 0


  cluster_name      = var.label
  addon_name        = "aws-guardduty-agent"
  addon_version     = "v1.2.0-eksbuild.1"
  resolve_conflicts = "OVERWRITE"

  preserve = true

  tags = {
    "eks_addon" = "guardduty"
  }
}
