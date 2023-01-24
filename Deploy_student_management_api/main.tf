# Configure the AWS Provider
provider "aws" {
  region = "us-east-1"
}

#Retrieve the list of AZs in the current AWS region
data "aws_availability_zones" "available" {}
data "aws_region" "current" {}

# Terraform Data Block - Lookup Ubuntu 20.04
data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"]
}

#Define the VPC 
resource "aws_vpc" "vpc" {
  cidr_block = var.vpc_cidr

  tags = {
    Name        = var.vpc_name
    Environment = "techcreate_datacenter_environment"
    Terraform   = "true"
  }
}


#Deploy the public subnets
resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = "192.168.0.0/26"
  availability_zone       = tolist(data.aws_availability_zones.available.names)[0]
  map_public_ip_on_launch = true

  tags = {
    Name      = "application_subent"
    Terraform = "true"
  }
}


#Create Internet Gateway
resource "aws_internet_gateway" "internet_gateway" {
  vpc_id = aws_vpc.vpc.id
  tags = {
    Name      = "techcreate_datacenter_igw"
    Terraform = "true"
  }
}

#Create route tables for public subnet
resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.internet_gateway.id

  }
  tags = {
    Name      = "techcreate_public_rtb"
    Terraform = "true"
  }
}


#Create route table associations
resource "aws_route_table_association" "public" {
  depends_on     = [aws_subnet.public_subnet]
  route_table_id = aws_route_table.public_route_table.id
  subnet_id      = aws_subnet.public_subnet.id
}

#Terraform Resouse Block - To Build Security Group for API Web Server
resource "aws_security_group" "allow_http" {
  name        = "allow_http_port_8080"
  description = "Allow http inbound traffic"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    description = "allow inbound http traffic "
    from_port   = 8080
    to_port     = 8080
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
    Name      = "allow_http"
    Terraform = "true"
  }
}

resource "aws_security_group" "allow_ssh" {
  name        = "allow_ssh"
  description = "Allow ssh inbound traffic"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    description = "allow ssh inboud traffic"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] #not recommanded to use 0.0.0.0/0
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name      = "allow_ssh"
    Terraform = "true"
  }
}


# Terraform Resource Block - To Build EC2 instance in Public Subnet
resource "aws_instance" "api_server" {
  ami             = data.aws_ami.ubuntu.id
  instance_type   = "t2.micro"
  subnet_id       = aws_subnet.public_subnet.id
  security_groups = [aws_security_group.allow_http.id, aws_security_group.allow_ssh.id]
  key_name        = aws_key_pair.api_server_key_pair.key_name
  connection {
    user        = "ubuntu"
    private_key = tls_private_key.rsa_4096_key_generator.private_key_pem
    host        = self.public_ip
  }

  #Modify private key file permission to 0600
  provisioner "local-exec" {
    command = "chmod 600 ${local_file.private_key_pem.filename}" 
  }

  #Instruction for deplaying Student management system api
  provisioner "remote-exec" {
    inline = [
       "sudo apt update -y",
       "sudo apt upgrade -y",
       "sudo apt install wget -y",
       "sudo apt install unzip -y",
       "sudo apt install maven -y",
       "sudo apt install openjdk-11-jdk -y",
       "wget https://github.com/SbonisoGordonMzizi/student-management-restapi/archive/refs/heads/main.zip",
       "unzip main.zip && cd student-management-restapi-main",
       "mvn compile",
       "mvn spring-boot:start"
    ]
  }

  tags = {
    Name      = "API EC2 Server"
    Terraform = "true"
  }

  lifecycle {
    ignore_changes = [security_groups]
  }
}

#Generate ssh-key
resource "tls_private_key" "rsa_4096_key_generator" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

#Store ssh private key on a local system
resource "local_file" "private_key_pem" {
  content  = tls_private_key.rsa_4096_key_generator.private_key_pem
  filename = "Api_aws_server_key.pem"
}

#Create aws_key_pair for API Server
resource "aws_key_pair" "api_server_key_pair" {
  key_name   = "API_Server_key"
  public_key = tls_private_key.rsa_4096_key_generator.public_key_openssh
  lifecycle {
    ignore_changes = [key_name]
  }
}


