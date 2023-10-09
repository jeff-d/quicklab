# This file is part of QuickLab, which creates simple, monitored labs.
# https://github.com/jeff-d/quicklab
#
# SPDX-FileCopyrightText: © 2023 Jeffrey M. Deininger <9385180+jeff-d@users.noreply.github.com>
# SPDX-License-Identifier: AGPL-3.0-or-later


#====================
# AWS CloudTrail
#====================
# ref: # https://help.sumologic.com/docs/integrations/amazon-aws/cloudtrail/


# Sumo Logic App
# (required to visualize the logs)
resource "null_resource" "sumo_app_cloudtrail" {
  depends_on = [sumologic_folder.this]

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
          UUID             = local.app.cloudtrail.uuid
          NAME             = local.app.cloudtrail.name
          DESCRIPTION      = substr(local.app.cloudtrail.description, 0, 255)
          FOLDER           = sumologic_folder.this.id
          DATASOURCEVALUES = jsonencode({ logsrc = "_sourceCategory = ${sumologic_cloudtrail_source.this.category}" })
          # LOGSRC      = sumologic_cloudtrail_source.this.category
        }
      )
    )
  }
}


# Sumo Org Resources
# (required to receive the logs)
resource "sumologic_cloudtrail_source" "this" {
  name          = aws_cloudtrail.this.name
  description   = "collects logs for the QuickLab trail"
  category      = "${var.prefix}/${var.uid}/aws/${data.aws_region.current.name}/cloudtrail"
  content_type  = "AwsCloudTrailBucket"
  scan_interval = 300000
  paused        = false
  collector_id  = sumologic_collector.this.id

  authentication {
    type     = "AWSRoleBasedAuthentication"
    role_arn = aws_iam_role.sumo.arn
  }

  path {
    type            = "S3BucketPathExpression"
    bucket_name     = aws_s3_bucket.trail.bucket
    path_expression = "AWSLogs/*"
  }

  depends_on = [
    time_sleep.sumo_role,
    sumologic_collector.this
  ]
}
resource "sumologic_http_source" "aws_admins" {
  name                         = "cloudtrail-aws-admins"
  description                  = "Privileged AWS User IDs, uploaded via CSV, used with the CloudTrail App. Reference: https://help.sumologic.com/docs/integrations/amazon-aws/cloudtrail/#enable-sumo-logic-to-track-aws-admin-activity"
  category                     = "admin_users"
  collector_id                 = sumologic_collector.this.id
  automatic_date_parsing       = false
  multiline_processing_enabled = false # one username per CSV line
  use_autoline_matching        = false
}
resource "local_file" "aws_admins" {
  filename        = "${path.module}/admin_users.csv"
  file_permission = "0600"
  content         = join("\n", [for u in local.aws_admins : format("%s", u)])
}
resource "null_resource" "upload_aws_admins" {

  depends_on = [sumologic_cloudtrail_source.this, sumologic_http_source.aws_admins]

  triggers = {
    updated_admins_list = local_file.aws_admins.id
  }

  provisioner "local-exec" {
    command = <<-EOT
    curl -s -X POST '${sumologic_http_source.aws_admins.url}' -T '${local_file.aws_admins.filename}'
    EOT
  }
}
resource "sumologic_lookup_table" "aws_admins" {
  name = "aws-admins"
  fields {
    field_name = "admin_users"
    field_type = "string"
  }
  ttl               = 15
  primary_keys      = ["admin_users"]
  parent_folder_id  = sumologic_folder.this.id
  size_limit_action = "DeleteOldData"
  description       = "QuickLab AWS Admins"
}
resource "sumologic_content" "load_aws_admins" {
  parent_id = sumologic_folder.this.id
  config = jsonencode(
    {
      "type" : "SavedSearchWithScheduleSyncDefinition",
      "name" : "update-aws-admin-list",
      "description" : "Runs every 15Minutes with timerange of 30m and updates hosted shared file of AWS admins at /shared/aws/cloudtrail/admin_users, referenced by the AWS CloudTrail App",
      "search" : {
        "queryText" : "_sourceCategory=admin_users | parse \"*\" as admin_user | count as count by admin_user | fields -count | save /shared/aws/cloudtrail/admin_users",
        "defaultTimeRange" : "-10m",
        "byReceiptTime" : false,
        "viewName" : "",
        "viewStartTime" : "1970-01-01T00:00:00Z",
        "queryParameters" : [],
        "parsingMode" : "Manual"
      },
      "searchSchedule" : null
    }
  )

  depends_on = [
    null_resource.upload_aws_admins,
    sumologic_lookup_table.aws_admins
  ]
}


# AWS Resources
# (required to send the logs)
# Trail - scoped to this region
resource "aws_cloudtrail" "this" {
  name                          = "${var.prefix}-${var.uid}-trail-${data.aws_region.current.name}"
  s3_bucket_name                = aws_s3_bucket.trail.id
  include_global_service_events = true
  is_multi_region_trail         = false
  is_organization_trail         = false

  insight_selector {
    insight_type = "ApiCallRateInsight"
  }

  insight_selector {
    insight_type = "ApiErrorRateInsight"
  }

  tags = {
    Component = local.module
    Name      = "${var.prefix}-${var.uid}-trail-${data.aws_region.current.name}"
    CreatedBy = var.creator
  }

  depends_on = [
    aws_s3_bucket.trail,
    aws_s3_bucket_policy.trail
  ]

}
# Bucket - store the logs
resource "aws_s3_bucket" "trail" {
  bucket_prefix = "${var.prefix}-${var.uid}-cloudtrail-${data.aws_region.current.name}-"
  force_destroy = true # removes bucket objects upon bucket destroy

  depends_on = [aws_sns_topic.trail] # ref: https://repost.aws/knowledge-center/unable-validate-destination-s3

  tags = {
    Name      = "${var.prefix}-${var.uid}-${local.module}-cloudtrail"
    Component = local.module
    CreatedBy = var.creator
  }
}
# Bucket Policy (enables CT to write to Bucket)
resource "aws_s3_bucket_policy" "trail" {
  bucket = aws_s3_bucket.trail.id
  policy = data.aws_iam_policy_document.trail_bucket_policy.json
}
data "aws_iam_policy_document" "trail_bucket_policy" {
  statement {
    sid    = "AWSCloudTrailAclCheck"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }

    actions   = ["s3:GetBucketAcl"]
    resources = [aws_s3_bucket.trail.arn]
  }

  statement {
    sid    = "AWSCloudTrailWrite"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }

    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.trail.arn}/AWSLogs/${data.aws_caller_identity.current.account_id}/*"]

    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }
  }
}
# S3 Bucket Notification (alerts SNS when new )
resource "aws_s3_bucket_notification" "sumo" {
  bucket = aws_s3_bucket.trail.id

  topic {
    topic_arn     = aws_sns_topic.trail.arn
    events        = ["s3:ObjectCreated:*"]
    filter_suffix = ".log"
  }
}
data "aws_iam_policy_document" "s3_sns" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["s3.amazonaws.com"]
    }

    actions   = ["SNS:Publish"]
    resources = ["arn:aws:sns:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:${var.prefix}-${var.uid}-cloudtrail-topic"]

    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = ["arn:${data.aws_partition.current.partition}:s3:::${var.prefix}-${var.uid}-cloudtrail-${data.aws_region.current.name}-*"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }

  }
}
# SNS Topic (receives notice of new trail logs published to S3)
resource "aws_sns_topic" "trail" {
  name   = "${var.prefix}-${var.uid}-cloudtrail-topic"
  policy = data.aws_iam_policy_document.s3_sns.json
  tags = {
    Component = local.module
    Name      = "${var.prefix}-${var.uid}-topic-trail-${data.aws_region.current.name}"
    CreatedBy = var.creator
  }
}
# SNS Subscription (notifies Sumo to pull the new log from S3)
resource "aws_sns_topic_subscription" "trail_notify" {
  topic_arn = aws_sns_topic.trail.arn
  protocol  = "https"
  endpoint  = sumologic_cloudtrail_source.this.url

}
# Sumo IAM Role (allows Sumo Read on Resources)
resource "aws_iam_role" "sumo" {
  name                = "${var.prefix}-${var.uid}-SumoRole"
  assume_role_policy  = data.aws_iam_policy_document.sumo_trust.json
  managed_policy_arns = [aws_iam_policy.sumo_role_policy.arn]
  tags = {
    Component = local.module
    CreatedBy = var.creator
  }
}
resource "time_sleep" "sumo_role" {
  depends_on      = [aws_iam_role.sumo]
  create_duration = "15s" # aaccommodates slight delay in Sumo Logic assuming the new IAM role for the first time
}
data "aws_iam_policy_document" "sumo_trust" {
  statement {
    sid     = ""
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    condition {
      test     = "StringEquals"
      variable = "sts:ExternalId"
      values   = ["${var.sumo_env}:${var.sumo_org}"]
    }

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::926226587429:root"]
    }
  }

}
resource "aws_iam_policy" "sumo_role_policy" {
  name   = "${var.prefix}-${var.uid}-SumoRole-policy"
  path   = "/"
  policy = data.aws_iam_policy_document.sumo_policy.json
  tags = {
    Component = local.module
    CreatedBy = var.creator
  }
}
data "aws_iam_policy_document" "sumo_policy" {
  statement {
    sid       = "SumoMetadataTagsSource"
    effect    = "Allow"
    resources = ["*"]
    actions   = ["tag:GetResources"]
  }
  statement {
    sid    = "SumoS3Source"
    effect = "Allow"

    resources = [
      "arn:${data.aws_partition.current.partition}:s3:::${aws_s3_bucket.trail.bucket}",
      "arn:${data.aws_partition.current.partition}:s3:::${aws_s3_bucket.trail.bucket}/*"
    ]

    actions = [
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:ListBucketVersions",
      "s3:ListBucket",
    ]
  }
  statement {
    sid       = "SumoCwMetricsSource"
    effect    = "Allow"
    resources = ["*"]

    actions = [
      "cloudwatch:ListMetrics",
      "cloudwatch:GetMetricStatistics",
      "tag:GetResources",
    ]
  }
}
