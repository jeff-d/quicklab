# This file is part of QuickLab, which creates simple, monitored labs.
# https://github.com/jeff-d/quicklab
#
# SPDX-FileCopyrightText: © 2023 Jeffrey M. Deininger <9385180+jeff-d@users.noreply.github.com>
# SPDX-License-Identifier: AGPL-3.0-or-later


resource "sumologic_token" "this" {
  for_each    = var.create_bastion ? toset(["bastion"]) : toset([])
  name        = "${var.prefix}-${var.uid}-${local.module}-token"
  description = "A token for QuickLab ${var.uid} ${local.module}"
  status      = "Active"
  type        = "CollectorRegistration"
}

# Sumo Logic Fields sent via otelcol-sumo
resource "sumologic_field" "otelcol" {
  for_each = var.create_bastion && var.create_bastion_otelcol_fields ? toset(local.fields.otelcol) : toset([])

  field_name = each.key
  data_type  = "String"
  state      = "Enabled"
}
resource "sumologic_field" "system" {
  for_each = var.create_bastion && var.create_bastion_otelsystem_fields ? toset(local.fields.resourcedetection.system) : toset([])

  field_name = each.key
  data_type  = "String"
  state      = "Enabled"
}
resource "sumologic_field" "ec2" {
  for_each = var.create_bastion && var.create_bastion_otelec2_fields ? toset(local.fields.resourcedetection.ec2) : toset([])

  field_name = each.key
  data_type  = "String"
  state      = "Enabled"
}

# Secrets Manager Secret
resource "aws_secretsmanager_secret" "sumo_token" {
  for_each                = var.create_bastion ? toset(["bastion"]) : toset([])
  name                    = "${var.prefix}-${var.uid}-sumo-token"
  recovery_window_in_days = 0

  tags = {
    Component = local.module
    Name      = "${var.prefix}-${var.uid}-${local.module}-secret-installation-token"
  }
}
resource "aws_secretsmanager_secret_version" "sumo_token" {
  for_each      = var.create_bastion ? toset(["bastion"]) : toset([])
  secret_id     = aws_secretsmanager_secret.sumo_token["bastion"].id
  secret_string = sumologic_token.this["bastion"].encoded_token_and_url
}
resource "aws_secretsmanager_secret_policy" "sumo_token" {
  for_each   = var.create_bastion ? toset(["bastion"]) : toset([])
  secret_arn = aws_secretsmanager_secret.sumo_token["bastion"].arn
  policy     = data.aws_iam_policy_document.secret_resource_policy.json

}
data "aws_iam_policy_document" "secret_resource_policy" {
  statement {
    sid    = "EnableBastionToReadTheSecret"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = ["arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:role/${var.prefix}-${var.uid}-bastion-instance-role"]
    }

    actions   = ["secretsmanager:GetSecretValue"]
    resources = ["arn:${data.aws_partition.current.partition}:secretsmanager:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:secret:${var.prefix}-${var.uid}-sumo-token*"]
  }

  depends_on = [
    aws_secretsmanager_secret.sumo_token
  ]
}
