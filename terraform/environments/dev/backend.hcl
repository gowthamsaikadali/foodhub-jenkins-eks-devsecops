# Used with:  terraform init -backend-config=environments/dev/backend.hcl
# Replace the bucket name with the one printed by terraform/bootstrap.
bucket       = "foodhub-tfstate-REPLACE_ACCOUNT_ID-ap-south-1"
key          = "foodhub/dev/terraform.tfstate"
region       = "ap-south-1"
encrypt      = true
use_lockfile = true # S3-native locking: a .tflock object is created next to the state while someone runs apply
