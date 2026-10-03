#!/bin/bash
set -ex

echo "=== Starting Infrastructure Setup ==="

# 1. Update Core Dependencies and Install Docker + Compose Plugin via DNF
dnf update -y
dnf install -y docker
systemctl enable --now docker
usermod -aG docker ec2-user

# 2. Verify Docker Compose registers cleanly (Logs to your execution file)
mkdir -p /usr/libexec/docker/cli-plugins
DEB_HOST="https://docker.com"
curl -SL "${DEB_HOST}/docker-compose-plugin_2.24.5-1~ubuntu.24.04~noble_amd64.deb" -o /tmp/compose.deb

# 3. Create Clean Working Space Environments
BASE_DIR="/home/ec2-user/prometheus-demo"
mkdir -p $BASE_DIR/app
mkdir -p $BASE_DIR/grafana-storage
chown -R 472:472 $BASE_DIR/grafana-storage

# 4. Fetch App and Infrastructure Asset Code Modules from GitHub
GITHUB_RAW="https://raw.githubusercontent.com/main/scripts"

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
