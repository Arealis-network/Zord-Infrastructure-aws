#!/bin/bash
set -euo pipefail

# Update system
yum update -y

# ----------------------------- Install kubectl -----------------------------
curl -o /tmp/kubectl https://amazon-eks.s3.us-west-2.amazonaws.com/1.19.6/2021-01-05/bin/linux/amd64/kubectl
chmod +x /tmp/kubectl
mv /tmp/kubectl /usr/local/bin/kubectl

# Verify kubectl
kubectl version --client || true

# ----------------------------- Install eksctl -------------------------------
curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" \
| tar xz -C /tmp

mv /tmp/eksctl /usr/local/bin/eksctl

# Verify eksctl
eksctl version || true

# ----------------------------- Install helm ---------------------------------
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Verify helm
helm version || true


# Install MariaDB
sudo yum install -y mariadb105-server
sudo systemctl start mariadb
sudo systemctl enable mariadb
mysql --version 
#systemctl status mariadb


# Install PostgreSQL 
sudo yum install -y postgresql15 postgresql15-server
sudo /usr/pgsql-15/bin/postgresql-15-setup initdb
sudo systemctl enable postgresql-15
sudo systemctl start postgresql-15
psql --version

# Install AWS CLI v2
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
rm -rf awscliv2.zip aws

# Install Docker
sudo yum install -y docker
sudo systemctl enable docker
sudo systemctl start docker
sudo usermod -aG docker ec2-user || true
docker --version || true

# Install Git
sudo yum install -y git
git --version || true

# ----------------------------- Install Jenkins ------------------------------
sudo docker volume create jenkins_home
sudo docker rm -f jenkins >/dev/null 2>&1 || true
sudo docker pull jenkins/jenkins:lts-jdk21
sudo docker run -d \
  --name jenkins \
  --restart unless-stopped \
  -p 7777:8080 \
  -p 50000:50000 \
  -v jenkins_home:/var/jenkins_home \
  jenkins/jenkins:lts-jdk21

# Wait for Jenkins to create the initial admin password inside the container.
for i in {1..30}; do
  if sudo docker exec jenkins test -f /var/jenkins_home/secrets/initialAdminPassword; then
    break
  fi
  sleep 10
done

if sudo docker exec jenkins test -f /var/jenkins_home/secrets/initialAdminPassword; then
  sudo docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword > /home/ec2-user/jenkins-initial-admin-password
  sudo chown ec2-user:ec2-user /home/ec2-user/jenkins-initial-admin-password
fi
sudo docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword
# ----------------------------- Install SonarQube ---------------------------
sudo tee /etc/sysctl.d/99-sonarqube.conf > /dev/null <<'EOF'
vm.max_map_count=524288
fs.file-max=131072
EOF
sudo sysctl --system || true

sudo docker volume create sonarqube_data
sudo docker volume create sonarqube_logs
sudo docker volume create sonarqube_extensions
sudo docker rm -f sonarqube >/dev/null 2>&1 || true
sudo docker pull sonarqube:lts-community
sudo docker run -d \
  --name sonarqube \
  --restart unless-stopped \
  -p 9000:9000 \
  -v sonarqube_data:/opt/sonarqube/data \
  -v sonarqube_logs:/opt/sonarqube/logs \
  -v sonarqube_extensions:/opt/sonarqube/extensions \
  sonarqube:lts-community

sudo docker ps || true
echo "Jenkins Docker container is configured on port 7777"
echo "Initial admin password file: /home/ec2-user/jenkins-initial-admin-password"
echo "SonarQube Docker container is configured on port 9000"
echo "SonarQube default login: admin / admin"

helm repo add autoscaler https://kubernetes.github.io/autoscaler
helm repo update
