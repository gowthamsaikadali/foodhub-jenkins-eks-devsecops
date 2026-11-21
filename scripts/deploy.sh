#!/usr/bin/env bash
# Deploys the app to EKS with exact image tags. Called by the Jenkins pipeline (also usable by hand).
#   ECR_REGISTRY=123456789012.dkr.ecr.ap-south-1.amazonaws.com IMAGE_TAG=build-25 bash scripts/deploy.sh
set -euo pipefail

: "${ECR_REGISTRY:?ECR_REGISTRY is required}"
: "${IMAGE_TAG:?IMAGE_TAG is required}"
if [ "$IMAGE_TAG" = "latest" ]; then
  echo "Refusing to deploy the 'latest' tag. Use an immutable tag such as build-25." >&2
  exit 1
fi
NS="${K8S_NAMESPACE:-foodhub}"
INGRESS_FILE="${INGRESS_FILE:-kubernetes/ingress/ingress.yaml}"

export ECR_REGISTRY IMAGE_TAG
render() { envsubst '${ECR_REGISTRY} ${IMAGE_TAG}' < "$1"; }

echo "Deploying tag ${IMAGE_TAG} from ${ECR_REGISTRY} to namespace ${NS}"

# Static objects first, then the workloads
kubectl apply -f kubernetes/backend/serviceaccount.yaml -f kubernetes/backend/configmap.yaml
kubectl apply -f kubernetes/backend/service.yaml -f kubernetes/frontend/service.yaml
render kubernetes/backend/deployment.yaml  | kubectl apply -f -
render kubernetes/frontend/deployment.yaml | kubectl apply -f -
kubectl apply -f kubernetes/autoscaling/
kubectl apply -f "$INGRESS_FILE"
kubectl apply -f kubernetes/network-policies/

# Record WHY this revision exists (shown by "kubectl rollout history")
kubectl -n "$NS" annotate deployment/foodhub-backend  kubernetes.io/change-cause="image ${IMAGE_TAG}" --overwrite
kubectl -n "$NS" annotate deployment/foodhub-frontend kubernetes.io/change-cause="image ${IMAGE_TAG}" --overwrite
