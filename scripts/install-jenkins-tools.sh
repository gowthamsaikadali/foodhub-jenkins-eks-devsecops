#!/usr/bin/env bash
# Run ON THE JENKINS EC2 (Ubuntu 24.04) as a user with sudo:   bash install-jenkins-tools.sh
# Installs Jenkins and every tool the pipelines call. Safe to re-run.
set -euo pipefail

K8S_MINOR="${K8S_MINOR:-v1.36}"             # kubectl should be within one minor version of the EKS cluster
SONAR_SCANNER_VERSION="${SONAR_SCANNER_VERSION:-7.0.2.4839}"   # check https://docs.sonarsource.com/sonarqube-server/latest/analyzing-source-code/scanners/sonarscanner/

echo "==> 1/10 Base packages"
sudo apt-get update -y
sudo apt-get install -y ca-certificates curl gnupg unzip zip git jq gettext-base apt-transport-https software-properties-common wget

echo "==> 2/10 Java 21 (Jenkins and Maven need it)"
sudo apt-get install -y fontconfig openjdk-21-jdk

echo "==> 3/10 Jenkins (LTS)"
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key -o /etc/apt/keyrings/jenkins-keyring.asc
echo "deb [signed-by=/etc/apt/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/" | sudo tee /etc/apt/sources.list.d/jenkins.list >/dev/null
sudo apt-get update -y
sudo apt-get install -y jenkins

echo "==> 4/10 Docker"
if ! command -v docker >/dev/null; then
  curl -fsSL https://get.docker.com | sudo sh
fi
sudo usermod -aG docker jenkins
sudo usermod -aG docker "$USER" || true

echo "==> 5/10 AWS CLI v2"
if ! command -v aws >/dev/null; then
  curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip
  unzip -q -o /tmp/awscliv2.zip -d /tmp
  sudo /tmp/aws/install
fi

echo "==> 6/10 Terraform (HashiCorp apt repository)"
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor --yes -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(. /etc/os-release && echo "$VERSION_CODENAME") main" | sudo tee /etc/apt/sources.list.d/hashicorp.list >/dev/null
sudo apt-get update -y
sudo apt-get install -y terraform

echo "==> 7/10 kubectl ${K8S_MINOR} and Helm"
curl -fsSL "https://pkgs.k8s.io/core:/stable:/${K8S_MINOR}/deb/Release.key" | sudo gpg --dearmor --yes -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/${K8S_MINOR}/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list >/dev/null
sudo apt-get update -y
sudo apt-get install -y kubectl
if ! command -v helm >/dev/null; then
  curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
fi

echo "==> 8/10 Maven and Node.js 20"
sudo apt-get install -y maven
if ! command -v node >/dev/null; then
  curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
  sudo apt-get install -y nodejs
fi

echo "==> 9/10 Trivy (Aqua Security apt repository)"
curl -fsSL https://aquasecurity.github.io/trivy-repo/deb/public.key | sudo gpg --dearmor --yes -o /usr/share/keyrings/trivy.gpg
echo "deb [signed-by=/usr/share/keyrings/trivy.gpg] https://aquasecurity.github.io/trivy-repo/deb generic main" | sudo tee /etc/apt/sources.list.d/trivy.list >/dev/null
sudo apt-get update -y
sudo apt-get install -y trivy

echo "==> 10/10 SonarScanner CLI ${SONAR_SCANNER_VERSION}"
if [ ! -d /opt/sonar-scanner ]; then
  curl -fsSL "https://binaries.sonarsource.com/Distribution/sonar-scanner-cli/sonar-scanner-cli-${SONAR_SCANNER_VERSION}-linux-x64.zip" -o /tmp/sonar-scanner.zip
  sudo unzip -q -o /tmp/sonar-scanner.zip -d /opt
  sudo mv /opt/sonar-scanner-*-linux-x64 /opt/sonar-scanner
  sudo ln -sf /opt/sonar-scanner/bin/sonar-scanner /usr/local/bin/sonar-scanner
fi

sudo systemctl enable --now jenkins
sudo systemctl restart jenkins

echo
echo "================ Installed versions ================"
java -version 2>&1 | head -1
git --version
docker --version
aws --version
terraform version | head -1
kubectl version --client | head -1
helm version --short
mvn -v | head -1
node -v
trivy --version | head -1
sonar-scanner --version 2>&1 | grep -i "SonarScanner" | head -1 || true
echo "===================================================="
echo "Jenkins first-time password:"
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
