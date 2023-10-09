# AWS Marketplace Addons
resource "aws_iam_openid_connect_provider" "cluster" {
  client_id_list  = ["sts.${data.aws_partition.current.dns_suffix}"]
  thumbprint_list = data.tls_certificate.cluster.certificates[*].sha1_fingerprint
  url             = data.tls_certificate.cluster.url

  tags = {
    Component = local.module
    CreatedBy = var.creator
    Name      = "${aws_eks_cluster.this.name}-eks-irsa"
  }

  #TODO: solve inconsistent final plan with merged tags
  /*
  tags = merge(
    {
      Name      = "${aws_eks_cluster.this.name}-eks-irsa"
      createdby = var.creator
    }
  )
  */
}
resource "aws_eks_addon" "_" {
  for_each                    = { for addon in local.addons : addon.name => addon }
  cluster_name                = aws_eks_cluster.this.name
  addon_name                  = each.value.name
  addon_version               = each.value.version
  service_account_role_arn    = aws_iam_role.irsa.arn
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "PRESERVE"
  preserve                    = true

  tags = {
    Component = local.module
    createdby = var.creator
  }

  depends_on = [
    aws_eks_node_group.this
  ]

}
resource "aws_iam_role" "irsa" {
  assume_role_policy = data.aws_iam_policy_document.irsa_trust_policy.json
  name               = "${var.prefix}-${var.uid}-${local.module}-irsa-role"

  tags = {
    Module                    = local.module
    createdby                 = var.creator
    "ServiceAccountName"      = "eks-irsa"
    "ServiceAccountNameSpace" = "kube-system"
  }

  depends_on = []

}
data "aws_iam_policy_document" "irsa_trust_policy" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringLike"
      variable = "${replace(aws_iam_openid_connect_provider.cluster.url, "https://", "")}:sub"
      values = [
        "system:serviceaccount:kube-system:ebs-csi-controller-sa",
        "system:serviceaccount:*:${var.prefix}-${var.uid}-aws-load-balancer-controller",
        "system:serviceaccount:*:${var.prefix}-${var.uid}-eks-irsa",
        "system:serviceaccount:default:default"
      ]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.cluster.url, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }

    principals {
      identifiers = [aws_iam_openid_connect_provider.cluster.arn]
      type        = "Federated"
    }
  }
}
resource "aws_iam_role_policy_attachment" "addon" {
  for_each   = { for k, v in local.policies : k => v }
  policy_arn = each.value
  role       = aws_iam_role.irsa.name
}


# AWS Load Balancer Controller
data "http" "lbc_iam_policy" {
  url = "https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/main/docs/install/iam_policy.json"

  request_headers = {
    Accept = "application/json"
  }
}
resource "aws_iam_policy" "lbc" {
  name        = "${var.prefix}-${var.uid}-AWSLoadBalancerControllerIAMPolicy"
  path        = "/"
  description = "AWS Load Balancer Controller IAM Policy. Ref: https://github.com/kubernetes-sigs/aws-load-balancer-controller/blob/main/docs/install/iam_policy.json"
  policy      = data.http.lbc_iam_policy.response_body
}
resource "aws_iam_role_policy_attachment" "lbc" {
  policy_arn = aws_iam_policy.lbc.arn
  role       = aws_iam_role.irsa.name
}
resource "null_resource" "lbc_sa" {
  provisioner "local-exec" {
    command = tostring(
      templatefile(
        "${path.module}/aws-lbc-sa.tftpl",
        {
          CLUSTERNAME        = aws_eks_cluster.this.name
          SERVICEACCOUNTNAME = "${var.prefix}-${var.uid}-aws-load-balancer-controller"
          IRSA_ARN           = aws_iam_role.irsa.arn
        }
      )
    )
  }

  triggers = {
    new_cluster    = aws_eks_cluster.this.id
    new_node_group = aws_eks_node_group.this.id
  }

  depends_on = [
    aws_eks_node_group.this,
    aws_iam_role.irsa
  ]

}
resource "null_resource" "lbc_helm" {

  provisioner "local-exec" {
    command = tostring(
      templatefile(
        "${path.module}/aws-lbc-helm.tftpl",
        {
          CLUSTERNAME        = aws_eks_cluster.this.name
          SERVICEACCOUNTNAME = "${var.prefix}-${var.uid}-aws-load-balancer-controller"
          MODULE             = local.module
          LABID              = var.uid
          CREATEDBY          = "${var.prefix}-${var.uid}-aws-load-balancer-controller"
          BUCKET             = aws_s3_bucket.lblogs.id
        }
      )
    )
  }

  triggers = {
    new_cluster    = aws_eks_cluster.this.id
    new_node_group = aws_eks_node_group.this.id
    # always_run     = "${timestamp()}"
  }

  depends_on = [
    aws_eks_node_group.this,
    null_resource.lbc_sa,
    aws_s3_bucket.lblogs
  ]
}
resource "aws_s3_bucket" "lblogs" {
  bucket_prefix = "${var.prefix}-${var.uid}-lb-${data.aws_region.current.name}-"
  force_destroy = true # removes bucket objects upon bucket destroy

  tags = {
    Component = local.module
    CreatedBy = var.creator
  }
}
