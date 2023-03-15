data "aws_cloudwatch_event_bus" "default" {
  name = "default"
}

data "aws_region" "current" {}
