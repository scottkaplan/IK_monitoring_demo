#!/bin/bash
set -ex

echo "=== Starting Infrastructure Setup ==="

# 1. Update Core Dependencies and Launch Docker
dnf update -y
dnf install -y docker
systemctl enable --now docker
usermod -aG docker ec2-user

# 2. Setup the Docker Compose Engine Plugin cleanly
mkdir -p /usr/libexec/docker/cli-plugins
curl -SL "https://github.com" -o /usr/libexec/docker/cli-plugins/docker-compose
chmod +x /usr/libexec/docker/cli-plugins/docker-compose

# 3. Create Clean Working Space Environments
BASE_DIR="/home/ec2-user/prometheus-demo"
mkdir -p $BASE_DIR/app
mkdir -p $BASE_DIR/grafana-storage
chown -R 472:472 $BASE_DIR/grafana-storage

# 4. Fetch App and Infrastructure Asset Code Modules from GitHub
GITHUB_RAW="https://githubusercontent.com"

curl -SL "${GITHUB_RAW}/main.py" -o $BASE_DIR/app/main.py
curl -SL "${GITHUB_RAW}/requirements.txt" -o $BASE_DIR/app/requirements.txt
curl -SL "${GITHUB_RAW}/prometheus.yml" -o $BASE_DIR/prometheus.yml
curl -SL "${GITHUB_RAW}/dashboard.yml" -o $BASE_DIR/dashboard.yml
curl -SL "${GITHUB_RAW}/ik_dashboard.json" -o $BASE_DIR/ik_dashboard.json
curl -SL "${GITHUB_RAW}/docker-compose.yml" -o $BASE_DIR/docker-compose.yml

# 5. Turn on the Container Applications Microservice Architecture
cd $BASE_DIR
docker compose up -d

echo "=== System Is Configured and Listening on Target Ports ==="
