#!/usr/bin/env bash
# Run ON THE SONARQUBE EC2 (Ubuntu 24.04):   bash install-sonarqube.sh
# Runs SonarQube Community Build + PostgreSQL in Docker Compose. Data is kept in Docker volumes.
set -euo pipefail

echo "==> 1/4 Docker"
sudo apt-get update -y
sudo apt-get install -y ca-certificates curl openssl
if ! command -v docker >/dev/null; then
  curl -fsSL https://get.docker.com | sudo sh
fi
sudo usermod -aG docker "$USER" || true

echo "==> 2/4 Kernel settings that SonarQube's embedded Elasticsearch requires"
sudo tee /etc/sysctl.d/99-sonarqube.conf >/dev/null <<'SYSCTL'
vm.max_map_count=524288
fs.file-max=131072
SYSCTL
sudo sysctl --system >/dev/null

echo "==> 3/4 Compose file with a random database password"
sudo mkdir -p /opt/sonarqube
cd /opt/sonarqube
if [ ! -f .env ]; then
  echo "POSTGRES_PASSWORD=$(openssl rand -hex 24)" | sudo tee .env >/dev/null
  sudo chmod 600 .env
fi
sudo tee docker-compose.yml >/dev/null <<'YAML'
services:
  db:
    image: postgres:16-alpine
    restart: unless-stopped
    environment:
      POSTGRES_USER: sonar
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      POSTGRES_DB: sonarqube
    volumes:
      - pg_data:/var/lib/postgresql/data
  sonarqube:
    image: sonarqube:community
    restart: unless-stopped
    depends_on: [db]
    ports:
      - "9000:9000"
    environment:
      SONAR_JDBC_URL: jdbc:postgresql://db:5432/sonarqube
      SONAR_JDBC_USERNAME: sonar
      SONAR_JDBC_PASSWORD: ${POSTGRES_PASSWORD}
    volumes:
      - sonar_data:/opt/sonarqube/data
      - sonar_extensions:/opt/sonarqube/extensions
      - sonar_logs:/opt/sonarqube/logs
volumes:
  pg_data:
  sonar_data:
  sonar_extensions:
  sonar_logs:
YAML

echo "==> 4/4 Start"
sudo docker compose up -d
echo "Waiting for SonarQube to become ready (first start takes 2-4 minutes)..."
for i in $(seq 1 60); do
  if curl -fsS http://localhost:9000/api/system/status 2>/dev/null | grep -q '"status":"UP"'; then
    echo "SonarQube is UP. Open http://<this-server-ip>:9000   (first login: admin / admin, you must change it)"
    exit 0
  fi
  sleep 10
done
echo "SonarQube did not report UP in 10 minutes. Check: sudo docker compose -f /opt/sonarqube/docker-compose.yml logs --tail=100"
exit 1
