#!/usr/bin/env bash
# Calls the application through the load balancer and fails if it is not healthy.
#   bash scripts/health-check.sh [namespace]
set -euo pipefail
NS="${1:-foodhub}"
echo "Waiting for the load balancer hostname..."
HOST=""
for i in $(seq 1 40); do
  HOST="$(kubectl -n "$NS" get ingress foodhub -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || true)"
  [ -n "$HOST" ] && break
  sleep 15
done
[ -n "$HOST" ] || { echo "No load balancer hostname after 10 minutes"; exit 1; }
SCHEME="${SCHEME:-http}"
echo "ALB: ${HOST}"

check() {
  local url="$1" want="$2" code
  for i in $(seq 1 30); do          # a brand-new ALB needs a few minutes before targets are healthy
    code="$(curl -ks -o /dev/null -w '%{http_code}' --max-time 10 "$url" || true)"
    if [ "$code" = "$want" ]; then echo "OK   ${url} -> ${code}"; return 0; fi
    sleep 10
  done
  echo "FAIL ${url} -> ${code} (expected ${want})"; return 1
}

check "${SCHEME}://${HOST}/" 200
check "${SCHEME}://${HOST}/api/restaurants" 200
check "${SCHEME}://${HOST}/api/orders/my-orders" 401   # protected endpoint must refuse anonymous callers
echo "All health checks passed."
