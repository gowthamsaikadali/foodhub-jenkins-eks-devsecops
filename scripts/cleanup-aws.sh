#!/usr/bin/env bash
# Phase 16 cleanup helper. Removes Kubernetes objects that create AWS resources OUTSIDE Terraform (the ALB), then
# prints what is left. Run this BEFORE "terraform destroy", otherwise the ALB and its security groups block the VPC deletion.
set -euo pipefail
NS="${K8S_NAMESPACE:-foodhub}"
echo "Deleting the Ingress (this removes the Application Load Balancer)..."
kubectl -n "$NS" delete ingress --all --ignore-not-found
echo "Waiting 90 seconds for the controller to delete the ALB..."
sleep 90
echo "Uninstalling monitoring (releases any load balancers/volumes)..."
helm -n monitoring uninstall kube-prometheus-stack 2>/dev/null || true
echo
echo "Load balancers still present in the region (should be empty):"
aws elbv2 describe-load-balancers --query 'LoadBalancers[].LoadBalancerName' --output text || true
echo
echo "Now run:  cd terraform && terraform destroy -var-file=environments/dev/dev.tfvars"
