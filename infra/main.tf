# Configure Terraform backend (оставляем без изменений)
terraform {
  backend "s3" {
    bucket         = "my-terraform-state-bucket-c-a"
    key            = "projects/c-a/terraform.tfstate"
    region         = "eu-central-1"
    dynamodb_table = "my-terraform-lock-table"
    encrypt        = true
  }
}

# Configure the AWS provider
provider "aws" {
  region = var.aws_region
}

# Create a VPC
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "c-a-vpc"
  }
}

# Create an Internet Gateway
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "c-a-igw"
  }
}

# Create a public subnet in first AZ
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = var.availability_zone
  map_public_ip_on_launch = true
  tags = {
    Name = "c-a-public-subnet"
  }
}

# Create a public subnet in second AZ
resource "aws_subnet" "public_2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = var.availability_zone_2
  map_public_ip_on_launch = true
  tags = {
    Name = "c-a-public-subnet-2"
  }
}

# Create a Route Table for public subnets
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
}

# Associate the Route Table with the public subnets
resource "aws_route_table_association" "public_assoc_1" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "public_assoc_2" {
  subnet_id      = aws_subnet.public_2.id
  route_table_id = aws_route_table.public_rt.id
}

# Security Group for the Load Balancer
resource "aws_security_group" "lb_sg" {
  name   = "c-a-lb-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    description = "Allow HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow HTTPS from anywhere"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Security Group for the EC2 instances
resource "aws_security_group" "instance_sg" {
  name   = "c-a-instance-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    description     = "Allow HTTP from the Load Balancer"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.lb_sg.id]
  }

  ingress {
    description = "Allow SSH access"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Создание Application Load Balancer
resource "aws_lb" "app_lb" {
  name               = "c-a-app-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.lb_sg.id]
  subnets            = [aws_subnet.public.id, aws_subnet.public_2.id]

  tags = {
    Name = "c-a-app-lb"
  }
}

# HTTP Listener, перенаправляющий на HTTPS
resource "aws_lb_listener" "http_listener" {
  load_balancer_arn = aws_lb.app_lb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

# HTTPS Listener для Load Balancer (используем сертификат, переданный через переменную)
resource "aws_lb_listener" "https_listener" {
  load_balancer_arn = aws_lb.app_lb.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = var.acm_certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_tg.arn
  }
}

# Launch Template for application instances
resource "aws_launch_template" "app_lt" {
  name_prefix   = "c-a-app-lt-"
  image_id      = var.ami_id
  instance_type = var.instance_type
  key_name      = var.key_pair_name

  network_interfaces {
    device_index                = 0
    associate_public_ip_address = true
    security_groups             = [aws_security_group.instance_sg.id]
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "c-a-app-instance"
    }
  }
}

# Создание Target Group для EC2 инстансов
resource "aws_lb_target_group" "app_tg" {
  name     = "c-a-app-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    path                = "api/health"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 60
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = {
    Name = "c-a-app-tg"
  }
}

# Auto Scaling Group with desired capacity of 3 instances
resource "aws_autoscaling_group" "app_asg" {
  name                = "c-a-app-asg"
  max_size            = 3
  min_size            = 3
  desired_capacity    = 3
  vpc_zone_identifier = [aws_subnet.public.id, aws_subnet.public_2.id]

  launch_template {
    id      = aws_launch_template.app_lt.id
    version = "$Latest"
  }

  target_group_arns = [aws_lb_target_group.app_tg.arn]

  tag {
    key                 = "Name"
    value               = "c-a-app-instance"
    propagate_at_launch = true
  }

  # Optional health check configuration
  health_check_type         = "ELB"
  health_check_grace_period = 500

  lifecycle {
    create_before_destroy = true
  }
}

data "aws_instances" "asg_instances" {
  filter {
    name   = "tag:aws:autoscaling:groupName"
    values = [aws_autoscaling_group.app_asg.name]
  }
}

output "public_ips" {
  value = data.aws_instances.asg_instances.public_ips
}
