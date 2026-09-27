resource "aws_cloudwatch_log_group" "vpc_flow" {
  for_each = local.vpcs

  name              = "/aws/vpc-flow-logs/${var.project_name}/${each.key}"
  retention_in_days = 30
}

data "aws_iam_policy_document" "flow_logs_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["vpc-flow-logs.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "flow_logs" {
  name               = "${var.project_name}-flow-logs"
  assume_role_policy = data.aws_iam_policy_document.flow_logs_assume_role.json
}

data "aws_iam_policy_document" "flow_logs" {
  statement {
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams",
      "logs:PutLogEvents",
    ]
    resources = [
      for log_group in aws_cloudwatch_log_group.vpc_flow : "${log_group.arn}:*"
    ]
  }
}

resource "aws_iam_role_policy" "flow_logs" {
  name   = "${var.project_name}-flow-logs"
  role   = aws_iam_role.flow_logs.id
  policy = data.aws_iam_policy_document.flow_logs.json
}

resource "aws_flow_log" "vpc" {
  for_each = local.vpcs

  iam_role_arn    = aws_iam_role.flow_logs.arn
  log_destination = aws_cloudwatch_log_group.vpc_flow[each.key].arn
  traffic_type    = "ALL"
  vpc_id          = aws_vpc.environment[each.key].id

  tags = {
    Name = "${var.project_name}-${each.key}-flow-log"
  }
}

