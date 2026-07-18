#!/bin/bash
set -euo pipefail

# Log user data execution
exec > >(tee /var/log/user-data.log | logger -t user-data -s 2>/dev/console) 2>&1

echo "========== Starting User Data Script =========="

#################################################
# Update Ubuntu
#################################################

echo "========== Updating Ubuntu package repository========== ..."
apt update -y

#################################################
# Install Java (Required for Jenkins)
#################################################

echo "========== Installing OpenJDK 21========== ..."
apt install -y fontconfig openjdk-21-jre

echo "Verifying Java installation..."
java -version

#################################################
# Install Jenkins LTS
#################################################

echo "Adding Jenkins repository..."
wget -O /etc/apt/keyrings/jenkins-keyring.asc \
https://pkg.jenkins.io/debian-stable/jenkins.io-2026.key

echo "Configuring Jenkins APT repository..."
echo "deb [signed-by=/etc/apt/keyrings/jenkins-keyring.asc]" \
https://pkg.jenkins.io/debian-stable binary/ | \
tee /etc/apt/sources.list.d/jenkins.list > /dev/null

echo "Updating package repository..."
apt update -y

echo "========== Installing Jenkins========== .."
apt install -y jenkins

echo "Enabling Jenkins service..."
systemctl enable jenkins

echo "Starting Jenkins service..."
systemctl start jenkins

#################################################
# Install Docker
#################################################

echo "Installing Docker prerequisites..."
apt install -y ca-certificates curl

echo "Creating Docker keyring directory..."
install -m 0755 -d /etc/apt/keyrings

echo "Downloading Docker GPG key..."
curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
-o /etc/apt/keyrings/docker.asc

chmod a+r /etc/apt/keyrings/docker.asc

echo "Adding Docker repository..."
tee /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
EOF

echo "Updating package repository..."
apt update -y

echo "========== Installing Docker Engine========== ..."
apt install -y \
docker-ce \
docker-ce-cli \
containerd.io \
docker-buildx-plugin \
docker-compose-plugin

echo "Enabling Docker service..."
systemctl enable docker

echo "Starting Docker service..."
systemctl start docker

#################################################
# Docker Permissions
#################################################

echo "Adding ubuntu and jenkins users to Docker group..."
usermod -aG docker ubuntu
usermod -aG docker jenkins

echo "Restarting Jenkins service..."
systemctl restart jenkins

#################################################
# Install Terraform
#################################################

echo "Adding HashiCorp repository..."
wget -O- https://apt.releases.hashicorp.com/gpg | \
gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg

echo "Configuring Terraform repository..."
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(grep -oP '(?<=UBUNTU_CODENAME=).*' /etc/os-release || lsb_release -cs) main" | \
tee /etc/apt/sources.list.d/hashicorp.list

echo "Updating package repository..."
apt update -y

echo "========== Installing Terraform========== ..."
apt install -y terraform

#################################################
# Install AWS CLI v2
#################################################

echo "========== Downloading AWS CLI v2========== ..."
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" \
-o "awscliv2.zip"

echo "Installing unzip..."
apt install -y unzip

echo "Extracting AWS CLI package..."
unzip -q awscliv2.zip

echo "Installing AWS CLI..."
./aws/install

#################################################
# Install SonarQube
#################################################

echo "========== Pulling and starting SonarQube container========== ..."
docker run -d \
--name sonarqube \
-p 9000:9000 \
--restart unless-stopped \
sonarqube:lts-community

#################################################
# Install Trivy
#################################################

echo "Installing Trivy prerequisites..."
apt install -y wget gnupg

echo "Adding Trivy repository..."
wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | \
gpg --dearmor | \
tee /usr/share/keyrings/trivy.gpg > /dev/null

echo "Configuring Trivy repository..."
echo "deb [signed-by=/usr/share/keyrings/trivy.gpg] https://aquasecurity.github.io/trivy-repo/deb generic main" | \
tee /etc/apt/sources.list.d/trivy.list

echo "Updating package repository..."
apt update -y

echo "========== Installing Trivy========== ..."
apt install -y trivy

#################################################
# Verify Installations
#################################################

echo "========== Installed Versions =========="

echo "Java Version:"
java -version

echo "Jenkins Version:"
jenkins --version || true

echo "Docker Version:"
docker --version

echo "Terraform Version:"
terraform version

echo "AWS CLI Version:"
aws --version

echo "Trivy Version:"
trivy --version

echo "========== User Data Completed Successfully =========="
