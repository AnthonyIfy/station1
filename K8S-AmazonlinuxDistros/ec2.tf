# Configure AWS provider with proper credentials
provider "aws" {
  region  = "us-west-1"
  profile = "asher"
}

# Create default VPC if one does not exist
resource "aws_default_vpc" "default_vpc" {
  tags = {
    Name = "default vpc"
  }
}

# Get all availability zones in the region
data "aws_availability_zones" "available_zones" {}

# Create default subnet if one does not exist
resource "aws_default_subnet" "default_az1" {
  availability_zone = data.aws_availability_zones.available_zones.names[0]

  tags = {
    Name = "default subnet"
  }
}

# Create security group for the EC2 instances
resource "aws_security_group" "ec2_security_group6" {
  name        = "ec2-security-group6"
  description = "allow access on required ports"
  vpc_id      = aws_default_vpc.default_vpc.id  # ✅ fixed reference

  ingress {
    description = "http access"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "k8s all traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "k8s kubelet"
    from_port   = 10250
    to_port     = 10250
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "k8s api server"
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "nodeport"
    from_port   = 31111
    to_port     = 31111
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "https access"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "ssh access"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "k8s-server-sg"
  }
}

# Use data source to get the latest Amazon Linux 2 AMI
data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

# Launch EC2 instances with user_data script
resource "aws_instance" "ec2_instance" {
  ami                    = data.aws_ami.amazon_linux_2.id
  instance_type          = "t3.medium"
  subnet_id              = aws_default_subnet.default_az1.id
  vpc_security_group_ids = [aws_security_group.ec2_security_group6.id]
  key_name               = "deployment"
  count                  = 3

  tags = {
    Name = "kubernetes-server-${count.index + 1}"
  }

  # Run install_k8s.sh at instance boot
  user_data = file("${path.module}/install_k8s.sh")  # ✅ replaces provisioners
}

# Print the public IPs of the EC2 instances
output "container_urls" {
  value = aws_instance.ec2_instance[*].public_ip
}
