#====================
# Amazon VPC Flow Logs
#====================
# ref: https://help.sumologic.com/docs/integrations/amazon-aws/vpc-flow-logs/

# Sumo Logic App
# (required to visualize the logs)
resource "null_resource" "sumo_app_flowlogs" {
  for_each   = var.create_network ? toset(["network"]) : toset([])
  depends_on = [sumologic_http_source.flowlogs["network"], sumologic_folder.this] # depends_on has no effect if the dependency is created conditionally via for_each

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
          UUID             = local.app.flowlogs.uuid
          NAME             = local.app.flowlogs.name
          DESCRIPTION      = substr(local.app.flowlogs.description, 0, 255)
          FOLDER           = sumologic_folder.this.id
          DATASOURCEVALUES = jsonencode({ vpcFlowLogs = join("", ["_sourceCategory = ", try("${sumologic_http_source.flowlogs["network"].category}", "")]) })
          # LOGSRC           = sumologic_http_source.flowlogs["network"].category
        }
      )
    )
  }
}


# Sumo Org Resources
# (required to receive the logs)
resource "sumologic_http_source" "flowlogs" {
  for_each     = var.create_network ? toset(["network"]) : toset([])
  name         = "${var.vpc.tags_all.Name}-flowlogs"
  description  = "Flow Logs for ${var.vpc.tags_all.Name}"
  category     = "${var.prefix}/${var.uid}/aws/${data.aws_region.current.name}/network/flowlogs"
  collector_id = sumologic_collector.this.id
  default_date_formats {
    format  = "epoch"
    locator = "\\s(\\d{10,13})\\s\\d{10,13}" # original from sumo docs: \s(\d{10,13})\s\d{10,13}
  }
}
resource "sumologic_field_extraction_rule" "flowlogs" {
  for_each         = var.create_network ? toset(["network"]) : toset([])
  name             = "VPC Flow Logs"
  scope            = "_sourceCategory=${var.prefix}/${var.uid}/aws/*/network/flowlogs"
  parse_expression = <<-EOT
    json "message" as _rawvpc nodrop
    | if (_raw matches "{*", _rawvpc,_raw) as message
    | parse field=message "* * * * * * * * * * * * * *" as version,accountID,interfaceID,src_ip,dest_ip,src_port,dest_port,Protocol,Packets,bytes,StartSample,EndSample,Action,status
    | fields interfaceid,src_ip,dest_ip,src_port,dest_port,protocol,packets,bytes,action,status
  EOT
  enabled          = true
}


# AWS Resources
# (required to send the logs)
# CW Logs Lambda Function (SumoCWLogsLambda)
resource "aws_lambda_function" "flowlogs" {
  for_each      = var.create_network ? toset(["network"]) : toset([])
  function_name = "${var.prefix}-${var.uid}-SumoCWLogsLambda-flowlogs"
  handler       = "cloudwatchlogs_lambda.handler"
  runtime       = "nodejs16.x"
  memory_size   = 128
  environment {
    variables = {
      SUMO_ENDPOINT               = sumologic_http_source.flowlogs["network"].url
      LOG_FORMAT                  = "VPC-JSON"
      INCLUDE_LOG_INFO            = true
      LOG_STREAM_PREFIX           = ""
      INCLUDE_SECURITY_GROUP_INFO = true
      # VPC_CIDR_PREFIX = 
    }
  }

  role      = aws_iam_role.lambda_role_flowlogs["network"].arn
  s3_bucket = "appdevzipfiles-${data.aws_region.current.name}" # will work for most global Regions
  s3_key    = "cloudwatchlogs-with-dlq.zip"
  timeout   = 300
  dead_letter_config {
    target_arn = aws_sqs_queue.dlq_flowlogs["network"].arn
  }

  depends_on = [
    aws_cloudwatch_log_group.lambda_flowlogs,
    aws_iam_role.lambda_role_flowlogs,
    aws_sqs_queue.dlq_flowlogs,
    sumologic_http_source.flowlogs
  ]

  tags = {
    Component = local.module
    Name      = "${var.prefix}-${var.uid}-function-SumoCWLogsLambda-flowlogs"
  }
}
resource "aws_cloudwatch_log_group" "lambda_flowlogs" {
  for_each          = var.create_network ? toset(["network"]) : toset([])
  name              = "/aws/lambda/${var.prefix}-${var.uid}-SumoCWLogsLambda-flowlogs"
  retention_in_days = 7

  tags = {
    Component = local.module
    Name      = "${var.prefix}-${var.uid}-lg-SumoCWLogsLambda-flowlogs"
  }
}
# CW Lambda Execution Role (SumoCWLambdaExecutionRole)
resource "aws_iam_role" "lambda_role_flowlogs" {
  for_each            = var.create_network ? toset(["network"]) : toset([])
  name                = "${var.prefix}-${var.uid}-SumoCWLambdaExecutionRole-flowlogs"
  assume_role_policy  = data.aws_iam_policy_document.lambda_trust_flowlogs.json
  managed_policy_arns = [aws_iam_policy.lambda_role_policy_flowlogs["network"].arn]

  tags = {
    Component = local.module
    CreatedBy = var.creator
  }
}
data "aws_iam_policy_document" "lambda_trust_flowlogs" {
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
resource "aws_iam_policy" "lambda_role_policy_flowlogs" {
  for_each = var.create_network ? toset(["network"]) : toset([])
  name     = "${var.prefix}-${var.uid}-SumoCWLambdaExecutionRole-policy-flowlogs"
  path     = "/"
  policy   = data.aws_iam_policy_document.lambda_permissions_flowlogs.json
  tags = {
    Component = local.module
    CreatedBy = var.creator
  }
}
data "aws_iam_policy_document" "lambda_permissions_flowlogs" {
  statement {
    sid       = "SQSCreateLogsRolePolicy"
    effect    = "Allow"
    resources = ["arn:${data.aws_partition.current.partition}:sqs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:${var.prefix}-${var.uid}-SumoCWDeadLetterQueue-flowlogs"]

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
    resources = ["arn:${data.aws_partition.current.partition}:lambda:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:function:${var.prefix}-${var.uid}-SumoCWLogsLambda-flowlogs"]
    actions   = ["lambda:InvokeFunction"]
  }
  statement {
    sid       = "DescribeENILambdaPerms"
    effect    = "Allow"
    resources = ["*"]
    actions   = ["ec2:DescribeNetworkInterfaces"]
  }
}
# CW Lambda Permission (SumoCWLambdaPermission)
resource "aws_lambda_permission" "invoke_flowlogs" {
  for_each       = var.create_network ? toset(["network"]) : toset([])
  statement_id   = "${var.prefix}-${var.uid}-SumoCWLambdaPermission-flowlogs"
  action         = "lambda:InvokeFunction"
  function_name  = aws_lambda_function.flowlogs["network"].function_name
  principal      = "logs.${data.aws_region.current.name}.amazonaws.com"
  source_account = data.aws_caller_identity.current.account_id
}
#CW Events Invoke Lambda Permission (SumoCWEventsInvokeLambdaPermission)
resource "aws_lambda_permission" "invoke_dlq_flowlogs" {
  for_each      = var.create_network ? toset(["network"]) : toset([])
  statement_id  = "${var.prefix}-${var.uid}-SumoCWEventsInvokeLambdaPermission-flowlogs"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.dlq_flowlogs["network"].function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.dlq_flowlogs["network"].arn
}
# CW Log Subscription Filter (SumoCWLogSubsriptionFilter)
resource "aws_cloudwatch_log_subscription_filter" "flowlogs" {
  for_each        = var.create_network ? toset(["network"]) : toset([])
  name            = "${var.prefix}-${var.uid}-SumoCWLogSubsriptionFilter-flowlogs"
  log_group_name  = var.cwl_flowlogs # log group where VPC Flow Logs are stored, passed from "Network" Module
  filter_pattern  = ""               # includes all
  destination_arn = aws_lambda_function.flowlogs["network"].arn
  # distribution    = "Random" # enable to override default distribution by log stream

  depends_on = [aws_lambda_permission.invoke_flowlogs]
}
# CW Dead Letter Queue (SumoCWDeadLetterQueue)
resource "aws_sqs_queue" "dlq_flowlogs" {
  for_each = var.create_network ? toset(["network"]) : toset([])
  name     = "${var.prefix}-${var.uid}-SumoCWDeadLetterQueue-flowlogs"

  tags = {
    Component = local.module
    Name      = "${var.prefix}-${var.uid}-queue-SumoCWDeadLetterQueue-flowlogs"
  }
}
# CW Process DLQ Schedule Rule (SumoCWProcessDLQScheduleRule)
resource "aws_cloudwatch_event_rule" "dlq_flowlogs" {
  for_each            = var.create_network ? toset(["network"]) : toset([])
  name                = "${var.prefix}-${var.uid}-SumoCWProcessDLQScheduleRule-flowlogs"
  description         = "Events rule for Cron"
  schedule_expression = "rate(5 minutes)"
  is_enabled          = true

  tags = {
    Component = local.module
    Name      = "${var.prefix}-${var.uid}-eventrule-SumoCWProcessDLQScheduleRule-flowlogs"
  }
}
resource "aws_cloudwatch_event_target" "dlq_flowlogs" {
  for_each = var.create_network ? toset(["network"]) : toset([])
  rule     = aws_cloudwatch_event_rule.dlq_flowlogs["network"].name
  arn      = aws_lambda_function.dlq_flowlogs["network"].arn
}
# CW Process DLQ Lambda Function (SumoCWProcessDLQLambda)
resource "aws_lambda_function" "dlq_flowlogs" {
  for_each      = var.create_network ? toset(["network"]) : toset([])
  function_name = "${var.prefix}-${var.uid}-SumoCWProcessDLQLambda-flowlogs"
  s3_bucket     = "appdevzipfiles-${data.aws_region.current.name}" # will work for most global Regions
  s3_key        = "cloudwatchlogs-with-dlq.zip"
  role          = aws_iam_role.lambda_role_flowlogs["network"].arn
  timeout       = 300
  handler       = "DLQProcessor.handler"
  dead_letter_config {
    target_arn = aws_sqs_queue.dlq_flowlogs["network"].arn
  }
  runtime     = "nodejs16.x"
  memory_size = 128
  environment {
    variables = {
      SUMO_ENDPOINT               = sumologic_http_source.flowlogs["network"].url
      TASK_QUEUE_URL              = aws_sqs_queue.dlq_flowlogs["network"].name
      NUM_OF_WORKERS              = 4
      LOG_FORMAT                  = "VPC-JSON"
      INCLUDE_LOG_INFO            = true
      LOG_STREAM_PREFIX           = ""
      INCLUDE_SECURITY_GROUP_INFO = true
      # VPC_CIDR_PREFIX = 
    }
  }
  depends_on = [
    aws_cloudwatch_log_group.dlq_flowlogs,
    aws_iam_role.lambda_role_flowlogs,
    aws_sqs_queue.dlq_flowlogs
  ]

  tags = {
    Component = local.module
    Name      = "${var.prefix}-${var.uid}-function-SumoCWProcessDLQLambda-flowlogs"
  }
}
resource "aws_cloudwatch_log_group" "dlq_flowlogs" {
  for_each          = var.create_network ? toset(["network"]) : toset([])
  name              = "/aws/lambda/${var.prefix}-${var.uid}-SumoCWProcessDLQLambda-flowlogs"
  retention_in_days = 7

  tags = {
    Component = local.module
    Name      = "${var.prefix}-${var.uid}-lg-SumoCWProcessDLQLambda-flowlogs"
  }
}
# CW Email SNS Topic (SumoCWEmailSNSTopic)
resource "aws_sns_topic" "flowlogs" {
  for_each = var.create_network ? toset(["network"]) : toset([])
  name     = "${var.prefix}-${var.uid}-SumoCWEmailSNSTopic-flowlogs"

  tags = {
    Component = local.module
    Name      = "${var.prefix}-${var.uid}-topic-SumoCWEmailSNSTopic-flowlogs"
  }
}
resource "aws_sns_topic_subscription" "dlq_flowlogs" {
  for_each  = var.create_network ? toset(["network"]) : toset([])
  topic_arn = aws_sns_topic.flowlogs["network"].arn
  protocol  = "sqs"
  endpoint  = aws_sqs_queue.dlq_flowlogs["network"].arn
}
# CW Spillover Alarm (SumoCWSpilloverAlarm)
resource "aws_cloudwatch_metric_alarm" "spillover-flowlogs" {
  for_each          = var.create_network ? toset(["network"]) : toset([])
  alarm_name        = "${var.prefix}-${var.uid}-SumoCWSpilloverAlarm-flowlogs"
  alarm_description = "Notify via email if number of messages in DeadLetterQueue exceeds threshold"
  alarm_actions     = [aws_sns_topic.flowlogs["network"].arn]

  comparison_operator = "GreaterThanThreshold"
  dimensions = {
    name  = "QueueName"
    value = aws_sqs_queue.dlq_flowlogs["network"].name
  }
  evaluation_periods = 1
  metric_name        = "ApproximateNumberOfMessagesVisible"
  namespace          = "AWS/SQS"
  period             = 3600
  statistic          = "Sum"
  threshold          = 100000


  depends_on = [
    aws_sns_topic.flowlogs
  ]

  tags = {
    Component = local.module
    Name      = "${var.prefix}-${var.uid}-alarm-SumoCWSpilloverAlarm-flowlogs"
  }

}
