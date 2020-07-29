Set of terraform scripts that will stand up an ECS Cluster with a container running in it (via Fargate)

terraform.tvars file:

```
aws_access_key_id = ""
aws_secret_access_key = ""
region = "eu-west-2"
tag = "latest"
aws_ecr_repository = "780480840318.dkr.ecr.eu-west-2.amazonaws.com/node-hello"
```

Problems:

Will not destroy until all tasks on the cluster are stopped.  I do this via the web ui.

