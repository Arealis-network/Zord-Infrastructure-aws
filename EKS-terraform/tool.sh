#!/bin/bash
set -euo pipefail

#----------------------------- Update system -----------------------------

yum update -y
yum install -y unzip curl git

#----------------------------- Install kubectl -----------------------------

curl -LO "https://dl.k8s.io/release/$(curl -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
mv kubectl /usr/local/bin/

kubectl version --client

#----------------------------- Install eksctl -----------------------------

curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz"
| tar xz -C /tmp
mv /tmp/eksctl /usr/local/bin

eksctl version

#----------------------------- Install Helm -----------------------------

curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
helm version

#----------------------------- Install AWS CLI -----------------------------

curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
./aws/install
rm -rf awscliv2.zip aws

aws --version

#----------------------------- Install Docker -----------------------------

yum install -y docker
systemctl enable docker
systemctl start docker

usermod -aG docker ec2-user || true
chmod 666 /var/run/docker.sock
docker --version

#----------------------------- Install Jenkins -----------------------------

docker volume create jenkins_home
docker rm -f jenkins >/dev/null 2>&1 || true

docker run -d
--name jenkins
--restart unless-stopped
-p 7777:8080
-p 50000:50000
-v jenkins_home:/var/jenkins_home
-v /var/run/docker.sock:/var/run/docker.sock
jenkins/jenkins

Wait for Jenkins password

for i in {1..30}; do
if docker exec jenkins test -f /var/jenkins_home/secrets/initialAdminPassword; then
break
fi
sleep 10
done


sudo docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword
docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword | tee /home/ec2-user/jenkins-initial-admin-password


#----------------------------- Install SonarQube -----------------------------

tee /etc/sysctl.d/99-sonarqube.conf > /dev/null <<'EOF'
vm.max_map_count=524288
fs.file-max=131072
EOF

sysctl --system

docker volume create sonarqube_data
docker volume create sonarqube_logs
docker volume create sonarqube_extensions

docker rm -f sonarqube >/dev/null 2>&1 || true

docker run -d
--name sonarqube
--restart unless-stopped
-p 9000:9000
-v sonarqube_data:/opt/sonarqube/data
-v sonarqube_logs:/opt/sonarqube/logs
-v sonarqube_extensions:/opt/sonarqube/extensions
sonarqube

#----------------------------- Helm Repo -----------------------------

helm repo add autoscaler https://kubernetes.github.io/autoscaler
helm repo update

#----------------------------- Done -----------------------------

echo "Jenkins: http://:7777"
echo "SonarQube: http://:9000"
echo "Jenkins password saved at /home/ec2-user/jenkins-initial-admin-password"
