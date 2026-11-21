#!/usr/bin/env bash
# Logs in to ECR with the instance-profile credentials and pushes both images with two tags each.
#   ECR_REGISTRY=... BUILD_TAG=build-25 SHA_TAG=sha-1a2b3c4 bash scripts/ecr-push.sh
# Repositories use IMMUTABLE tags. A tag that already exists can never be overwritten, so an existing tag is skipped
# (this happens when the same commit is built twice).
set -euo pipefail
: "${ECR_REGISTRY:?}"; : "${BUILD_TAG:?}"; : "${SHA_TAG:?}"
REGION="${AWS_REGION:-ap-south-1}"

# aws ecr get-login-password   -> prints a temporary (12 hour) password for ECR, using the EC2 instance role
# docker login --username AWS  -> "AWS" is the fixed username ECR expects
# --password-stdin             -> reads the password from the pipe so it never appears in the process list
aws ecr get-login-password --region "$REGION" | docker login --username AWS --password-stdin "$ECR_REGISTRY"

for app in frontend backend; do
  repo="foodhub-${app}"
  for tag in "$BUILD_TAG" "$SHA_TAG"; do
    if aws ecr describe-images --region "$REGION" --repository-name "$repo" --image-ids imageTag="$tag" >/dev/null 2>&1; then
      echo "Tag ${repo}:${tag} already exists in ECR (immutable). Skipping."
    else
      docker push "${ECR_REGISTRY}/${repo}:${tag}"
    fi
  done
done
