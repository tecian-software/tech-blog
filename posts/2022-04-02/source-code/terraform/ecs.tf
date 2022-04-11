# define ECS cluster
resource "aws_ecs_cluster" "main" {
  name = "example-app-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

# define ECS task run by service
resource "aws_ecs_task_definition" "main" {

  family = "example-app"

  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]

  # define resouces for each task
  cpu    = 256
  memory = 512

  # give task required permissions to access DB and
  # services running in private subnets
  execution_role_arn = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn      = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([{
    name      = "example-app-api"
    image     = "nginx:latest"
    essential = true

    "environment" : [
      {
        "name" : "BUILD",
        "value" : "v0.1.0"
      }
    ]
    "logConfiguration" : {
      "logDriver" : "awslogs",
      "options" : {
        "awslogs-group" : "awslogs-example-app-api",
        "awslogs-region" : "${var.aws_region}",
        "awslogs-stream-prefix" : "example-app-api",
        "awslogs-create-group" : "true"
      }
    }
    healthCheckGracePeriodSeconds = 60
    portMappings = [
      {
        protocol      = "tcp"
        containerPort = 80
        hostPort      = 80
      }
    ]
  }])
}

# define ecs service to run ECS task via fargate
resource "aws_ecs_service" "main" {

  name    = "example-app-api"
  cluster = aws_ecs_cluster.main.id

  # add container tasks to ecs service
  task_definition     = aws_ecs_task_definition.main.arn
  desired_count       = 1
  launch_type         = "FARGATE"
  scheduling_strategy = "REPLICA"

  network_configuration {
    security_groups  = [aws_security_group.ecs_tasks.id]
    subnets          = data.aws_subnet.private.*.id
    assign_public_ip = true
  }

  # attach ecs service to loadbalancer to control traffic
  load_balancer {
    target_group_arn = aws_alb_target_group.http.arn
    container_name   = "example-app-api"
    container_port   = 80
  }
}

resource "aws_security_group" "ecs_tasks" {
  name        = "example-app-sg-task"
  vpc_id      = data.aws_vpc.main.id
  description = "Allow access from ALB sg to port 80 and allow all egress traffic"

  ingress {
    protocol        = "tcp"
    from_port       = 80
    to_port         = 80
    description     = "Allow ingress to HTTP port on ECS tasks from load balancer"
    security_groups = [aws_security_group.alb.id]
  }

  ingress {
    protocol        = "tcp"
    from_port       = 80
    to_port         = 80
    description     = "Allow ingress to HTTP port on ECS tasks from load balancer"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    protocol         = "-1"
    from_port        = 0
    to_port          = 0
    description      = "Allow egress to all sources"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}