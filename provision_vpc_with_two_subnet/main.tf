#Author: Sboniso G Mzizi
#Date: 20-01-2023

#This script will provision resource on AWS Cloud.
# Resources:
# VPC
# Two subnets private and public
# NACl
# Security Group
# Internet Gateway
# Nat Gateway
# Route Table


#Cloud provider
terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "4.50.0"
    }
  }
}

#AWS cloud region 
provider "aws" {
  region = "us-east-1"
}


#Provision vpc
resource "aws_vpc" "tech_datacenter" {
  cidr_block = "192.168.1.0/24"
  instance_tenancy = "default"
  tags = {
    Name = "tech-datacenter"
  }
}

#Provision public subnet
resource "aws_subnet" "tech_datacenter_public_subnet" {
  vpc_id                  = aws_vpc.tech_datacenter.id
  cidr_block              = "192.168.1.0/25"
  availability_zone       = "us-east-1f"
  map_public_ip_on_launch = true

  tags = {
    Name = "tech-datacenter-public-subnet"
  }

  depends_on = [
    aws_vpc.tech_datacenter
  ]
}


#Provision private subnet
resource "aws_subnet" "tech_datacenter_private_subnet" {
  vpc_id                  = aws_vpc.tech_datacenter.id
  cidr_block              = "192.168.1.128/25"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = false

  tags = {
    Name = "tech-datacenter-private-subnet"
  }

  depends_on = [
    aws_vpc.tech_datacenter
  ]
}


#Provision internet gateway
resource "aws_internet_gateway" "tech_internet_gateway" {
  vpc_id = aws_vpc.tech_datacenter.id

  tags = {
    Name = "tech_internet_gateway"
  }

  depends_on = [
    aws_vpc.tech_datacenter
  ]
}

#Provision elastic ip address
resource "aws_eip" "tech_eip" {
  vpc = true
}

#Provision nat gateway
resource "aws_nat_gateway" "tech_nat_gateway" {

  allocation_id = aws_eip.tech_eip.id
  subnet_id     = aws_subnet.tech_datacenter_public_subnet.id

  tags = {
    Name = "tech_nat_gateway"
  }

  depends_on = [
    aws_internet_gateway.tech_internet_gateway,
    aws_eip.tech_eip
  ]
}

#Provision route table for public subnet
resource "aws_route_table" "tech_route_table_public" {
  vpc_id = aws_vpc.tech_datacenter.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.tech_internet_gateway.id
  }

  tags = {
    Name = "tech_route_table_public"
  }
}

#Provision route table for private subnet
resource "aws_route_table" "tech_route_table_private" {
  vpc_id = aws_vpc.tech_datacenter.id

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.tech_nat_gateway.id
  }

  tags = {
    Name = "tech_route_table_private"
  }

  depends_on = [
    aws_vpc.tech_datacenter
  ]
}

#Associating subnet and route table
resource "aws_route_table_association" "route_table_association_public" {
  subnet_id      = aws_subnet.tech_datacenter_public_subnet.id
  route_table_id = aws_route_table.tech_route_table_public.id
  depends_on = [
    aws_subnet.tech_datacenter_public_subnet,
    aws_route_table.tech_route_table_public
  ]
}

#Associating subnet and route table
resource "aws_route_table_association" "route_table_association_private" {
  subnet_id      = aws_subnet.tech_datacenter_private_subnet.id
  route_table_id = aws_route_table.tech_route_table_private.id
   depends_on = [
    aws_subnet.tech_datacenter_private_subnet,
    aws_route_table.tech_route_table_private
  ]
}

#Provision network access control list 
resource "aws_network_acl" "tech_acl" {
  vpc_id = aws_vpc.tech_datacenter.id

   ingress {
    protocol   = -1
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  egress {
    protocol   = -1
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  tags = {
    Name = "main"
  }


  depends_on = [
    aws_vpc.tech_datacenter
  ]
}

#Provision security group
resource "aws_security_group" "allow_http" {
  name        = "allow_http"
  description = "Allow http inbound traffic"
  vpc_id      = aws_vpc.tech_datacenter.id

  ingress {
    description      = "HTTP from VPC"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_http"
  }


  depends_on = [
    aws_vpc.tech_datacenter
  ]
}

