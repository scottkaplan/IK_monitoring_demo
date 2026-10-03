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
  region = "us-west-1" # Change to your preferred AWS target region
}

# ==========================================
# NETWORK SETUP (VPC, SUBNET, IGW, ROUTING)
# ==========================================

resource "aws_vpc" "ik_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "IK"
  }
}

resource "aws_subnet" "ik_subnet" {
  vpc_id            = aws_vpc.ik_vpc.id
  cidr_block        = "10.0.0.0/24" # Fits within the 10.0.0.0/16 VPC block allocation
  availability_zone = "us-west-1a"

  tags = {
    Name = "IK-Public-Subnet"
  }
}

resource "aws_internet_gateway" "ik_igw" {
  vpc_id = aws_vpc.ik_vpc.id

  tags = {
    Name = "IK-IGW"
  }
}

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

  ingress {
    description = "SSH Access"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Grafana Web Dashboard"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Custom Python Demo HTTP App"
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Prometheus Engine Console UI"
    from_port   = 9090
    to_port     = 9090
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
    Name = "IK-Monitoring-SG"
  }
}

# ==========================================
# COMPUTE ENGINE (EC2 INSTANCE & EIP)
# ==========================================

data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023*-x86_64"]
  }
}

resource "aws_instance" "monitoring_node" {
  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.ik_subnet.id
  vpc_security_group_ids = [aws_security_group.monitoring_sg.id]
  key_name               = "IK"

  # Automate installation and service injection without using git
  user_data = <<-EOF
              #!/bin/bash
              # 1. Install and Start Docker Engine
              dnf update -y
              dnf install -y docker
              systemctl enable --now docker
              usermod -aG docker ec2-user

              # 2. Setup the Docker Compose Plugin manually
              mkdir -p /usr/libexec/docker/cli-plugins
              curl -SL https://github.com(uname -m) -o /usr/libexec/docker/cli-plugins/docker-compose
              chmod +x /usr/libexec/docker/cli-plugins/docker-compose

              # 3. Create Project Structure
              mkdir -p /home/ec2-user/prometheus-demo/app
              mkdir -p /home/ec2-user/prometheus-demo/grafana-storage
              chown -R 472:472 /home/ec2-user/prometheus-demo/grafana-storage

              # 4. Write Python HTTP server application
              cat << 'APP_EOF' > /home/ec2-user/prometheus-demo/app/main.py
              import time
              import random
              from http.server import HTTPServer, BaseHTTPRequestHandler
              from prometheus_client import generate_latest, CONTENT_TYPE_LATEST, Counter, Gauge, Histogram, Summary

              REQUEST_COUNT = Counter('demo_requests_total', 'Total number of HTTP requests received', ['method', 'endpoint'])
              ACTIVE_USERS = Gauge('demo_active_users', 'Current active users on the platform')
              REQUEST_LATENCY = Histogram('demo_request_latency_seconds', 'Time spent processing request')
              PAYLOAD_SIZE = Summary('demo_payload_size_bytes', 'Size of processed payloads')

              class MetricServer(BaseHTTPRequestHandler):
                  def do_GET(self):
                      if self.path == '/metrics':
                          self.send_response(200)
                          self.send_header('Content-Type', CONTENT_TYPE_LATEST)
                          self.end_headers()
                          self.wfile.write(generate_latest())
                      else:
                          REQUEST_COUNT.labels(method=self.command, endpoint=self.path).inc()
                          ACTIVE_USERS.set(random.randint(10, 100))
                          with REQUEST_LATENCY.time():
                              time.sleep(random.uniform(0.01, 0.5))
                          PAYLOAD_SIZE.observe(random.randint(100, 5000))
                          self.send_response(200)
                          self.send_header('Content-Type', 'text/html')
                          self.end_headers()
                          self.wfile.write(b"<h1>Demo App running...</h1>")

              if __name__ == '__main__':
                  server = HTTPServer(('0.0.0.0', 8000), MetricServer)
                  print("Server started on port 8000")
                  server.serve_forever()
              APP_EOF

              # 5. Write App Requirements configuration
              cat << 'REQ_EOF' > /home/ec2-user/prometheus-demo/app/requirements.txt
              prometheus_client==0.21.0
              REQ_EOF

              # 6. Write Prometheus Target scrapers
              cat << 'PROM_EOF' > /home/ec2-user/prometheus-demo/prometheus.yml
              global:
                scrape_interval: 5s
              scrape_configs:
                - job_name: 'demo-http-app'
                  static_configs:
                    - targets: ['demo-app:8000']
              PROM_EOF

              # 7. Write Orchestration blueprint Compose profile
              cat << 'COMPOSE_EOF' > /home/ec2-user/prometheus-demo/docker-compose.yml
              version: '3.8'
              services:
                demo-app:
                  image: python:3.11-slim
                  container_name: demo-app
                  volumes:
                    - ./app:/app
                  working_dir: /app
                  command: sh -c "pip install -r requirements.txt && python main.py"
                  ports:
                    - "8000:8000"
                prometheus:
                  image: prom/prometheus:latest
                  container_name: prometheus
                  volumes:
                    - ./prometheus.yml:/etc/prometheus/prometheus.yml
                  ports:
                    - "9090:9090"
                grafana:
                  image: grafana/grafana:latest
                  container_name: grafana
                  ports:
                    - "3000:3000"
                  volumes:
                    - ./grafana-storage:/var/lib/grafana
                  environment:
                    - GF_SECURITY_ADMIN_PASSWORD=admin
              COMPOSE_EOF

              # 8. Spin up stack infrastructure containers
              cd /home/ec2-user/prometheus-demo
              docker compose up -d
              EOF

  tags = {
    Name = "IK-Monitoring-Demo-Server"
  }
}

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

data "aws_route53_zone" "primary_domain" {
  name         = "kaplans.com."
  private_zone = false
}

resource "aws_route53_record" "dns_cname" {
  zone_id = data.aws_route53_zone.primary_domain.zone_id
  name    = "monitoring_://kaplans.com"
  type    = "CNAME"
  ttl     = 300
  records = [aws_eip.monitoring_eip.public_dns]
}

# ==========================================
# COMMAND LINE TERMINAL OUTPUT SUMMARY
# ==========================================

output "instance_public_ip" {
  value       = aws_eip.monitoring_eip.public_ip
  description = "The target public Static IP pointing directly to your instances layout endpoints."
}

output "dns_endpoint" {
  value       = "http://monitoring_://kaplans.com:3000"
  description = "The target live web address URL endpoint layer routing directly to your Grafana screen dashboards."
}
