# PHASE 1: Architecture and Prerequisites

Cost of this phase: **free** (reading only).

---

### A. What are we doing?
Understanding what we will build before we build it: the application, the cloud network, the delivery pipeline and the monitoring.

### B. Why are we doing it?
In a DevOps interview you are expected to explain **why** each piece exists and how the pieces talk to each other. If you can draw and explain this phase from memory, you can answer most architecture questions.

### C. How does it work?

#### 1. Two halves

| Half | What it is | Tools |
|---|---|---|
| **The application** | The product users touch | React, Spring Boot, MySQL |
| **The platform** | How code reaches production safely and is watched | Terraform, Jenkins, SonarQube, Trivy, ECR, EKS, Prometheus, Grafana |

#### 2. Three-tier architecture

A three-tier app splits into layers. Each layer talks only to its neighbour, which makes it secure and independently scalable.

| Tier | Technology | Runs on | Job |
|---|---|---|---|
| 1. Presentation | React served by Nginx | Pods on EKS | Draws the UI in the browser, calls the backend over HTTP |
| 2. Application | Spring Boot (Java 21) | Pods on EKS | Login and JWT, business rules, order totals, payment simulation |
| 3. Database | RDS MySQL 8 | AWS managed, private subnet | Users, restaurants, foods, carts, orders, payments |

Rules to remember: (1) the browser never talks to the database; (2) the backend computes prices, never the browser, because the browser can be tampered with; (3) the database has no public IP and only the worker nodes may connect.

#### 3. AWS network (what Terraform builds in Phase 8)

```
                          Internet
                             |
                    +--------v--------+
                    |  ALB (HTTP/S)   |   created by the AWS Load Balancer Controller from the Kubernetes Ingress
                    +--------+--------+
+----------------------------|------------------------------------------------------+
| VPC 10.0.0.0/16            |                                  region ap-south-1    |
|  PUBLIC subnets (2 AZ)     |                                                       |
|   ALB   NAT gateway   Jenkins EC2   SonarQube EC2                                  |
|  PRIVATE APP subnets (2 AZ)|                                                       |
|   EKS worker nodes:  ns foodhub (frontend, backend)  ns monitoring  ns external-secrets |
|  PRIVATE DB subnets (2 AZ)    <-- no route to the internet at all                  |
|   RDS MySQL 8 (encrypted, not public)        port 3306 allowed only from the EKS SG |
+-------------------------------------------------------------------------------------+
 Outside the VPC (AWS managed): ECR, Secrets Manager, S3 (Terraform state), IAM, KMS, CloudWatch
```

| AWS service | Purpose | Analogy |
|---|---|---|
| VPC | Your private network | Your fenced property |
| Public subnet | Has a route to the Internet Gateway | Front gate and driveway |
| Private subnet | No inbound internet route | Rooms inside the house |
| Internet Gateway | Two-way door to the internet | Front door |
| NAT Gateway | Lets private resources go out but blocks inbound | One-way exit door |
| Security Group | Stateful firewall per resource | Bouncer with a guest list |
| EKS | Managed Kubernetes control plane | A manager who schedules your containers |
| ECR | Private Docker registry | Private warehouse for images |
| RDS | Managed MySQL with backups | Database with a built-in admin |
| Secrets Manager | Stores credentials, rotatable, audited | Locked safe |
| IAM | Who may do what | Keycards |
| ACM | Free TLS certificates | The padlock |
| ALB | Layer-7 load balancer | Receptionist routing visitors |
| S3 | Holds Terraform state | Filing cabinet for infrastructure records |

#### 4. Runtime request path (a customer ordering food)
1. Browser requests the site; the ALB (TLS terminated with an ACM certificate when you have a domain) forwards it.
2. The ALB sends `/` to the frontend Service (Nginx pod, which returns the React files).
3. React calls `/api/...`; the ALB routes `/api/*` to the backend Service.
4. The backend validates the JWT, runs business logic and queries RDS on 3306.
5. The DB password reached the pod through: **RDS generates it -> Secrets Manager stores it -> External Secrets Operator reads it using an IAM role (Pod Identity) -> creates a Kubernetes Secret -> injected as environment variables**. It is never in Git.

#### 5. DevSecOps pipeline ("shift left": find problems as early as possible)

```
git push -> GitHub -> webhook -> Jenkins
 1 Checkout   2 npm ci / mvn deps   3 frontend build   4 backend build   5 unit tests
 6 SonarQube analysis   7 Quality gate  (red = STOP)
 8 Trivy filesystem scan (code, dependencies, secrets)  (HIGH/CRITICAL = STOP)
 9 Terraform validate   10 Trivy IaC scan (Terraform, Kubernetes, Dockerfiles)
 11 AWS identity   12 Docker build   13 Trivy image scan (STOP)
 14 ECR login + push (tags build-N and sha-<commit>)
 15 EKS login   16 kubectl deploy (exact tag, never latest)   17 rollout check   18 API health check
 19 Notify; on failure after deploy -> automatic rollback
```
Why two pipelines: an application commit must never be able to change your VPC or database. The **infrastructure pipeline** (`jenkins/Jenkinsfile.infra`) is manual-only, plans, waits for human approval, then applies, and cannot destroy.

#### 6. How the tools interact

| Interaction | Mechanism |
|---|---|
| GitHub -> Jenkins | Webhook (HTTP POST on push) |
| Jenkins -> SonarQube | Scanner uploads analysis; SonarQube calls Jenkins back (webhook) with the quality gate result |
| Jenkins -> Trivy | CLI in pipeline stages; non-zero exit code fails the build |
| Jenkins -> ECR | `aws ecr get-login-password` using the EC2 **instance profile** (no stored keys) |
| Jenkins -> EKS | `aws eks update-kubeconfig`; authorised by an EKS **access entry** limited to the `foodhub` namespace |
| EKS nodes -> ECR | Node IAM role with `AmazonEC2ContainerRegistryReadOnly` (no imagePullSecrets) |
| Backend -> RDS | JDBC over 3306, allowed by a security-group-to-security-group rule |
| EKS -> Secrets Manager | External Secrets Operator with an IAM role via EKS Pod Identity |
| Prometheus -> backend | ServiceMonitor scrapes `/actuator/prometheus` on port 8081 |

#### 7. Monitoring

```
Spring Boot (Actuator + Micrometer) --/actuator/prometheus--+
node-exporter (per node: CPU, RAM, disk) --------------------+--> Prometheus --> Grafana (dashboards)
kube-state-metrics (pod/deployment state, restarts) ---------+        |
                                                                      +--> Alertmanager --> email/Slack
```
Installed with one Helm chart, `kube-prometheus-stack`. Grafana is reached through `kubectl port-forward`, never a public URL.

### D. Where should I execute it?
Nowhere yet. This phase is reading. The prerequisite installs below run on your **Windows machine** (preferably inside **WSL2 Ubuntu**).

### E. Which directory should I be in?
Not applicable yet. From Phase 2 on you work inside `foodhub-devsecops/` (the unzipped repository).

### F. Which file should I create?
None. Unzip the delivered zip; it creates `foodhub-devsecops/` containing every file.

### G. Complete code
The whole project is already in the zip. Open `README.md` for the file map.

### H. Explain the code
Prerequisite list and why each tool is needed:

| Tool | Version | Why |
|---|---|---|
| Git | latest | Source control |
| Node.js | 20 LTS | Builds React |
| JDK | 21 | Runs/builds the backend |
| Maven | 3.9+ | Java build tool |
| Docker Desktop (WSL2 backend) | latest | Local containers |
| AWS CLI | v2 | Talks to AWS |
| Terraform | 1.10 or newer | Infrastructure as code (1.10 adds S3 native state locking) |
| kubectl | within one minor version of the cluster (1.36) | Controls Kubernetes |
| Helm | 3.x | Installs packaged apps (monitoring, controllers) |
| jq | any | Reads JSON in scripts |
| VS Code or IntelliJ | any | Editor |

Accounts: an AWS account with **MFA on the root user**, an IAM admin user for daily work, a GitHub account, and (optional) a domain name for HTTPS.

### I. Execute commands
Install and check the tools (WSL2 Ubuntu terminal). One command at a time:

```bash
git --version
```
```bash
node -v
```
```bash
java -version
```
```bash
mvn -v
```
```bash
docker --version
```
```bash
docker compose version
```
```bash
aws --version
```
```bash
terraform version
```
```bash
kubectl version --client
```
```bash
helm version --short
```
If a tool is missing, ask Claude for exact install steps for your OS. (Phase 9 contains Linux install commands for most of them in `scripts/install-jenkins-tools.sh`; you can reuse those lines on WSL2 Ubuntu.)

### J. Expected output
Each command prints a version number. Java must start with 21, Node with v20 (or newer LTS), Terraform 1.10 or higher. The exact numbers on your machine will differ.

### K. Verification
You can answer these out loud:
1. Why is the database in a private subnet?
2. What is the difference between a public and a private subnet, and what does a NAT gateway do?
3. Describe the path from `git push` to a pod running in EKS.
4. Why are there two pipelines?
5. Which AWS resources bill while idle? (EKS control plane, NAT gateway, ALB, RDS, EC2/EBS, Elastic IPs.)

### L. Troubleshooting
| Problem | Fix |
|---|---|
| `docker: command not found` in WSL | Docker Desktop > Settings > Resources > WSL integration > enable your Ubuntu distro |
| `java -version` shows 17 or 11 | Install `openjdk-21-jdk` and set `JAVA_HOME` |
| Windows line endings break scripts (`\r: command not found`) | `git config --global core.autocrlf input`, then re-clone/unzip inside WSL |

### M. Completion checklist
- [ ] I understand the three tiers and why the DB is private.
- [ ] I can explain public vs private subnet and NAT.
- [ ] I can explain the pipeline flow end to end.
- [ ] I know why infrastructure and application pipelines are separate.
- [ ] I know which resources cost money while idle.
- [ ] AWS account with root MFA exists (needed from Phase 7; a Budgets alert is created there).
- [ ] All local tools in section H are installed and verified.
- [ ] I know whether I have a domain name (needed only for HTTPS in Phase 13).

**Design decisions locked in** (change them only deliberately, then update every affected file): Terraform state in S3 with native lockfile (no DynamoDB); EKS Pod Identity for pod-to-AWS permissions; EKS access entries instead of `aws-auth`; two nodes across two AZs; Kubernetes 1.36 (in standard support until Aug 2027; verified at https://endoflife.date/eks on 2026-11-16, re-check before use because older versions cost 6x more per cluster-hour).
