variable "vpc_id" {
  type        = string
  description = "ID of VPC to deploy application into"
}

variable "public_subnet_ids" {
  type        = list(string)
  description = "List of subnet ID's for public subnets"
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "List of subnet ID's for private subnet"
}

variable "availability_zones" {
  type        = list(string)
  default     = ["eu-west-1a", "eu-west-1b"]
  description = "List of availability zones to use for Application Load Balancer"
}

variable "certificate_arn" {
  type        = string
  description = "ARN of ACM certificate"
}

variable "aws_region" {
  type        = string
  default     = "eu-west-1"
  description = "AWS region"
}