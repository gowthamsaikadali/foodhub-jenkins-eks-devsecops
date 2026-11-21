# PHASE 8: Terraform Infrastructure

**Cost warning.** This is the first phase that spends real money. Rough INR estimates for the **dev** profile running 24x7 in ap-south-1 (US$ at about ₹88; verify with the AWS Pricing Calculator):

| Item | About per month |
|---|---|
| EKS control plane | ₹6,400 (US$0.10/h) |
| 2 x t3.medium nodes | ₹6,000 |
| NAT gateway (single) + data | ₹3,000+ |
| RDS db.t3.micro + 20 GB | ₹1,500 |
| Jenkins + SonarQube EC2, EBS, Elastic IPs | ₹4,000-6,000 |
| ALB (created in Phase 13) | ₹1,800 |
| KMS, Secrets Manager, CloudWatch logs, ECR | ₹500-1,000 |
| **Total, left running** | **roughly ₹23,000-28,000 (about ₹800-950 per day)** |

**Rule: `terraform destroy` when you stop for the day** (Phase 16 gives the safe order). Created and destroyed within a few hours, a practice run costs about ₹100-300.

---

### A. What are we doing?
Describing the entire AWS infrastructure as code and creating it with Terraform: VPC, subnets, NAT, security groups, IAM, ECR, EKS, RDS, Secrets Manager, and the Jenkins and SonarQube servers.

### B. Why are we doing it?
Clicking in the console is not repeatable, reviewable or destroyable. Code is: it goes through Git review, it can be recreated in minutes, and `destroy` removes everything so billing stops.

### C. How does it work?
Terraform reads `.tf` files, compares them with the **state** in S3, prints a **plan** (what it will add, change or destroy), and on `apply` calls AWS APIs.

```
modules/vpc       -> VPC, 3 tiers of subnets (public / private app / private db), IGW, NAT, route tables
modules/security  -> security groups: ALB, nodes, RDS (3306 only from nodes), Jenkins, SonarQube
modules/iam       -> Jenkins role (least privilege), separate "terraform-deployer" role, EKS roles
modules/ecr       -> 2 repositories (backend, frontend), immutable tags, scan on push, lifecycle policy
modules/eks       -> cluster, managed node group, access entries, Pod Identity roles, add-ons, KMS
modules/rds       -> MySQL 8 in DB subnets, encrypted, AWS-managed master password in Secrets Manager
modules/secrets   -> JWT secret, DB connection secret, External Secrets role
modules/ci_servers-> Jenkins and SonarQube EC2 (IMDSv2, encrypted EBS, Elastic IPs)
```
Tier isolation: only the ALB is public; nodes are private; RDS accepts connections only from the node security group.

### D. Where should I execute it?
**Windows local machine (WSL2)** with `AWS_PROFILE=foodhub` set.

### E. Which directory should I be in?
```bash
cd foodhub-devsecops/terraform
```

### F. Which file should I create?
1. Fix the bucket name in `environments/dev/backend.hcl` (replace `REPLACE_ACCOUNT_ID` or paste the exact name printed in Phase 7).
2. Create `terraform.tfvars` (your personal values; ignored by Git):
```bash
cp terraform.tfvars.example terraform.tfvars
```

### G. Complete code
All Terraform files are in the zip. Your `terraform.tfvars`:
```hcl
state_bucket_name    = "foodhub-tfstate-<your-account-id>-ap-south-1"
admin_cidrs          = ["<YOUR_PUBLIC_IP>/32"]
admin_principal_arns = ["arn:aws:iam::<your-account-id>:user/foodhub-admin"]
# github_webhook_cidrs = []   # leave empty to rely on polling; see Phase 12
```
Environment sizes live in `environments/dev/dev.tfvars` (t3.medium x2, db.t3.micro, single NAT, deletion protection off).

### H. Explain the code
* `backend.tf`: `backend "s3" {}` is intentionally empty; values come from `backend.hcl` so one code base serves dev and prod.
* `variables.tf`: validations such as "admin_cidrs must not contain 0.0.0.0/0" protect you from exposing Jenkins and SonarQube to the world.
* `modules/vpc`: three subnet tiers across `az_count` zones. `single_nat_gateway = true` saves about ₹3,000/month in dev; prod uses one NAT per AZ for resilience.
* `modules/eks`: **access entries** (modern replacement for the `aws-auth` ConfigMap) give your user and the Jenkins role cluster access; **Pod Identity** gives the Load Balancer Controller and External Secrets only the AWS permissions they need; **KMS** encrypts Kubernetes Secrets; the VPC CNI is configured with `enableNetworkPolicy` so the NetworkPolicies in `kubernetes/` are really enforced.
* `modules/rds`: `manage_master_user_password = true`: **you never see or write the DB password**. AWS stores it in Secrets Manager.
* `modules/iam`: Jenkins cannot create arbitrary resources. It can push to ECR, describe/get a token for EKS, and `sts:AssumeRole` into the separate `terraform-deployer` role used only by the infrastructure pipeline.
* `create_ci_servers = true`: set to `false` if you want to build only the cluster first.

### I. Execute commands
**1. Format and initialise**
```bash
terraform fmt -recursive
```
```bash
terraform init -backend-config=environments/dev/backend.hcl
```
**2. Validate the syntax and references**
```bash
terraform validate
```
> Honest note: this code was written without being able to run `terraform validate` in the authoring environment. If it reports an error, read the message (it names the file and line), fix that one thing, and re-run. This is normal and is part of the learning. `docs/TROUBLESHOOTING.md` lists the likely ones.

**3. Preview. Read it.**
```bash
terraform plan -var-file=environments/dev/dev.tfvars -out=dev.plan
```
Look for the summary `Plan: N to add, 0 to change, 0 to destroy.` On a first run the destroy count must be 0.

**4. Create (takes about 15-25 minutes, EKS and RDS are the slow ones)**
```bash
terraform apply dev.plan
```
**5. Read the outputs**
```bash
terraform output
```
**6. Connect kubectl** (command also printed by `terraform output kubeconfig_command`)
```bash
aws eks update-kubeconfig --region ap-south-1 --name foodhub-dev-eks
```
```bash
kubectl get nodes
```
**7. Inspect what exists**
```bash
aws ecr describe-repositories --query 'repositories[].repositoryName'
```
```bash
aws rds describe-db-instances --query 'DBInstances[].[DBInstanceIdentifier,DBInstanceStatus]'
```
**8. Destroy (when you stop; do Phase 16 steps first if you installed the ALB/ingress)**
```bash
terraform destroy -var-file=environments/dev/dev.tfvars
```

### J. Expected output
* `terraform init`: `Terraform has been successfully initialized!`
* `terraform validate`: `Success! The configuration is valid.`
* `terraform apply`: ends with `Apply complete! Resources: N added, 0 changed, 0 destroyed.` and lists outputs (cluster name, ECR URLs, RDS endpoint, Jenkins and SonarQube addresses). N and the addresses are yours.
* `kubectl get nodes`: two nodes with `STATUS Ready`.

### K. Verification
1. Console > VPC: your VPC with public, private and database subnets.
2. Console > EKS > cluster is `Active`; Compute shows 2 nodes.
3. Console > RDS: instance `available`, **Publicly accessible: No**.
4. `aws secretsmanager list-secrets --query 'SecretList[].Name'` shows the JWT, DB-connection and RDS master secrets (names only; **never print secret values into screenshots**).
5. ECR: two repositories, tag immutability on.
6. `terraform plan` immediately after apply says `No changes.`: your code and AWS agree.

### L. Troubleshooting
| Error | Fix |
|---|---|
| `Error acquiring the state lock` | Another run is active, or one crashed. Wait; if sure nothing runs: `terraform force-unlock <ID>`. |
| `Backend configuration changed` | Re-run `terraform init -backend-config=... -reconfigure`. |
| `AccessDenied` | Wrong `AWS_PROFILE` or the user lacks permission. Re-check `aws sts get-caller-identity`. |
| `InvalidParameterCombination ... kubernetes version` | The EKS version is not offered in the region yet: `aws eks describe-cluster-versions` and set `kubernetes_version`. |
| `VcpuLimitExceeded` / quota | New accounts have low limits; request an increase in Service Quotas, or use `t3.small` only if memory allows. |
| `InsufficientFreeAddressesInSubnet` | Do not shrink subnet CIDRs. |
| `Error: Invalid for_each argument ... known only after apply` | Apply in two steps: `terraform apply -target=module.vpc` first, then the full apply. |
| Destroy hangs on subnets/VPC | An ALB or ENI created by Kubernetes still exists: run `scripts/cleanup-aws.sh` (Phase 16), then retry. |
| RDS creation stuck in `creating` | Normal for 5-10 minutes. |

### M. Completion checklist
- [ ] I read the cost table and understand the daily cost of leaving this running.
- [ ] `terraform validate` succeeds; `plan` was reviewed before `apply`.
- [ ] `kubectl get nodes` shows Ready nodes.
- [ ] RDS is private; secrets exist; ECR repos exist.
- [ ] `terraform plan` afterwards shows no changes.
- [ ] I know the destroy procedure and will use it.
