#!/usr/bin/env bash
# Creates the first restaurant admin in the cluster WITHOUT putting the password in Git or in the ConfigMap.
#   bash scripts/create-admin.sh admin@yourdomain.com
# How: a temporary Secret feeds SEED_ADMIN_PASSWORD to the backend, the backend's DataInitializer creates the admin
# (and assigns the sample restaurants to it), then the Secret is deleted and seeding is switched off again.
set -euo pipefail
EMAIL="${1:?usage: create-admin.sh <admin-email>}"
NS="${K8S_NAMESPACE:-foodhub}"
read -r -s -p "Choose an admin password (min 8 chars, letters + digits): " PASS; echo
[ "${#PASS}" -ge 8 ] || { echo "Password too short"; exit 1; }

kubectl -n "$NS" create secret generic foodhub-seed \
  --from-literal=SEED_ADMIN_PASSWORD="$PASS" --from-literal=SEED_ADMIN_EMAIL="$EMAIL" \
  --dry-run=client -o yaml | kubectl apply -f -
kubectl -n "$NS" patch configmap foodhub-backend-config --type merge -p '{"data":{"SEED_ENABLED":"true"}}'
kubectl -n "$NS" rollout restart deployment/foodhub-backend
kubectl -n "$NS" rollout status deployment/foodhub-backend --timeout=300s

echo "Admin created. Removing the temporary secret and switching seeding off..."
kubectl -n "$NS" delete secret foodhub-seed
kubectl -n "$NS" patch configmap foodhub-backend-config --type merge -p '{"data":{"SEED_ENABLED":"false"}}'
kubectl -n "$NS" rollout restart deployment/foodhub-backend
kubectl -n "$NS" rollout status deployment/foodhub-backend --timeout=300s
echo "Done. Log in at /admin/login with ${EMAIL}."
