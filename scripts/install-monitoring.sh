#!/usr/bin/env bash
# Installs kube-prometheus-stack, then the FoodHub ServiceMonitor, alert rules and Grafana dashboards.
#   bash scripts/install-monitoring.sh
set -euo pipefail
CHART_VERSION="${KPS_CHART_VERSION:-}"     # pin after the first successful install (helm list -n monitoring)

kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -

# Random Grafana admin password, stored only in the cluster. Read it later with the command printed at the end.
if ! kubectl -n monitoring get secret grafana-admin >/dev/null 2>&1; then
  kubectl -n monitoring create secret generic grafana-admin \
    --from-literal=admin-user=admin \
    --from-literal=admin-password="$(openssl rand -base64 24 | tr -d '/+=' | cut -c1-24)"
fi

helm repo add prometheus-community https://prometheus-community.github.io/helm-charts >/dev/null
helm repo update >/dev/null
helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  -n monitoring ${CHART_VERSION:+--version "$CHART_VERSION"} \
  -f monitoring/kube-prometheus-stack-values.yaml --wait --timeout 10m

echo "==> FoodHub ServiceMonitor and alert rules"
kubectl apply -f kubernetes/monitoring/

echo "==> Grafana dashboards (ConfigMaps labelled grafana_dashboard=1 are auto-imported)"
for f in monitoring/dashboards/*.json; do
  name="dashboard-$(basename "$f" .json)"
  kubectl -n monitoring create configmap "$name" --from-file="$(basename "$f")=$f" --dry-run=client -o yaml \
    | kubectl label --local -f - grafana_dashboard=1 -o yaml \
    | kubectl apply -f -
done

echo
echo "Monitoring installed."
echo "Grafana password : kubectl -n monitoring get secret grafana-admin -o jsonpath='{.data.admin-password}' | base64 -d; echo"
echo "Open Grafana     : kubectl -n monitoring port-forward svc/kube-prometheus-stack-grafana 3000:80   then http://localhost:3000"
echo "Open Prometheus  : kubectl -n monitoring port-forward svc/kube-prometheus-stack-prometheus 9090:9090"
