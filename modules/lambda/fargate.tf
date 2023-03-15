
data "aws_availability_zones" "available" {
  state = "available"
}


module "vpc" {
  count   = var.use_existing_subnets ? 0 : 1
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 2.21"

  name = "autospotting-${module.label.id}"

  cidr = "10.0.0.0/24"

  azs            = [data.aws_availability_zones.available.names[0], data.aws_availability_zones.available.names[1]]
  public_subnets = ["10.0.0.0/25", "10.0.0.128/25"]

  enable_nat_gateway      = false
  enable_dns_hostnames    = true
  enable_dns_support      = true
  map_public_ip_on_launch = true
}

resource "aws_ecs_cluster" "autospotting" {
  name = "autospotting-${module.label.id}"
}

resource "aws_ecs_cluster_capacity_providers" "example" {
  cluster_name = aws_ecs_cluster.autospotting.name

  capacity_providers = ["FARGATE"]
  default_capacity_provider_strategy {
    capacity_provider = "FARGATE"
  }
}


resource "aws_ecs_task_definition" "autospotting_task_definition" {
  family                   = "autospotting-${module.label.id}"
  execution_role_arn       = var.use_existing_iam_role ? data.aws_arn.role_arn[0].arn : aws_iam_role.autospotting_role[0].arn
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 256
  memory                   = 512

  container_definitions = jsonencode([{
    name  = "autospotting-${module.label.id}"
    image = "${aws_ecr_repository.autospotting.repository_url}:${var.lambda_source_image_tag}"


    environment = [{
      name  = "AUTOMATED_INSTANCE_DATA_UPDATE"
      value = tostring(var.automated_instance_data_update)
      }, {
      name  = "BILLING_ONLY"
      value = "true"
      }, {
      name  = "NOTIFICATION_SNS_TOPIC"
      value = aws_sns_topic.email_notification.arn
      }, {
      name  = "SAVINGS_REPORTS_FREQUENCY"
      value = var.autospotting_savings_reports_frequency
    }]
  }])

  tags = module.label.tags
}

resource "aws_iam_role" "autospotting_task_execution" {
  count = var.use_existing_iam_role ? 0 : 1
  name  = "autospotting-${module.label.id}-task-execution"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = module.label.tags
}

resource "aws_iam_role_policy_attachment" "autospotting_task_execution_policy_attachment" {
  count      = var.use_existing_iam_role ? 0 : 1
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
  role       = aws_iam_role.autospotting_task_execution[count.index].name
}



resource "aws_cloudwatch_log_group" "autospotting" {
  name              = "autospotting-${module.label.id}"
  retention_in_days = 7
}

module "ecs-fargate-scheduled-task" {
  source  = "umotif-public/ecs-fargate-scheduled-task/aws"
  version = "~> 1.0.0"

  name_prefix = module.label.id

  ecs_cluster_arn = aws_ecs_cluster.autospotting.arn

  task_role_arn      = var.use_existing_iam_role ? data.aws_arn.role_arn[0].arn : aws_iam_role.autospotting_task_execution[0].arn
  execution_role_arn = var.use_existing_iam_role ? data.aws_arn.role_arn[0].arn : aws_iam_role.autospotting_task_execution[0].arn

  event_target_task_definition_arn = aws_ecs_task_definition.autospotting_task_definition.arn
  event_rule_schedule_expression   = "rate(1 hour)"
  event_target_subnets             = var.use_existing_subnets ? var.existing_subnets : module.vpc.public_subnets
  event_target_assign_public_ip    = true
}
