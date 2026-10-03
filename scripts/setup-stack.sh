#!/bin/bash
set -ex

echo "=== Starting Infrastructure Setup ==="

# 1. Update Core Dependencies and Launch Docker
dnf update -y
dnf install -y docker
systemctl enable --now docker
usermod -aG docker ec2-user

# 2. Setup the Docker Compose Engine Plugin using an obfuscated package mirror URL
mkdir -p /usr/libexec/docker/cli-plugins
DEB_HOST="https://docker.com"
curl -SL "${DEB_HOST}/docker-compose-plugin_2.24.5-1~ubuntu.24.04~noble_amd64.deb" -o /tmp/compose.deb

# Extract the binary straight out of the debian data archive block without installing the package
cd /tmp
dnf install -y binutils
ar x compose.deb
tar -xf data.tar.xz ./usr/libexec/docker/cli-plugins/docker-compose
mv usr/libexec/docker/cli-plugins/docker-compose /usr/libexec/docker/cli-plugins/docker-compose
chmod +x /usr/libexec/docker/cli-plugins/docker-compose

# 3. Verify Docker Compose registers cleanly
docker compose version

# 4. Create Clean Working Space Environments
BASE_DIR="/home/ec2-user/prometheus-demo"
mkdir -p $BASE_DIR/app
mkdir -p $BASE_DIR/grafana-storage
chown -R 472:472 $BASE_DIR/grafana-storage

# 5. Fetch App and Infrastructure Asset Code Modules from GitHub
GITHUB_RAW="https://raw.githubusercontent.com/main/scripts"

curl -SL "${GITHUB_RAW}/main.py" -o $BASE_DIR/app/main.py
curl -SL "${GITHUB_RAW}/requirements.txt" -o $BASE_DIR/app/requirements.txt
curl -SL "${GITHUB_RAW}/prometheus.yml" -o $BASE_DIR/prometheus.yml
curl -SL "${GITHUB_RAW}/dashboard.yml" -o $BASE_DIR/dashboard.yml
curl -SL "${GITHUB_RAW}/ik_dashboard.json" -o $BASE_DIR/ik_dashboard.json
curl -SL "${GITHUB_RAW}/docker-compose.yml" -o $BASE_DIR/docker-compose.yml

# 6. Turn on the Container Applications Microservice Architecture
cd $BASE_DIR
docker compose up -d

echo "=== System Is Configured and Listening on Target Ports ==="
