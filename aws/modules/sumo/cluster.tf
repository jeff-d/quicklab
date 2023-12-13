# This file is part of QuickLab, which creates simple, monitored labs.
# https://github.com/jeff-d/quicklab
#
# SPDX-FileCopyrightText: © 2023 Jeffrey M. Deininger <9385180+jeff-d@users.noreply.github.com>
# SPDX-License-Identifier: AGPL-3.0-or-later


resource "sumologic_http_source" "rum_traces" {
  for_each     = var.create_cluster ? toset(["cluster"]) : toset([])
  name         = "cluster-rum-traces"
  description  = "A source to receive RUM Traces for apps deployed to the QuickLab kubernetes cluster"
  category     = "${var.prefix}/${var.uid}/aws/${data.aws_region.current.name}/cluster/app/rum"
  collector_id = sumologic_collector.this.id
  content_type = "Rum"
}

#====================
# Amazon EKS Control Plane Logs
#====================
# ref: https://help.sumologic.com/docs/integrations/amazon-aws/eks-control-plane/


# Sumo Logic App
# (required to visualize the logs)
resource "null_resource" "sumo_app_eks" {
  for_each   = var.create_cluster ? toset(["cluster"]) : toset([])
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
          UUID             = local.app.eks.uuid
          NAME             = local.app.eks.name
          DESCRIPTION      = substr(local.app.eks.description, 0, 255)
          FOLDER           = sumologic_folder.this.id
          DATASOURCEVALUES = jsonencode({ ekslogsource = "_sourceCategory = ${sumologic_http_source.eks["cluster"].category}" })
          # LOGSRC      = sumologic_http_source.eks["cluster"].category
        }
      )
    )
  }
}


# Sumo Org Resources
# (required to receive the logs)
resource "sumologic_http_source" "eks" {
  for_each     = var.create_cluster ? toset(["cluster"]) : toset([])
  name         = "cluster-eks-control-plane-logs"
  description  = "Flow Logs for ${var.vpc.tags_all.Name}"
  category     = "${var.prefix}/${var.uid}/aws/${data.aws_region.current.name}/cluster/controlplane"
  collector_id = sumologic_collector.this.id
  default_date_formats {
    format  = "epoch"
    locator = "\\s(\\d{10,13})\\s\\d{10,13}" # original from sumo docs: \s(\d{10,13})\s\d{10,13}
  }
}


# AWS Resources
# (required to send the logs)
# CW Logs Lambda Function (SumoCWLogsLambda)
resource "aws_lambda_function" "eks" {
  for_each      = var.create_cluster ? toset(["cluster"]) : toset([])
  function_name = "${var.prefix}-${var.uid}-SumoCWLogsLambda-eks"
  handler       = "cloudwatchlogs_lambda.handler"
  runtime       = "nodejs16.x"
  memory_size   = 128
  environment {
    variables = {
      SUMO_ENDPOINT     = sumologic_http_source.eks["cluster"].url
      LOG_FORMAT        = "VPC-JSON"
      INCLUDE_LOG_INFO  = true
      LOG_STREAM_PREFIX = ""
    }
  }

  role      = aws_iam_role.lambda_role_eks["cluster"].arn
  s3_bucket = "appdevzipfiles-${data.aws_region.current.name}" # will work for most global Regions
  s3_key    = "cloudwatchlogs-with-dlq.zip"
  timeout   = 300
  dead_letter_config {
    target_arn = aws_sqs_queue.dlq_eks["cluster"].arn
  }

  depends_on = [
    aws_cloudwatch_log_group.lambda_eks,
    aws_iam_role.lambda_role_eks,
    # aws_sqs_queue.dlq_eks,
    sumologic_http_source.eks
  ]

  tags = {
    Component = local.module
    Name      = "${var.prefix}-${var.uid}-function-SumoCWLogsLambda-eks"
  }
}
resource "aws_cloudwatch_log_group" "lambda_eks" {
  for_each          = var.create_cluster ? toset(["cluster"]) : toset([])
  name              = "/aws/lambda/${var.prefix}-${var.uid}-SumoCWLogsLambda-eks"
  retention_in_days = 7

  tags = {
    Component = local.module
    Name      = "${var.prefix}-${var.uid}-lg-SumoCWLogsLambda-eks"
  }
}
# CW Lambda Execution Role (SumoCWLambdaExecutionRole)
resource "aws_iam_role" "lambda_role_eks" {
  for_each            = var.create_cluster ? toset(["cluster"]) : toset([])
  name                = "${var.prefix}-${var.uid}-SumoCWLambdaExecutionRole-eks"
  assume_role_policy  = data.aws_iam_policy_document.lambda_trust_eks.json
  managed_policy_arns = [aws_iam_policy.lambda_role_policy_eks["cluster"].arn]

  tags = {
    Component = local.module
    CreatedBy = var.creator
  }
}
data "aws_iam_policy_document" "lambda_trust_eks" {
  statement {
    sid     = ""
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}
resource "aws_iam_policy" "lambda_role_policy_eks" {
  for_each = var.create_cluster ? toset(["cluster"]) : toset([])
  name     = "${var.prefix}-${var.uid}-SumoCWLambdaExecutionRole-policy-eks"
  path     = "/"
  policy   = data.aws_iam_policy_document.lambda_permissions_eks.json
  tags = {
    Component = local.module
    CreatedBy = var.creator
  }
}
data "aws_iam_policy_document" "lambda_permissions_eks" {
  statement {
    sid       = "SQSCreateLogsRolePolicy"
    effect    = "Allow"
    resources = ["arn:${data.aws_partition.current.partition}:sqs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:${var.prefix}-${var.uid}-SumoCWDeadLetterQueue-eks"]

    actions = [
      "sqs:DeleteMessage",
      "sqs:GetQueueUrl",
      "sqs:ListQueues",
      "sqs:ChangeMessageVisibility",
      "sqs:SendMessageBatch",
      "sqs:ReceiveMessage",
      "sqs:SendMessage",
      "sqs:GetQueueAttributes",
      "sqs:ListQueueTags",
      "sqs:ListDeadLetterSourceQueues",
      "sqs:DeleteMessageBatch",
      "sqs:PurgeQueue",
      "sqs:DeleteQueue",
      "sqs:CreateQueue",
      "sqs:ChangeMessageVisibilityBatch",
      "sqs:SetQueueAttributes",
    ]
  }
  statement {
    sid       = "CloudWatchCreateLogsRolePolicy"
    effect    = "Allow"
    resources = ["arn:${data.aws_partition.current.partition}:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:*"]

    actions = [
      # "logs:CreateLogGroup", # intentionally omitted to prevent late-publish log group resurrection
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogStreams",
    ]
  }
  statement {
    sid       = "InvokeLambdaRolePolicy"
    effect    = "Allow"
    resources = ["arn:${data.aws_partition.current.partition}:lambda:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:function:${var.prefix}-${var.uid}-SumoCWLogsLambda-eks"]
    actions   = ["lambda:InvokeFunction"]
  }
}
# CW Lambda Permission (SumoCWLambdaPermission)
resource "aws_lambda_permission" "invoke_eks" {
  for_each       = var.create_cluster ? toset(["cluster"]) : toset([])
  statement_id   = "${var.prefix}-${var.uid}-SumoCWLambdaPermission-eks"
  action         = "lambda:InvokeFunction"
  function_name  = aws_lambda_function.eks["cluster"].function_name
  principal      = "logs.${data.aws_region.current.name}.amazonaws.com"
  source_account = data.aws_caller_identity.current.account_id
}
# CW Log Subscription Filter (SumoCWLogSubsriptionFilter)
resource "aws_cloudwatch_log_subscription_filter" "eks" {
  for_each        = var.create_cluster ? toset(["cluster"]) : toset([])
  name            = "${var.prefix}-${var.uid}-SumoCWLogSubsriptionFilter-eks"
  log_group_name  = "/aws/eks/${var.prefix}-${var.uid}-cluster/cluster" # log group where EKS Control Plane Logs are stored, defined in "Cluster" Module
  filter_pattern  = ""                                                  # includes all
  destination_arn = aws_lambda_function.eks["cluster"].arn
  # distribution    = "Random" # enable to override default distribution by log stream

  depends_on = [aws_lambda_permission.invoke_eks]
}
# CW Dead Letter Queue (SumoCWDeadLetterQueue)
resource "aws_sqs_queue" "dlq_eks" {
  for_each = var.create_cluster ? toset(["cluster"]) : toset([])
  name     = "${var.prefix}-${var.uid}-SumoCWDeadLetterQueue-eks"

  tags = {
    Component = local.module
    Name      = "${var.prefix}-${var.uid}-queue-SumoCWDeadLetterQueue-eks"
  }
}
# CW Process DLQ Schedule Rule (SumoCWProcessDLQScheduleRule)
resource "aws_cloudwatch_event_rule" "dlq_eks" {
  for_each            = var.create_cluster ? toset(["cluster"]) : toset([])
  name                = "${var.prefix}-${var.uid}-SumoCWProcessDLQScheduleRule-eks"
  description         = "Events rule for Cron"
  schedule_expression = "rate(5 minutes)"

  tags = {
    Component = local.module
    Name      = "${var.prefix}-${var.uid}-eventrule-SumoCWProcessDLQScheduleRule-eks"
  }
}
resource "aws_cloudwatch_event_target" "dlq_eks" {
  for_each = var.create_cluster ? toset(["cluster"]) : toset([])
  rule     = aws_cloudwatch_event_rule.dlq_eks["cluster"].name
  arn      = aws_lambda_function.dlq_eks["cluster"].arn
}
# CW Process DLQ Lambda Function (SumoCWProcessDLQLambda)
resource "aws_lambda_function" "dlq_eks" {
  for_each      = var.create_cluster ? toset(["cluster"]) : toset([])
  function_name = "${var.prefix}-${var.uid}-SumoCWProcessDLQLambda-eks"
  s3_bucket     = "appdevzipfiles-${data.aws_region.current.name}" # will work for most global Regions
  s3_key        = "cloudwatchlogs-with-dlq.zip"
  role          = aws_iam_role.lambda_role_eks["cluster"].arn
  timeout       = 300
  handler       = "DLQProcessor.handler"
  dead_letter_config {
    target_arn = aws_sqs_queue.dlq_eks["cluster"].arn
  }
  runtime     = "nodejs16.x"
  memory_size = 128
  environment {
    variables = {
      SUMO_ENDPOINT     = sumologic_http_source.eks["cluster"].url
      TASK_QUEUE_URL    = aws_sqs_queue.dlq_eks["cluster"].name
      NUM_OF_WORKERS    = 4
      LOG_FORMAT        = "VPC-JSON"
      INCLUDE_LOG_INFO  = true
      LOG_STREAM_PREFIX = ""
    }
  }
  depends_on = [
    aws_cloudwatch_log_group.dlq_eks,
    aws_iam_role.lambda_role_eks,
    aws_sqs_queue.dlq_eks
  ]

  tags = {
    Component = local.module
    Name      = "${var.prefix}-${var.uid}-function-SumoCWProcessDLQLambda-eks"
  }
}
#CW Events Invoke Lambda Permission (SumoCWEventsInvokeLambdaPermission)
resource "aws_lambda_permission" "invoke_dlq_eks" {
  for_each      = var.create_cluster ? toset(["cluster"]) : toset([])
  statement_id  = "${var.prefix}-${var.uid}-SumoCWEventsInvokeLambdaPermission-eks"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.dlq_eks["cluster"].function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.dlq_eks["cluster"].arn
}
resource "aws_cloudwatch_log_group" "dlq_eks" {
  for_each          = var.create_cluster ? toset(["cluster"]) : toset([])
  name              = "/aws/lambda/${var.prefix}-${var.uid}-SumoCWProcessDLQLambda-eks"
  retention_in_days = 7

  tags = {
    Component = local.module
    Name      = "${var.prefix}-${var.uid}-lg-SumoCWProcessDLQLambda-eks"
  }
}
# CW Email SNS Topic (SumoCWEmailSNSTopic)
resource "aws_sns_topic" "eks" {
  for_each = var.create_cluster ? toset(["cluster"]) : toset([])
  name     = "${var.prefix}-${var.uid}-SumoCWEmailSNSTopic-eks"

  tags = {
    Component = local.module
    Name      = "${var.prefix}-${var.uid}-topic-SumoCWEmailSNSTopic-eks"
  }
}
resource "aws_sns_topic_subscription" "dlq_eks" {
  for_each  = var.create_cluster ? toset(["cluster"]) : toset([])
  topic_arn = aws_sns_topic.eks["cluster"].arn
  protocol  = "sqs"
  endpoint  = aws_sqs_queue.dlq_eks["cluster"].arn
}
# CW Spillover Alarm (SumoCWSpilloverAlarm)
resource "aws_cloudwatch_metric_alarm" "spillover-eks" {
  for_each          = var.create_cluster ? toset(["cluster"]) : toset([])
  alarm_name        = "${var.prefix}-${var.uid}-SumoCWSpilloverAlarm-eks"
  alarm_description = "Notify via email if number of messages in DeadLetterQueue exceeds threshold"
  alarm_actions     = [aws_sns_topic.eks["cluster"].arn]

  comparison_operator = "GreaterThanThreshold"
  dimensions = {
    name  = "QueueName"
    value = aws_sqs_queue.dlq_eks["cluster"].name
  }
  evaluation_periods = 1
  metric_name        = "ApproximateNumberOfMessagesVisible"
  namespace          = "AWS/SQS"
  period             = 3600
  statistic          = "Sum"
  threshold          = 100000


  depends_on = [
    aws_sns_topic.eks
  ]

  tags = {
    Component = local.module
    Name      = "${var.prefix}-${var.uid}-alarm-SumoCWSpilloverAlarm-eks"
  }

}
