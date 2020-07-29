provider "aws" {
  region     = "${var.region}"
  access_key = "${var.aws_access_key_id}"
  secret_key = "${var.aws_secret_access_key}"
}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnet_ids" "default" {
  vpc_id = "${data.aws_vpc.default.id}"
}

resource "aws_security_group" "lb" {
  name        = "lb-sg"
  description = "controls access to the Application Load Balancer (ALB)"

  ingress {
    protocol    = "tcp"
    from_port   = 80
    to_port     = 8000
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "ecs_tasks" {
  name        = "ecs-tasks-sg"
  description = "allow inbound access from the ALB only"

  ingress {
    protocol        = "tcp"
    from_port       = 8000
    to_port         = 8000
    cidr_blocks     = ["0.0.0.0/0"]
    security_groups = [aws_security_group.lb.id]
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_lb" "staging" {
  name               = "alb"
  subnets            = data.aws_subnet_ids.default.ids
  load_balancer_type = "application"
  security_groups    = [aws_security_group.lb.id]

  tags = {
    Environment = "staging",
    Application = "dummyapi"
  }
}

resource "aws_lb_listener" "https_forward" {
  load_balancer_arn = aws_lb.staging.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.staging.arn
  }
}

resource "aws_lb_target_group" "staging" {
  name        = "dummyapi-alb-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = data.aws_vpc.default.id
  target_type = "ip"

  health_check {
    healthy_threshold   = "3"
    interval            = "90"
    protocol            = "HTTP"
    matcher             = "200-299"
    timeout             = "20"
    path                = "/"
    unhealthy_threshold = "2"
  }
}

//resource "aws_ecr_repository" "repo" {
//  name = "dummyapi/staging/runner"
//}

//resource "aws_ecr_lifecycle_policy" "repo-policy" {
//  repository = aws_ecr_repository.repo.name
//
//  policy = <<EOF
//{
//  "rules": [
//    {
//      "rulePriority": 1,
//      "description": "Keep image deployed with tag latest",
//      "selection": {
//        "tagStatus": "tagged",
//        "tagPrefixList": ["latest"],
//        "countType": "imageCountMoreThan",
//        "countNumber": 1
//      },
//      "action": {
//        "type": "expire"
//      }
//    },
//    {
//      "rulePriority": 2,
//      "description": "Keep last 2 any images",
//      "selection": {
//        "tagStatus": "any",
//        "countType": "imageCountMoreThan",
//        "countNumber": 2
//      },
//      "action": {
//        "type": "expire"
//      }
//    }
//  ]
//}
//EOF
//}

data "aws_iam_policy_document" "ecs_task_execution_role" {
  version = "2012-10-17"
  statement {
    sid     = ""
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ecs_task_execution_role" {
  name               = "ecs-staging-execution-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_execution_role.json
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

data "template_file" "dummyapi" {
  template = file("./dummyapp.json.tpl")
  vars = {
    aws_ecr_repository = "${var.aws_ecr_repository}"
    tag                = "${var.tag}"
    app_port           = 8000
  }
}

resource "aws_ecs_task_definition" "service" {
  family                   = "dummyapi-staging"
  network_mode             = "awsvpc"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  cpu                      = 256
  memory                   = 512
  requires_compatibilities = ["FARGATE"]
  container_definitions    = data.template_file.dummyapi.rendered
  tags = {
    Environment = "staging",
    Application = "dummyapi"
  }
}

resource "aws_ecs_cluster" "staging" {
    name = "staging"
}

resource "aws_ecs_service" "staging" {
  name            = "staging"
  cluster         = aws_ecs_cluster.staging.id
  task_definition = aws_ecs_task_definition.service.arn
  desired_count   = 2
  launch_type     = "FARGATE"

  network_configuration {
    security_groups  = [aws_security_group.ecs_tasks.id]
    subnets          = data.aws_subnet_ids.default.ids
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.staging.arn
    container_name   = "dummyapi"
    container_port   = 8000
  }

  depends_on = [aws_lb_listener.https_forward, aws_iam_role_policy_attachment.ecs_task_execution_role]

  tags = {
    Environment = "staging",
    Application = "dummyapi"
  }
}

resource "aws_cloudwatch_log_group" "dummyapi" {
  name = "awslogs-dummyapi-staging"

  tags = {
    Environment = "staging",
    Application = "dummyapi"
  }
}

// example -> ./push.sh . 123456789012.dkr.ecr.us-west-1.amazonaws.com/hello-world latest

//resource "null_resource" "push" {
//  provisioner "local-exec" {
//     command     = "${var.push_path}/push.sh ${var.source_path} ${aws_ecr_repository.repo.repository_url} ${var.tag}"
//     interpreter = ["bash", "-c"]
//  }
//}