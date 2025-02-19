variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "eu-central-1"
}

variable "ami_id" {
  description = "AMI ID for EC2 instance"
  type        = string
  default     = "ami-099da3ad959447ffa"
}

variable "availability_zone" {
  description = "Availability zone for the subnet"
  type        = string
  default     = "eu-central-1a"
}

variable "availability_zone_2" {
  description = "Zweite Availability Zone für Load Balancer"
  type        = string
  default     = "eu-central-1b"  
}


variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.small"
}

variable "key_pair_name" {
  description = "Name of the SSH key pair to access the instance"
  type        = string
  default     = "c-a"  
}
# variable "aws_access_key" {
#   default = "ASIAVA5YK74JKRVCCVKV"
# }

# variable "aws_secret_key" {
#   default = "H/jbQj+QH1byS39GOkcA5ZVDfxvC7BiLXDjVvBnR"
# }

variable "acm_certificate_arn" {
  description = "ARN of the AWS ACM certificate"
  type        = string
}
