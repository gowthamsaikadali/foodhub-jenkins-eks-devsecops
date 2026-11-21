# PHASE 16: Production Hardening and Cleanup

---

### A. What are we doing?
Two things: (1) the list of changes that turn this learning-grade setup into a production setup, and (2) **destroying everything safely** so AWS billing stops.

### B. Why are we doing it?
Forgotten resources are the most common surprise bill (EKS control plane, NAT, ALB, RDS and EC2 bill every hour whether or not anyone uses them). Production hardening is the difference between a demo and a service.

### C. How does it work? Dev shortcuts versus production
| Area | Dev (this project defaults) | Production |
|---|---|---|
| NAT | one shared | one per AZ |
| Nodes | 2 x t3.medium | bigger, mixed, Karpenter or Cluster Autoscaler, multiple AZs |
| RDS | single AZ, deletion protection off, no final snapshot | **Multi-AZ**, deletion protection on, final snapshot, 7-35 days backups, read replica if needed, RDS Proxy |
| Secrets | random generated | rotation enabled in Secrets Manager |
| Access | IP allow-list | VPN or SSO, private EKS endpoint, WAF on the ALB |
| TLS | HTTP for learning | ACM certificate, HTTPS only, HSTS |
| Images | pinned tags | plus image signing (cosign) and admission policy (Kyverno/OPA) |
| State | one S3 bucket | separate state per environment and account, restricted bucket access |
| Environments | dev | separate AWS accounts for dev / staging / prod |
| Logging | EKS control-plane logs | central logs (CloudWatch/OpenSearch), CloudTrail, GuardDuty, AWS Config |
| Monitoring | port-forward | SSO-protected Grafana, Alertmanager to Slack/PagerDuty, SLOs |
| Backups | RDS automated | tested restore drills |
| Deploy | Jenkins to cluster | GitOps (Argo CD) is the usual next step |
`environments/prod/prod.tfvars` already sets the safer values for NAT, nodes, Multi-AZ and deletion protection.

### D. Where should I execute it?
Windows (WSL2) with `AWS_PROFILE=foodhub`.

### E. Which directory should I be in?
```bash
cd foodhub-devsecops
```

### F. Which file should I create?
None.

### G. Complete code
`scripts/cleanup-aws.sh` removes Kubernetes-created AWS resources (ALB) first.

### H. Explain the code
Terraform only knows about what it created. The ALB and its security groups are created by the Load Balancer Controller **outside Terraform**, and they sit inside your VPC, so `terraform destroy` fails (or hangs) when deleting the VPC unless they are removed first. The script deletes the Ingress, waits for the controller to delete the ALB, uninstalls monitoring (releases volumes and any load balancer) and lists what remains.

### I. Execute commands (order matters)
**1. Stop and keep nothing you need.** Export anything you want (screenshots, data). To keep a database copy:
```bash
aws rds create-db-snapshot --db-instance-identifier <id> --db-snapshot-identifier foodhub-final-$(date +%Y%m%d)
```
(a snapshot costs a little per GB-month; delete it later if not needed).

**2. Remove Kubernetes-created AWS resources**
```bash
bash scripts/cleanup-aws.sh
```
The load-balancer list at the end must be empty.

**3. Delete the namespaces** (PVC-backed volumes are released)
```bash
kubectl delete namespace foodhub monitoring --wait=true
```
**4. Destroy the infrastructure**
```bash
terraform -chdir=terraform plan -destroy -var-file=environments/dev/dev.tfvars
```
Read it; then
```bash
terraform -chdir=terraform destroy -var-file=environments/dev/dev.tfvars
```
(type `yes`; takes 10-20 minutes). ECR repositories are deleted with their images because dev sets `ecr_force_delete = true`; the secrets use recovery window 0 in dev, so they disappear immediately.

**5. Prove nothing is left (each should list nothing relevant)**
```bash
aws eks list-clusters
aws rds describe-db-instances --query 'DBInstances[].DBInstanceIdentifier'
aws ec2 describe-instances --filters Name=instance-state-name,Values=running,stopped --query 'Reservations[].Instances[].InstanceId'
aws ec2 describe-nat-gateways --filter Name=state,Values=available --query 'NatGateways[].NatGatewayId'
aws ec2 describe-addresses --query 'Addresses[].PublicIp'
aws elbv2 describe-load-balancers --query 'LoadBalancers[].LoadBalancerName'
aws ec2 describe-volumes --filters Name=status,Values=available --query 'Volumes[].VolumeId'
aws secretsmanager list-secrets --query 'SecretList[].Name'
```
**6. Keep or delete the state bucket.** It costs almost nothing and has `prevent_destroy`. To remove it you must empty all object versions and remove the lifecycle guard deliberately; only do that when you are finished with the project for good.

**7. Check billing the next day:** Console > Billing > Cost Explorer; the budget alerts should stay quiet.

**Pausing instead of destroying (cheaper to resume, but not free):** stop the Jenkins and SonarQube EC2 instances (EBS and Elastic IPs still bill) and scale nodes to 0. The EKS control plane, NAT and RDS keep billing. Destroy is the only way to stop nearly all cost.

### J. Expected output
`Destroy complete! Resources: N destroyed.` and the checks in step 5 returning empty lists (or only your intentionally kept items).

### K. Verification
Next morning: Billing dashboard shows daily cost near zero (a few rupees for S3). No EKS, RDS, NAT or ELB entries in the Console for ap-south-1. Do not forget other regions if you experimented elsewhere.

### L. Troubleshooting
| Problem | Fix |
|---|---|
| `DependencyViolation` deleting subnets / security group / VPC | An ENI or ALB remains: Console > EC2 > Network Interfaces, filter by VPC; delete the leftover load balancer, wait a few minutes, retry destroy. |
| Destroy stuck on EKS node group | Pods with finalizers or a PodDisruptionBudget: delete namespaces first (step 3). |
| `Error: deletion protection is enabled` (RDS) | Prod-style setting; set `db_deletion_protection=false`, apply, then destroy. Intentional safety. |
| Secret "scheduled for deletion" blocks a re-create with the same name | Use recovery window 0 in dev, or restore/force-delete: `aws secretsmanager delete-secret --force-delete-without-recovery --secret-id <name>`. |
| S3 bucket will not delete | It is versioned: all versions and delete markers must be removed first (and `prevent_destroy` lifted). |
| State lock stuck | `terraform force-unlock <ID>` after confirming nothing runs. |

### M. Completion checklist
- [ ] Ingress deleted first; no load balancers remain.
- [ ] `terraform destroy` completed.
- [ ] Verification commands show no EKS, RDS, EC2, NAT, EIP, unattached volumes.
- [ ] Billing checked next day.
- [ ] I can list five changes required for production and why.
- [ ] Access keys of `foodhub-admin` are deactivated if I am done for good.
