#!/usr/bin/env bash
# Rolls the app back to the previous (or a given) revision.
#   bash scripts/rollback.sh              # previous revision
#   bash scripts/rollback.sh 7            # a specific revision number from "kubectl rollout history"
set -euo pipefail
NS="${K8S_NAMESPACE:-foodhub}"
REV="${1:-}"
for d in foodhub-backend foodhub-frontend; do
  echo "--- $d history ---"
  kubectl -n "$NS" rollout history deployment/"$d" | tail -n 6
  if [ -n "$REV" ]; then
    kubectl -n "$NS" rollout undo deployment/"$d" --to-revision="$REV"
  else
    kubectl -n "$NS" rollout undo deployment/"$d"
  fi
  kubectl -n "$NS" rollout status deployment/"$d" --timeout=300s
done
echo "Rollback finished."
