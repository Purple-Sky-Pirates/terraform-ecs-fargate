[
  {
    "name": "dummyapi",
    "image": "${aws_ecr_repository}:${tag}",
    "essential": true,
    "logConfiguration": {
      "logDriver": "awslogs",
      "options": {
        "awslogs-region": "eu-west-2",
        "awslogs-stream-prefix": "dummyapi-staging-service",
        "awslogs-group": "awslogs-dummyapi-staging"
      }
    },
    "portMappings": [
      {
        "containerPort": 8000,
        "hostPort": 8000,
        "protocol": "tcp"
      }
    ],
    "cpu": 1,
    "environment": [
      {
        "name": "NODE_ENV",
        "value": "staging"
      },
      {
        "name": "PORT",
        "value": "8000"
      }
    ],
    "ulimits": [
      {
        "name": "nofile",
        "softLimit": 65536,
        "hardLimit": 65536
      }
    ],
    "mountPoints": [],
    "memory": 512,
    "volumesFrom": []
  }
]