# Interview Q&A for this project

Answer in your own words and **only claim what you actually ran**. Where the project says "not verified", say so; interviewers value honesty and the fix-it story.

## Project overview
**Q: Describe the project in 30 seconds.**
A three-tier food-ordering app: React frontend, Spring Boot (Java 21) backend, MySQL on RDS. It is built and deployed through Jenkins with SonarQube and Trivy gates, images go to ECR, infrastructure is Terraform, and it runs on EKS behind an ALB with autoscaling, network policies, secrets from AWS Secrets Manager and Prometheus/Grafana monitoring.

**Q: Why three tiers?** Separation of concerns: each tier scales, deploys and is secured independently; the database is private, the backend is the only thing that talks to it.

## Application
**Q: How does authentication work?** Login returns a signed JWT (HS256); a filter validates it on each request; the server is stateless, so any replica can serve any request. Passwords are BCrypt hashes. Roles ROLE_CUSTOMER and ROLE_ADMIN guard routes.
**Q: Why does the client never send prices?** A client can be tampered with. The server reads prices from the database, computes totals with BigDecimal, and snapshots them in `order_items` so later price changes do not rewrite history.
**Q: How do you prevent invalid order states?** `OrderStatus.canMoveTo` defines the allowed transitions; the service rejects others with 400.
**Q: Why Flyway?** Versioned, repeatable schema changes with checksums; Hibernate `ddl-auto` is `none` so the app never changes the schema by itself.
**Q: Why is the entity named CustomerOrder?** `ORDER` is a reserved SQL word.
**Q: What is on port 8081?** Actuator (health, Prometheus metrics), separate from the public API so it is not exposed through the ingress.

## Docker
**Q: Why multi-stage builds, non-root users, fixed UID?** Smaller image, fewer vulnerabilities, no build tools at runtime; Kubernetes `runAsNonRoot` needs a numeric UID.
**Q: Why `exec java`?** Java becomes PID 1 and receives SIGTERM for graceful shutdown.

## Terraform
**Q: Why remote state with locking?** Shared, versioned, encrypted, and prevents two applies at once. S3 native locking (`use_lockfile`) removes the need for DynamoDB in current Terraform.
**Q: Why modules?** Reuse and clear boundaries (vpc, eks, rds ...).
**Q: How is the DB password handled?** `manage_master_user_password` makes RDS generate it in Secrets Manager; nobody types or commits it; External Secrets syncs it to the pod.
**Q: What does `terraform plan` give you?** A reviewable diff before any change; you saved it and apply exactly that plan.
**Q: How is Terraform run safely from Jenkins?** A separate manual pipeline with an approval step, using a dedicated deployer role that only the Jenkins role can assume; the app pipeline cannot change infrastructure.

## AWS and Kubernetes
**Q: Why private subnets and NAT?** Nodes and the DB have no inbound path from the internet; NAT gives outbound-only access for image pulls.
**Q: What are access entries, and Pod Identity?** Modern EKS authentication/authorization API replacing the `aws-auth` ConfigMap; Pod Identity gives pods a scoped IAM role without keys or OIDC trust plumbing.
**Q: Liveness vs readiness?** Liveness restarts a stuck container; readiness removes it from the Service until it can serve.
**Q: How does a zero-downtime rollout work?** Rolling update with `maxUnavailable: 0`, readiness probes gate traffic, old pods stay until new ones are Ready.
**Q: How do you roll back?** `kubectl rollout undo`; the pipeline does it automatically if a deployed build fails verification; immutable tags make the previous version still available.
**Q: What do NetworkPolicies do here?** Default deny, then allow only ALB to frontend, frontend to backend, backend to RDS and DNS, Prometheus to metrics. They need a CNI that enforces them (enabled on the VPC CNI add-on).
**Q: Why not use the `latest` tag?** Not reproducible, cannot be rolled back, and scanning results do not map to a version. ECR tags are immutable.
**Q: HPA requirements?** metrics-server plus CPU requests on the pods.

## CI/CD and security
**Q: Walk through the pipeline.** Checkout, install, build, test, SonarQube plus quality gate, Trivy filesystem, Terraform validate, Trivy IaC, AWS auth, image build, Trivy image scan, push to ECR, deploy to EKS, rollout verification, health check, post-actions (reports and rollback).
**Q: Why scan twice per stage?** First pass produces reports without failing; second enforces the policy.
**Q: How do you handle a scan finding you cannot fix?** Document it in `.trivyignore.yaml` with a reason and an expiry date and review it; never ignore silently.
**Q: How does Jenkins authenticate to AWS?** EC2 instance profile; no access keys exist to leak.
**Q: Where are secrets?** Secrets Manager, synced into Kubernetes Secrets by External Secrets; none in Git, ConfigMaps or Jenkins job config.

## Monitoring
**Q: How does Prometheus find the backend?** A ServiceMonitor selects the Service and scrapes the `metrics` port; alerts are PrometheusRule objects evaluated by Prometheus and routed by Alertmanager.
**Q: Which alerts matter?** Backend down, 5xx rate, latency, crash loops, node not ready, high CPU/memory.

## "What would you change for production?" (expect this one)
Multi-AZ RDS and deletion protection, one NAT per AZ, private EKS endpoint plus VPN/SSO, WAF and HTTPS only, secret rotation, image signing and admission control, central logging and CloudTrail/GuardDuty, separate AWS accounts per environment, GitOps (Argo CD), real payment gateway and email notifications, load testing and SLOs.

## "What did not work or was not verified?" (be honest)
The Java code, Terraform and Trivy policy were written in an environment where they could not be run. Run `mvn test`, `terraform validate` and the Trivy scans yourself, fix what breaks, and then say exactly what you fixed. Saying this clearly is a strong answer; claiming it all worked first time is not.
