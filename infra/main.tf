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

# --- Удалены ресурсы Load Balancer, Target Group, Listeners и ACM сертификаты ---

# Security Group for the EC2 instance
resource "aws_security_group" "instance_sg" {
  name   = "c-a-instance-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    description = "Allow HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
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
