# Cost guide (INR)

All figures are **estimates** at roughly ₹88 per US$1 for ap-south-1 (Mumbai) and on-demand prices as understood when this guide was written. Prices and exchange rates change: check the AWS Pricing Calculator (https://calculator.aws) before creating anything. The budget alarm from Phase 7 is your safety net, not a substitute for destroying resources.

## Always-on items (billed per hour while they exist)
| Resource | Dev profile | Approx per month | Approx per day |
|---|---|---|---|
| EKS control plane | 1 cluster | ₹6,400 | ₹210 |
| Worker nodes | 2 x t3.medium | ₹6,000 | ₹200 |
| NAT gateway | 1 (single) + data | ₹3,000+ | ₹100+ |
| RDS MySQL | db.t3.micro, 20 GB gp3, single AZ | ₹1,500 | ₹50 |
| Jenkins EC2 + EBS + Elastic IP | instance size per `jenkins_instance_type` | ₹2,000-3,500 | ₹70-120 |
| SonarQube EC2 + EBS + Elastic IP | needs about 4 GB RAM | ₹2,000-3,500 | ₹70-120 |
| ALB (created by the Ingress) | 1 | ₹1,800 | ₹60 |
| KMS key, Secrets Manager (3 secrets), CloudWatch logs, ECR storage | small | ₹500-1,000 | ₹20-35 |
| Prometheus/Grafana EBS volumes | few GB | ₹100-300 | ₹5-10 |
| **Total if left running** | | **about ₹23,000-28,000** | **about ₹800-950** |

Note: Elastic IPs and public IPv4 addresses are billed hourly too, including attached ones.

## What really costs when you only practise
A realistic study session (create in the morning, test, destroy in the evening, 8-10 hours): about **₹250-400**. A weekend left running by mistake: about **₹2,000**. A month forgotten: **₹25,000+**.

## The biggest levers
1. **Destroy daily** (Phase 16). Nothing else comes close.
2. `create_ci_servers = false` while you only work on the cluster, or stop the EC2 instances overnight.
3. Single NAT in dev (already set).
4. Stop (not delete) RDS for up to 7 days if you must pause: AWS restarts it automatically after 7 days.
5. Use smaller nodes only if the pods still schedule; do not starve Prometheus.
6. Delete unused EBS snapshots, old RDS snapshots, unattached EBS volumes and ECR images (the lifecycle policy limits ECR).

## Free or almost free
IAM, VPC itself, subnets, route tables, security groups, S3 state bucket (a few rupees), Terraform, Trivy, GitHub (free tier), Budgets (first two budgets free).

## Production (not required to deploy)
Multi-AZ RDS roughly doubles the database cost; one NAT per AZ triples NAT; larger nodes, WAF, a managed Grafana or central logging add more. Expect several times the dev figure.

## Cost safety checklist
- [ ] Budget alarm with a real email address exists.
- [ ] Billing alerts are on.
- [ ] I know the destroy order (Phase 16).
- [ ] I set a phone reminder for the end of every working session.
