# PHASE 7: AWS Preparation

Cost: account is free. Phase ends with a **budget alarm**; the S3 state bucket costs a few rupees per month. (INR figures in this guide use roughly ₹88 per US$1; check today's rate. All are estimates; see `docs/COST.md`.)

---

### A. What are we doing?
Preparing your AWS account safely: MFA on the root user, a non-root admin identity, AWS CLI configured, a budget alarm, and the S3 bucket that will hold Terraform state.

### B. Why are we doing it?
Mistakes at this stage are the expensive ones: a leaked root key or an unnoticed running cluster can cost thousands of rupees. Security and cost guardrails come **before** any infrastructure.

### C. How does it work?
* **Root user**: the email you signed up with, can do everything and cannot be restricted. Use it only to create the admin identity, then lock it away with MFA.
* **IAM user / role**: a restricted identity for daily work. Production teams use IAM Identity Center (SSO); a single learner can use one IAM user with MFA.
* **AWS CLI profile**: stores access keys locally in `~/.aws/credentials` (outside the repository).
* **Budget**: emails you when forecast or actual spend crosses limits.
* **Terraform state**: a file recording what Terraform built. It must be shared, versioned and locked, so we store it in S3 (versioned, encrypted, public access blocked). The Terraform in `terraform/bootstrap/` creates that bucket, with local state because it is the chicken before the egg.

### D. Where should I execute it?
AWS Console (browser) for steps 1-3, then **Windows local machine (WSL2)** for the rest.

### E. Which directory should I be in?
```bash
cd foodhub-devsecops/terraform/bootstrap
```
(for the Terraform part only)

### F. Which file should I create?
`terraform/bootstrap/terraform.tfvars` (never committed; ignored by `.gitignore`):
```bash
cp terraform.tfvars.example terraform.tfvars
```

### G. Complete code
`terraform/bootstrap/main.tf` is complete in the zip. `terraform.tfvars`:
```hcl
budget_email = "your-real-email@example.com"
# monthly_budget_usd = 100   # optional: alarm threshold in US dollars (default is set in the file)
```

### H. Explain the code
`bootstrap/main.tf` creates:
* `aws_s3_bucket` named `foodhub-tfstate-<account id>-ap-south-1`, with `prevent_destroy = true` (you cannot lose it by accident).
* **Versioning**: every state revision is kept, so a bad apply can be recovered.
* **Encryption** (AES-256) and **public access block**: state may contain sensitive attributes.
* A bucket policy denying non-TLS access.
* `aws_budgets_budget`: monthly limit with alerts at 50%, 80% and 100% actual and 100% forecast, emailed to you.

### I. Execute commands
**1. Secure the root user (browser).** Console > top-right account menu > Security credentials > Assign MFA device (authenticator app). Do not create root access keys.

**2. Create your admin user (browser).** IAM > Users > Create user `foodhub-admin`; attach the AWS managed policy `AdministratorAccess` (learning account; in a company you would scope this down); enable console access and **MFA** for it.

**3. Create an access key for the CLI (browser).** IAM > Users > foodhub-admin > Security credentials > Create access key > "Command Line Interface". Download or copy it once. Treat it like a password.

**4. Install the AWS CLI v2 (WSL2).**
```bash
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o awscliv2.zip
```
```bash
unzip awscliv2.zip && sudo ./aws/install
```
```bash
aws --version
```
**5. Configure the profile.** Enter the key, the secret, region `ap-south-1`, output `json`.
```bash
aws configure --profile foodhub
```
```bash
export AWS_PROFILE=foodhub
```
**6. Prove who you are.**
```bash
aws sts get-caller-identity
```
**7. Install Terraform** (version 1.10 or newer; follow https://developer.hashicorp.com/terraform/install for Ubuntu), then:
```bash
terraform version
```
**8. Create the state bucket and budget.**
```bash
cd terraform/bootstrap
```
```bash
terraform init
```
```bash
terraform plan
```
Read the plan: it must show only the S3 bucket pieces and the budget. Then:
```bash
terraform apply
```
(type `yes`). Note the printed bucket name.

**9. Find your public IP** (needed for Phase 8):
```bash
curl -s https://checkip.amazonaws.com
```
**10. Confirm the budget email** (AWS sends a confirmation mail for SNS/Budget notifications in some setups; click it if received).

### J. Expected output
* Step 6 prints JSON with `Account`, `UserId` and an `Arn` ending `user/foodhub-admin` (values are yours).
* Step 8 ends with `Apply complete! Resources: N added` and outputs the bucket name `foodhub-tfstate-<12-digit-account-id>-ap-south-1`.

### K. Verification
```bash
aws s3 ls | grep foodhub-tfstate
```
```bash
aws s3api get-bucket-versioning --bucket <bucket-name>
```
must show `"Status": "Enabled"`.
Console > Billing > Budgets lists your budget. Console > IAM shows MFA enabled for root and for the admin user. Also enable **Billing > Billing preferences > receive alerts**.

### L. Troubleshooting
| Error | Fix |
|---|---|
| `InvalidClientTokenId` / `SignatureDoesNotMatch` | Wrong or inactive key; re-run `aws configure --profile foodhub`; check no stray spaces. |
| `Unable to locate credentials` | `export AWS_PROFILE=foodhub` in this terminal (variables are per terminal). |
| `BucketAlreadyExists` | Names are global; change `bucket_name` in `main.tf` locals only if the name is taken (it includes your account id, so this is rare). |
| `Error: Unsupported Terraform Core version` | Upgrade Terraform to 1.10+. |
| Budget API access denied | Billing access for IAM users must be activated by the root user: Account > IAM user and role access to Billing information. |
| Terraform asks for `budget_email` | You did not create `terraform.tfvars` in this folder. |

### M. Completion checklist
- [ ] Root has MFA and no access keys.
- [ ] `foodhub-admin` has MFA; CLI profile works (`sts get-caller-identity`).
- [ ] State bucket exists with versioning enabled.
- [ ] A monthly budget with email alerts exists.
- [ ] I know my public IP and that bootstrap state file (`terraform.tfstate` in `bootstrap/`) is local and ignored by Git. **Keep a copy**; it is how Terraform remembers the bucket.
