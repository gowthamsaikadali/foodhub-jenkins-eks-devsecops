#!/usr/bin/env bash
# Renders kubernetes/external-secrets/*.yaml with the secret NAMES from terraform output and applies them.
# Only names are used here; no secret VALUE ever passes through this script.
set -euo pipefail
TF_DIR="${TF_DIR:-terraform}"
tfout() { terraform -chdir="$TF_DIR" output -raw "$1"; }

export DB_MASTER_SECRET_NAME="$(tfout db_master_secret_name)"
export DB_CONNECTION_SECRET_NAME="$(tfout db_connection_secret_name)"
export JWT_SECRET_NAME="$(tfout jwt_secret_name)"

kubectl apply -f kubernetes/external-secrets/secret-store.yaml
envsubst '${DB_MASTER_SECRET_NAME} ${DB_CONNECTION_SECRET_NAME} ${JWT_SECRET_NAME}' \
  < kubernetes/external-secrets/external-secret.yaml | kubectl apply -f -

echo "Waiting for the Kubernetes Secret foodhub-backend-secrets to be created..."
for i in $(seq 1 30); do
  if kubectl -n foodhub get secret foodhub-backend-secrets >/dev/null 2>&1; then
    echo "OK: secret exists (keys: $(kubectl -n foodhub get secret foodhub-backend-secrets -o jsonpath='{.data}' | python3 -c 'import sys,json;print(",".join(json.load(sys.stdin).keys()))'))"
    exit 0
  fi
  sleep 5
done
echo "Secret was not created. Inspect with: kubectl -n foodhub describe externalsecret foodhub-backend-secrets"
exit 1
