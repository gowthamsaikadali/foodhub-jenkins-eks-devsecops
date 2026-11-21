#!/usr/bin/env bash
# One-time cluster setup. Run from your admin machine (Windows: use WSL2) AFTER terraform apply.
#   cd foodhub-devsecops && bash scripts/bootstrap-cluster.sh dev
# Installs: namespace, metrics-server, AWS Load Balancer Controller, External Secrets Operator, then applies the
# secrets, network policies and RBAC. Chart versions are not pinned here: after a successful run, record them with
# "helm list -A" and set the *_CHART_VERSION variables below so future runs are reproducible.
set -euo pipefail

ENVIRONMENT="${1:-dev}"
TF_DIR="terraform"
LBC_CHART_VERSION="${LBC_CHART_VERSION:-}"
ESO_CHART_VERSION="${ESO_CHART_VERSION:-}"
METRICS_SERVER_CHART_VERSION="${METRICS_SERVER_CHART_VERSION:-}"

tfout() { terraform -chdir="$TF_DIR" output -raw "$1"; }
ver()   { [ -n "$1" ] && echo "--version $1" || true; }

echo "==> Reading Terraform outputs"
REGION="$(tfout region)"
CLUSTER="$(tfout eks_cluster_name)"
VPC_ID="$(tfout vpc_id)"

echo "==> Pointing kubectl at ${CLUSTER}"
aws eks update-kubeconfig --region "$REGION" --name "$CLUSTER"
kubectl get nodes

echo "==> Namespace"
kubectl apply -f kubernetes/namespace.yaml

echo "==> metrics-server (needed by the Horizontal Pod Autoscalers)"
helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/ >/dev/null
helm repo update >/dev/null
helm upgrade --install metrics-server metrics-server/metrics-server -n kube-system $(ver "$METRICS_SERVER_CHART_VERSION") --wait

echo "==> AWS Load Balancer Controller (IAM role comes from the Pod Identity association created by Terraform)"
helm repo add eks https://aws.github.io/eks-charts >/dev/null
helm repo update >/dev/null
helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller -n kube-system \
  $(ver "$LBC_CHART_VERSION") \
  --set clusterName="$CLUSTER" \
  --set region="$REGION" \
  --set vpcId="$VPC_ID" \
  --set serviceAccount.create=true \
  --set serviceAccount.name=aws-load-balancer-controller \
  --wait

echo "==> External Secrets Operator"
helm repo add external-secrets https://charts.external-secrets.io >/dev/null
helm repo update >/dev/null
helm upgrade --install external-secrets external-secrets/external-secrets -n external-secrets --create-namespace \
  $(ver "$ESO_CHART_VERSION") \
  --set installCRDs=true \
  --set serviceAccount.name=external-secrets \
  --wait

echo "==> Secret store + ExternalSecret"
bash scripts/apply-external-secrets.sh

echo "==> Network policies, RBAC, backend ConfigMap and ServiceAccount"
kubectl apply -f kubernetes/network-policies/
kubectl apply -f kubernetes/rbac/
kubectl apply -f kubernetes/backend/serviceaccount.yaml -f kubernetes/backend/configmap.yaml

echo
echo "Cluster bootstrap finished. Next: run the Jenkins application pipeline (or scripts/deploy.sh) to deploy the app."
kubectl get pods -A
