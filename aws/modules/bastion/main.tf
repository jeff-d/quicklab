# This file is part of QuickLab, which creates simple, monitored labs.
# https://github.com/jeff-d/quicklab
#
# SPDX-FileCopyrightText: © 2023 Jeffrey M. Deininger <9385180+jeff-d@users.noreply.github.com>
# SPDX-License-Identifier: AGPL-3.0-or-later


# EC2 Instance
resource "aws_instance" "this" {
  ami                  = data.aws_ssm_parameter.al23.value # data.aws_ami.amazon_linux_2.id
  instance_type        = "t3.micro"
  availability_zone    = var.bastion_az     # aws_subnet.public_a.availability_zone
  subnet_id            = var.bastion_subnet # aws_subnet.public_a.id
  hibernation          = true
  iam_instance_profile = aws_iam_instance_profile.bastion.name
  key_name             = var.ssh_key.key_name
  monitoring           = true # enable CloudWatch detailed monitoring
  vpc_security_group_ids = [
    aws_security_group.bastion.id,
    var.sg_remoteaccess_ssh,
    var.sg_remoteaccess_rdp
  ]
  metadata_options {
    http_endpoint          = "enabled"  # should be enabled by default and safe to omit, but testing suggests otherwise
    http_tokens            = "required" # disables IMDS v1
    instance_metadata_tags = "enabled"
  }

  root_block_device {
    # will be destroyed on instance termination
    encrypted   = true
    volume_type = "gp3"
    volume_size = 10 # GiB
  }

  user_data                   = var.monitoring == "sumo" ? data.cloudinit_config.sumo.rendered : ""
  user_data_replace_on_change = true

  tags = {
    Component = local.module
    Name      = "${var.prefix}-${var.uid}-bastion"
    CreatedBy = var.creator
    Prefix    = var.prefix
  }
}
data "cloudinit_config" "sumo" {
  gzip          = true
  base64_encode = true

  part {
    filename     = "base.tftpl"
    content_type = "text/cloud-config"
    merge_type   = local.cloud_init_merge_type
    content = templatefile(
      "${path.module}/cloud-init/base.tftpl",
      {
        TIMEZONE = "UTC"
      }
    )
  }

  part {
    filename     = "otelcol-sumo.tftpl"
    content_type = "text/cloud-config"
    merge_type   = local.cloud_init_merge_type
    content = templatefile(
      "${path.module}/cloud-init/otelcol-sumo.tftpl",
      {
        PREFIX      = var.prefix
        UID         = var.uid
        REGION      = data.aws_region.current.name
        PROJECT     = var.project
        ENVIRONMENT = var.environment
        CLOBBER     = true
        EPHEMERAL   = true
      }
    )
  }

  part {
    filename     = "log-bootstrap.tftpl"
    content_type = "text/cloud-config"
    merge_type   = local.cloud_init_merge_type
    content = templatefile(
      "${path.module}/cloud-init/log-bootstrap.tftpl",
      {
        PREFIX = var.prefix
        UID    = var.uid
        REGION = data.aws_region.current.name
      }
    )
  }

  part {
    filename     = "log-system.tftpl"
    content_type = "text/cloud-config"
    merge_type   = local.cloud_init_merge_type
    content = templatefile(
      "${path.module}/cloud-init/log-system.tftpl",
      {
        PREFIX = var.prefix
        UID    = var.uid
        REGION = data.aws_region.current.name
      }
    )
  }

  part {
    filename     = "metrics-host.tftpl"
    content_type = "text/cloud-config"
    merge_type   = local.cloud_init_merge_type
    content = templatefile(
      "${path.module}/cloud-init/metrics-host.tftpl",
      {

      }
    )
  }
}


# Security Group: Bastion
resource "aws_security_group" "bastion" {
  name        = "ec2-bastion"
  description = "default-sg for bastion"
  vpc_id      = var.vpc.id

  tags = {
    Component = local.module
    Name      = "${var.vpc.tags_all.Name}-sg-bastion"
    CreatedBy = var.creator
  }
}
resource "aws_security_group_rule" "allow_icmp_in" {
  type              = "ingress"
  description       = "allow ICMP in from VPC"
  from_port         = -1
  to_port           = -1
  protocol          = "icmp"
  cidr_blocks       = [var.vpc.cidr_block]
  security_group_id = aws_security_group.bastion.id
}


# Security Group Rules
resource "aws_security_group_rule" "allow_all_out" {
  for_each = {
    "bastion" = "${aws_security_group.bastion.id}"
  }
  type        = "egress"
  description = "Allow all traffic out (IPv4)" # recreates default AWS SG outbound rule that terraform implicitly deletes
  from_port   = 0
  to_port     = 0
  protocol    = "-1"
  cidr_blocks = ["0.0.0.0/0"]
  # ipv6_cidr_blocks  = ["::/0"]
  security_group_id = each.value
}


# Cloudwatch Log Group
resource "aws_cloudwatch_log_group" "bastion" {
  name_prefix = "${var.prefix}/${var.uid}/${local.module}/access-log/"

  skip_destroy      = false # set to true to preserve log group during terraform destroy
  retention_in_days = 30

  tags = {
    Component = local.module
    Name      = "${var.prefix}-${var.uid}-${local.module}-lg-access-logs"
    CreatedBy = var.creator
  }
}
resource "aws_cloudwatch_log_metric_filter" "SSHMetricFilter" {
  name           = "SSHMetricFilter"
  pattern        = "ON FROM USER PWD"
  log_group_name = aws_cloudwatch_log_group.bastion.name

  metric_transformation {
    name      = "SSHCommandCount"
    namespace = "${var.prefix}/${var.uid}/${aws_instance.this.tags_all.Name}"
    value     = "1"
  }
}


# IAM Host Profile
resource "aws_iam_instance_profile" "bastion" {
  name = "${var.prefix}-${var.uid}-bastion-instance-profile"
  role = aws_iam_role.bastion.name

  tags = {
    Component = local.module
    CreatedBy = var.creator
  }
}
resource "aws_iam_role" "bastion" {
  name                = "${var.prefix}-${var.uid}-bastion-instance-role"
  assume_role_policy  = data.aws_iam_policy_document.bastion_trust.json
  managed_policy_arns = [data.aws_iam_policy.AmazonSSMManagedInstanceCore.arn, data.aws_iam_policy.CloudWatchAgentServerPolicy.arn, aws_iam_policy.bastion_policy.arn]

  tags = {
    Component = local.module
    CreatedBy = var.creator
  }

}
resource "time_sleep" "bastion_role" {
  depends_on      = [aws_iam_role.bastion]
  create_duration = "15s" # aaccommodates a delay in role creation which can render invalid the principal reference in module.sumo["xxyy"].data.aws_iam_policy_document.secret_resource_policy
}
data "aws_iam_policy_document" "bastion_trust" {
  statement {
    sid     = ""
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}
resource "aws_iam_policy" "bastion_policy" {
  name   = "${var.prefix}-${var.uid}-bastion-policy"
  policy = data.aws_iam_policy_document.bastion_permission.json

  tags = {
    Component = local.module
    CreatedBy = var.creator
  }
}
data "aws_iam_policy_document" "bastion_permission" {
  # Write To CloudWatch Logs
  statement {
    sid    = "WriteToCloudWatchLogs"
    effect = "Allow"
    actions = [
      "logs:CreateLogStream",
      "logs:GetLogEvents",
      "logs:PutLogEvents",
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams",
      "logs:PutRetentionPolicy",
      "logs:PutMetricFilter",
      "logs:CreateLogGroup",
      "logs:CreateLogDelivery", # https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/AWS-logs-and-resource-policy.html
      "logs:PutResourcePolicy",
      "logs:DescribeResourcePolicies"
    ]
    resources = ["${aws_cloudwatch_log_group.bastion.arn}:*"]
  }

  # Retrieve Sumo Installation Token from Secrets Manager
  statement {
    sid       = "RetreiveSumoToken"
    effect    = "Allow"
    resources = ["arn:${data.aws_partition.current.partition}:secretsmanager:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:secret:${var.prefix}-${var.uid}-sumo-token*"]
    actions   = ["secretsmanager:GetSecretValue"]
  }

  # Describe Self
  statement {
    sid       = "DescribeSelf"
    effect    = "Allow"
    resources = ["*"]
    actions   = ["ec2:describeInstances"]
  }
}


# SSH Config
resource "local_file" "ssh_config" {
  content = templatefile(
    "${path.module}/ssh-config.tftpl",
    {
      PREFIX       = var.prefix
      UID          = var.uid
      HOSTNAME     = aws_instance.this.public_dns
      IDENTITYFILE = var.ssh_key_filename
    }
  )
  filename        = pathexpand("~/.ssh/${var.prefix}-${var.uid}-ssh-config")
  file_permission = "0600"
}
