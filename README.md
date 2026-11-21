# FoodHub DevSecOps

A complete three-tier food-ordering platform (React + Spring Boot + MySQL) with a full DevSecOps toolchain:
Terraform, Docker, Jenkins, SonarQube, Trivy, Amazon ECR, Amazon EKS, RDS, Secrets Manager, Prometheus and Grafana, all in `ap-south-1` (Mumbai).

You are meant to **build it phase by phase, understanding every step**. Everything is already written in this repository;
the guides in `docs/` walk you through running, reading and verifying each part, in the same A to M format for every phase.

> **Start here:** open `docs/PHASE-01-ARCHITECTURE.md`, then follow the phases in order. Do not skip ahead. Tick items in `docs/CHECKLIST.md`.

---

## What is verified and what is not (please read)

This repository was generated in an isolated workspace that could **reach npm but not Maven Central, HashiCorp, Helm chart repositories, or AWS**.
So some parts were executed and others were only checked statically. Nothing below is claimed beyond what was actually done.

| Part | Status |
|---|---|
| React frontend | **Built and tested**: `vite build` succeeds (136 modules) and the 4 Vitest tests pass. Not yet exercised against a live backend. |
| Spring Boot backend (86 Java files) | **Written, NOT compiled.** Only a brace/parenthesis balance check was run. Expect to possibly fix a small compile error or two on your first `mvn test` (Phase 3 tells you exactly how; paste any error to Claude). Library versions in `pom.xml` were chosen from knowledge and must be confirmed by the first build. |
| Flyway SQL migrations | Written, not executed against MySQL. |
| Dockerfiles | Written, not built. `docker-compose.yml` passes `docker compose config` (syntax valid). |
| Terraform (7 modules + bootstrap) | **Parsed as valid HCL, NOT `terraform validate`d and NOT applied.** Expect to fix small provider-schema issues on first `terraform validate`. |
| Kubernetes manifests | Parsed as valid YAML, not applied to a cluster. |
| Jenkinsfiles | Written, not run. |
| Shell scripts | `bash -n` syntax check only. |
| Trivy policy | Configured; **not run** (Trivy could not be downloaded). Your first scan may flag findings I could not predict. Phase 11 explains how to triage them honestly. |
| AWS cost figures | Estimates from knowledge of Mumbai on-demand prices. Verify in the AWS Pricing Calculator before creating resources. |

The guides are written so that **every step ends with a verification**. If a verification fails, stop, fix it (see `docs/TROUBLESHOOTING.md`), and do not continue.

---

## Architecture in one picture

```
 Developer -> GitHub -> Jenkins (EC2) -> SonarQube gate -> Trivy scans -> Docker build -> ECR -> EKS (private nodes)
                                                                                                   |
 Browser -> ALB (HTTP/HTTPS) -> /api -> Spring Boot pods ---------------------------------------->  RDS MySQL (private subnet)
                              -> /    -> React/Nginx pods        Secrets Manager -> External Secrets -> K8s Secret
 Prometheus + Grafana + Alertmanager watch the nodes, pods and the Spring Boot metrics.
```

Full diagrams and explanations: `docs/PHASE-01-ARCHITECTURE.md`.

## Repository layout

```
foodhub-devsecops/
├── frontend/            React 18 + Vite + Axios + React Router (pages, components, context, services)
├── backend/             Spring Boot 3.5, Java 21, JPA, Flyway, JWT, Actuator, 6 JUnit/Mockito test classes
├── database/            ER diagram (Mermaid) and a read-only copy of the schema
├── docker/              MySQL config used by docker-compose
├── terraform/           bootstrap/ (state bucket + budget) and modules: vpc, iam, ecr, eks, rds, secrets, security, ci_servers
│   └── environments/    dev and prod presets + remote-state backend settings
├── kubernetes/          namespace, backend, frontend, ingress, autoscaling, network-policies, external-secrets, rbac, monitoring
├── monitoring/          kube-prometheus-stack Helm values, alert e-mail example, 2 Grafana dashboards (21 panels)
├── jenkins/             Jenkinsfile.infra (Terraform pipeline) and the Trivy HTML report template
├── scripts/             install, bootstrap, deploy, rollback, health-check, smoke-test, cleanup helpers
├── docs/                one guide per phase + cost, troubleshooting, interview Q&A, checklist
├── Jenkinsfile          application CI/CD pipeline
├── docker-compose.yml   local stack (MySQL + backend + frontend)
├── sonar-project.properties, trivy.yaml, .trivyignore.yaml
└── .env.example, .gitignore
```

## Quick start (local, free)

```bash
cp .env.example .env            # then edit the passwords inside .env
docker compose up --build       # wait until the backend is healthy
# open http://localhost:3000   (customer)   and   http://localhost:3000/admin/login   (admin)
bash scripts/smoke-test.sh http://localhost:8080 admin@foodhub.local '<SEED_ADMIN_PASSWORD from .env>'
```

Cloud deployment costs real money. Read `docs/COST.md` and complete Phases 1 to 6 (free) first.

## The phases

| # | Guide | Cost |
|---|---|---|
| 1 | `docs/PHASE-01-ARCHITECTURE.md` architecture and prerequisites | free |
| 2 | `docs/PHASE-02-FRONTEND.md` React frontend | free |
| 3 | `docs/PHASE-03-BACKEND.md` Spring Boot backend | free |
| 4 | `docs/PHASE-04-MYSQL.md` MySQL, Flyway, order flow | free |
| 5 | `docs/PHASE-05-DOCKER.md` Docker and Compose | free |
| 6 | `docs/PHASE-06-GITHUB.md` Git, GitHub, branches, webhook | free |
| 7 | `docs/PHASE-07-AWS-PREP.md` AWS account, IAM, CLI, state bucket | pennies |
| 8 | `docs/PHASE-08-TERRAFORM.md` VPC, EKS, ECR, RDS, secrets | **paid while running** |
| 9 | `docs/PHASE-09-JENKINS.md` Jenkins server and tools | paid while running |
| 10 | `docs/PHASE-10-SONARQUBE.md` SonarQube and quality gate | paid while running |
| 11 | `docs/PHASE-11-TRIVY.md` security scanning and policy | free |
| 12 | `docs/PHASE-12-PIPELINE.md` the CI/CD pipeline | paid while running |
| 13 | `docs/PHASE-13-EKS-DEPLOY.md` deploy to EKS, ALB, HTTPS, autoscaling | paid while running |
| 14 | `docs/PHASE-14-MONITORING.md` Prometheus, Grafana, alerts | paid while running |
| 15 | `docs/PHASE-15-VALIDATION.md` end-to-end validation | paid while running |
| 16 | `docs/PHASE-16-PRODUCTION-CLEANUP.md` production readiness and cleanup | saves money |

Extras: `docs/COST.md`, `docs/TROUBLESHOOTING.md`, `docs/INTERVIEW-QA.md`, `docs/CHECKLIST.md`, `docs/GLOSSARY.md`.

## Security rules this project follows

* No passwords, keys or tokens in Git. `.env`, `*.tfvars` (personal ones), `*.tfstate`, `*.pem` are git-ignored.
* No AWS access keys anywhere: Jenkins uses an EC2 instance role, pods use EKS Pod Identity, nodes pull from ECR via their node role.
* The database lives in private subnets with no internet route; only the EKS node security group can reach port 3306.
* Database credentials are generated by RDS, stored in AWS Secrets Manager, and delivered into Kubernetes by External Secrets Operator.
* The backend computes all prices and totals; the frontend cannot set them.
* Containers run as non-root with read-only filesystems; NetworkPolicies default-deny.
* The pipeline fails on SonarQube quality gate failures and on HIGH/CRITICAL Trivy findings (explicit policy in `trivy.yaml`).
* Infrastructure and application pipelines are separate; no pipeline destroys infrastructure.

## Demo accounts (local only)

`docker compose` creates `admin@foodhub.local` and `customer@foodhub.local` using the passwords you put in `.env`
(`SEED_ADMIN_PASSWORD`, `SEED_CUSTOMER_PASSWORD`). In the cluster there are no demo accounts: create the first admin with `scripts/create-admin.sh`.

## License / purpose

Learning and portfolio project. Payments are simulated; never add real card handling without a PCI-compliant provider.
