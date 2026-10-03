#!/bin/bash
set -ex

echo "=== Starting Cloud-Native Infrastructure Setup ==="

# 1. Install and Start Standard Docker Engine from AWS
dnf update -y
dnf install -y docker
systemctl enable --now docker
usermod -aG docker ec2-user

# 2. Create a Global 'docker-compose' Alias Script using the Container Image
cat << 'EOF' > /usr/local/bin/docker-compose
#!/bin/bash
docker run --rm \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v "$PWD:$PWD" \
  -w "$PWD" \
  docker/compose:latest "$@"
EOF
chmod +x /usr/local/bin/docker-compose

# 3. Create the native Docker CLI Plugin alias mapping layer
mkdir -p /usr/libexec/docker/cli-plugins
ln -sf /usr/local/bin/docker-compose /usr/libexec/docker/cli-plugins/docker-compose

# 4. Explicitly Force-Create the Project Directories
TARGET_DIR="/home/ec2-user/prometheus-demo"
mkdir -p $TARGET_DIR/app
mkdir -p $TARGET_DIR/grafana-storage
chown -R 472:472 $TARGET_DIR/grafana-storage

# 5. Fetch Your 5 Asset Configurations from GitHub (USING YOUR EXACT SPECIFIED URL)
GITHUB_RAW="https://raw.githubusercontent.com/scottkaplan/IK_monitoring_demo/main/scripts"

curl -SL "${GITHUB_RAW}/main.py" -o $TARGET_DIR/app/main.py
curl -SL "${GITHUB_RAW}/requirements.txt" -o $TARGET_DIR/app/requirements.txt
curl -SL "${GITHUB_RAW}/prometheus.yml" -o $TARGET_DIR/prometheus.yml
curl -SL "${GITHUB_RAW}/dashboard.yml" -o $TARGET_DIR/dashboard.yml
curl -SL "${GITHUB_RAW}/ik_dashboard.json" -o $TARGET_DIR/ik_dashboard.json
curl -SL "${GITHUB_RAW}/docker-compose.yml" -o $TARGET_DIR/docker-compose.yml

# 6. Jump into the workspace and run the stack
cd $TARGET_DIR
docker-compose up -d --force-recreate

echo "=== System Up and Listening ==="
