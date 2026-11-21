# Remote state in S3. The bucket, key and locking settings are supplied at init time so the same code
# serves dev and prod with separate state files:
#   terraform init -backend-config=environments/dev/backend.hcl
terraform {
  backend "s3" {}
}
