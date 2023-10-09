# This file is part of QuickLab, which creates simple, monitored labs.
# https://github.com/jeff-d/quicklab
#
# SPDX-FileCopyrightText: © 2023 Jeffrey M. Deininger <9385180+jeff-d@users.noreply.github.com>
# SPDX-License-Identifier: AGPL-3.0-or-later


#====================
# AWS Cost Explorer
#====================
# ref: # https://help.sumologic.com/docs/integrations/amazon-aws/cost-explorer/


# Sumo Logic App
# (required to visualize the logs)
resource "null_resource" "sumo_app_costexplorer" {
  depends_on = [sumologic_cloud_to_cloud_source.costexplorer, sumologic_folder.this]

  triggers = {
    new_quicklab_folder = sumologic_folder.this.id
    # always_run          = "${timestamp()}"
  }

  provisioner "local-exec" {
    command = tostring(
      templatefile(
        "${path.module}/app-install.tftpl",
        {
          BASEURL          = local.baseurl
          BASICAUTH        = base64encode(local.basicauth)
          UUID             = local.app.costexplorer.uuid
          NAME             = local.app.costexplorer.name
          DESCRIPTION      = substr(local.app.costexplorer.description, 0, 255)
          FOLDER           = sumologic_folder.this.id
          DATASOURCEVALUES = jsonencode({})
          # LOGSRC      = "${var.prefix}/${var.uid}/aws/${data.aws_region.current.name}/costexplorer"
        }
      )
    )
  }
}


# Sumo Org Resources
# (required to receive the logs)
resource "sumologic_cloud_to_cloud_source" "costexplorer" {
  collector_id = sumologic_collector.this.id
  schema_ref = {
    type = "AWS Cost Explorer"
  }

  # fields.account is a friendly aws account name, specified in aws.auto.tfvars
  config = jsonencode(
    {
      "accessID" : "${aws_iam_access_key.costexplorer.id}",
      "name" : "costexplorer-${data.aws_region.current.name}",
      "description" : "collects Cost Explorer logs for ${data.aws_region.current.name}",
      "regions" : ["${data.aws_region.current.name}"],
      "fields" : {
        "account" : var.aws_account_name != null ? "${var.aws_account_name}" : "${data.aws_caller_identity.current.account_id}"
      },
      "accessKey" : "${aws_iam_access_key.costexplorer.secret}",
      "granularity" : ["daily", "monthly"],
      "costMetrics" : ["AmortizedCost"],
      "category" : "${var.prefix}/${var.uid}/aws/${data.aws_region.current.name}/costexplorer"
    }
  )
  depends_on = [
    aws_iam_access_key.costexplorer,
    sumologic_collector.this
  ]
}
resource "sumologic_field" "costexplorer" {
  for_each = toset(local.app.costexplorer.fields)

  field_name = each.key
  data_type  = "String"
  state      = "Enabled"
}
resource "sumologic_field_extraction_rule" "costexplorer" {
  name             = "AWS Cost Explorer"
  scope            = "account = * region CostUsd CostType StartDate EndDate MetricType Granularity Service LinkedAccount"
  parse_expression = <<-EOT
    json "LinkedAccount"
    | if (LinkedAccount = "${data.aws_caller_identity.current.account_id}",  "${var.aws_account_name}", LinkedAccount ) as LinkedAccount
    | if (LinkedAccount = "123456789",  "securityprod", LinkedAccount ) as LinkedAccount
    | if (LinkedAccount = "987654321",  "infraprod", LinkedAccount ) as LinkedAccount
  EOT
  enabled          = true

  depends_on = [
    sumologic_field.costexplorer["account"],
    sumologic_field.costexplorer["linkedaccount"]
  ]

}


# AWS Resources
# (required to send the logs)
resource "aws_iam_access_key" "costexplorer" {
  user = aws_iam_user.costexplorer.name
}
resource "aws_iam_user" "costexplorer" {
  name = "${var.prefix}-${var.uid}-sumo-costexplorer"
  path = "/"
}
data "aws_iam_policy_document" "costexplorer" {
  statement {
    effect = "Allow"
    actions = [
      "ce:Describe*",
      "ce:Get*",
      "ce:List*",
      "ec2:DescribeRegions"
    ]
    resources = ["*"]
  }
}
resource "aws_iam_user_policy" "costexplorer" {
  name   = "${var.prefix}-${var.uid}-sumo-costexplorer-policy"
  user   = aws_iam_user.costexplorer.name
  policy = data.aws_iam_policy_document.costexplorer.json
}
