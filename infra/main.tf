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

# Обновленная группа безопасности для Load Balancer
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
    from_port       = 80         # Разрешаем вход на порт 80
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

# Создаём один EC2-инстанс вместо ASG/Launch Template
resource "aws_instance" "app" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  key_name               = var.key_pair_name
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.instance_sg.id]
  associate_public_ip_address = true

  user_data = base64encode(<<-EOF
    #!/bin/bash
    amazon-linux-extras install docker -y
    service docker start
    usermod -a -G docker ec2-user
    # Запустите ваш Docker контейнер, например:
    # docker run -d -p 3000:3000 c-a-app:latest
  EOF
  )

  tags = {
    Name = "c-a-app-instance"
  }
}

# --- Удалены ресурсы Launch Template и Auto Scaling Group ---

# Если ранее выводились public IP адреса из ASG, можно добавить вывод из aws_instance
output "public_ip" {
  value = aws_instance.app.public_ip
}


# HTTP Listener that redirects to HTTPS
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


#Https
resource "aws_lb_listener" "https_listener" {
  load_balancer_arn = aws_lb.app_lb.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = var.acm_certificate_arn  # Используем переменную

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_tg.arn  # Убедитесь, что имя целевой группы правильное
  }
}

# resource "aws_lb_listener" "http_listener" {
#   load_balancer_arn = aws_lb.this.arn
#   port              = "80"
#   protocol          = "HTTP"

#   default_action {
#     type = "redirect"

#     redirect {
#       port        = "443"
#       protocol    = "HTTPS"
#       status_code = "HTTP_301"
#     }
#   }
# }
# resource "aws_acm_certificate" "cert" {
#   domain_name       = "macht.top"  # Замените на ваш домен
#   validation_method = "DNS"

#   lifecycle {
#     create_before_destroy = true
#   }

#   tags = {
#     Name = "medicall-cfd-cert"
#   }
# }

# variable "acm_certificate_arn" {
#   description = "ARN of the AWS ACM certificate"
#   type        = string
# }
# Launch Template for application instances
resource "aws_launch_template" "app_lt" {
  name_prefix   = "c-a-app-lt-"
  image_id      = var.ami_id
  instance_type = var.instance_type
  key_name      = var.key_pair_name

  network_interfaces {
    device_index = 0
    # subnet_id    = aws_subnet.public.id  # Можно убрать, если используете `vpc_zone_identifier` в ASG
    associate_public_ip_address = true
    security_groups              = [aws_security_group.instance_sg.id]
  }
  # vpc_security_group_ids = [aws_security_group.instance_sg.id]

  # # User data installs Docker, Docker Compose and runs the container
  # user_data = base64encode(<<-EOF
  #   #!/bin/bash
  #   amazon-linux-extras install docker -y
  #   service docker start
  #   usermod -a -G docker ec2-user

  #   curl -L "https://github.com/docker/compose/releases/download/v2.18.1/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
  #   chmod +x /usr/local/bin/docker-compose

  #   docker run -d -p 3000:3000 c-a-app:latest
  # EOF
  # )

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "c-a-app-instance"
    }
  }
}

# Auto Scaling Group with desired capacity of 3 instances
resource "aws_autoscaling_group" "app_asg" {
  name                      = "c-a-app-asg"
  max_size                  = 3
  min_size                  = 3
  desired_capacity          = 3
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
  health_check_grace_period = 300
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


