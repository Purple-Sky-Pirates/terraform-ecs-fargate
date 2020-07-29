# main creds for AWS connection
variable "aws_access_key_id" {
  description = "AWS access key"
}

variable "aws_secret_access_key" {
  description = "AWS secret access key"
}

variable "region" {
  description = "AWS region"
}

variable "aws_ecr_repository" {
  description = "repo of the docker image"
}

variable "tag" {
  description = "tag of the docker image"
}

