variable "project_name" {
  description = "Project name prefix for resources"
  type        = string
  default     = "glucosestream-aws"
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "tags" {
  description = "Common tags"
  type        = map(string)
  default = {
    Project = "glucosestream-aws"
    Owner   = "glucose-stream"
  }
}

