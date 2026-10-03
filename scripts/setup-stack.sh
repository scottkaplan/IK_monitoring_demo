#!/bin/bash
set -ex

echo "=== Starting Cloud-Native Infrastructure Setup ==="

# 1. Install and Start Standard Docker Engine from AWS
dnf update -y
dnf install -y docker
systemctl enable --now docker
usermod -aG docker ec2-user

# 2. Create a Global 'docker-compose' Alias Script using the Container Image
# This eliminates ALL binary downloads, dynamic pathing, and pip dependency conflicts.
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
mkdir -p /home/ec2-user/prometheus-demo/app
mkdir -p /home/ec2-user/prometheus-demo/grafana-storage
chown -R 472:472 /home/ec2-user/prometheus-demo/grafana-storage

# 5. Fetch Your 5 Asset Configurations from GitHub
GITHUB_RAW="https://raw.githubusercontent.com/scottkaplan/IK_monitoring_demo/main/scripts"

curl -SL "${GITHUB_RAW}/main.py" -o /home/ec2-user/prometheus-demo/app/main.py
curl -SL "${GITHUB_RAW}/requirements.txt" -o /home/ec2-user/prometheus-demo/app/requirements.txt
curl -SL "${GITHUB_RAW}/prometheus.yml" -o /home/ec2-user/prometheus-demo/prometheus.yml
curl -SL "${GITHUB_RAW}/dashboard.yml" -o /home/ec2-user/prometheus-demo/dashboard.yml
curl -SL "${GITHUB_RAW}/ik_dashboard.json" -o /home/ec2-user/prometheus-demo/ik_dashboard.json
curl -SL "${GITHUB_RAW}/docker-compose.yml" -o /home/ec2-user/prometheus-demo/docker-compose.yml
curl -SL "${GITHUB_RAW}/generate_traffic.py" -o /home/ec2-user/prometheus-demo/generate_traffic.py

# 6. Jump into the workspace and run the stack
cd /home/ec2-user/prometheus-demo
docker-compose up -d

echo "=== System Up and Listening ==="
