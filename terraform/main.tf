terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-west-2" # Change to your preferred AWS target region
}

# ==========================================
# NETWORK SETUP (VPC, SUBNET, IGW, ROUTING)
# ==========================================

# Create the dedicated VPC layer
resource "aws_vpc" "ik_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "IK"
  }
}

# Create a Public Subnet for the footprint infrastructure
resource "aws_subnet" "ik_subnet" {
  vpc_id            = aws_vpc.ik_vpc.id
  cidr_block        = "10.0.0.0/24" # Fits within the 10.0.0.0/16 VPC block allocation
  availability_zone = "us-west-2a"

  tags = {
    Name = "IK-Public-Subnet"
  }
}

# Internet Gateway to provide outside public access
resource "aws_internet_gateway" "ik_igw" {
  vpc_id = aws_vpc.ik_vpc.id

  tags = {
    Name = "IK-IGW"
  }
}

# Route Table directing external traffic to the Internet Gateway
resource "aws_route_table" "ik_route_table" {
  vpc_id = aws_vpc.ik_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.ik_igw.id
  }

  tags = {
    Name = "IK-Public-RouteTable"
  }
}

# Explicitly bind the public subnet to the Internet-facing routing engine
resource "aws_route_table_association" "ik_association" {
  subnet_id      = aws_subnet.ik_subnet.id
  route_table_id = aws_route_table.ik_route_table.id
}

# ==========================================
# FIREWALL RULES (SECURITY GROUP)
# ==========================================

resource "aws_security_group" "monitoring_sg" {
  name        = "monitoring_demo_sg"
  description = "Allow SSH access and Prometheus / Grafana pipeline ports"
  vpc_id      = aws_vpc.ik_vpc.id

  # SSH Access
  ingress {
    description = "SSH Access"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Change to your specific home/office IP for strict security
  }

  # Grafana UI Access
  ingress {
    description = "Grafana Web Dashboard"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Optional Port: Demo Web App
  ingress {
    description = "Custom Python Demo HTTP App"
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Optional Port: Prometheus Admin Dashboard
  ingress {
    description = "Prometheus Engine Console UI"
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Full Outbound Internet Access rules
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "IK-Monitoring-SG"
  }
}

# ==========================================
# COMPUTE ENGINE (EC2 INSTANCE & EIP)
# ==========================================

# Lookup dynamically the latest official image code identifier for Amazon Linux 2023
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023*-x86_64"]
  }
}

# Launch your target EC2 Instance environment
resource "aws_instance" "monitoring_node" {
  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.ik_subnet.id
  vpc_security_group_ids = [aws_security_group.monitoring_sg.id]
  key_name               = "IK" # Links your existing matching system key pair profile

  tags = {
    Name = "IK-Monitoring-Demo-Server"
  }
}

# Provision a Static Elastic IP Address allocation mapping block
resource "aws_eip" "monitoring_eip" {
  domain   = "vpc"
  instance = aws_instance.monitoring_node.id

  tags = {
    Name = "IK-Monitoring-EIP"
  }
}

# ==========================================
# DNS RECORD CREATION (ROUTE 53)
# ==========================================

# Resolves your existing base host platform domain inside AWS Route 53
data "aws_route53_zone" "primary_domain" {
  name         = "kaplans.com."
  private_zone = false
}

# Appends your specific custom record point pointing to the node target footprint endpoint EIP
resource "aws_route53_record" "dns_cname" {
  zone_id = data.aws_route53_zone.primary_domain.zone_id
  name    = "monitoring_demo.kaplans.com"
  type    = "CNAME"
  ttl     = 300
  records = [aws_eip.monitoring_eip.public_dns] # Maps dynamically to the AWS standard canonical public domain layout
}

# ==========================================
# COMMAND LINE TERMINAL OUTPUT SUMMARY
# ==========================================

output "instance_public_ip" {
  value       = aws_eip.monitoring_eip.public_ip
  description = "The target public Static IP pointing directly to your instances layout endpoints."
}

output "dns_endpoint" {
  value       = "http://monitoring_://kaplans.com"
  description = "The target live web address URL endpoint layer routing directly to your Grafana screen dashboards."
}
