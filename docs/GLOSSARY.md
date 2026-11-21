# Glossary (plain words)

**ACM**: AWS Certificate Manager; issues free TLS certificates for the ALB.
**Alertmanager**: receives alerts from Prometheus and sends notifications.
**ALB**: Application Load Balancer; HTTP(S) entry point to the cluster.
**AZ**: Availability Zone; one data centre group inside a region.
**BCrypt**: slow password hashing; the database stores only hashes.
**CIDR**: an IP range such as `10.0.0.0/16`; `/32` is one address.
**ConfigMap**: Kubernetes object for non-secret settings.
**Container / Image**: running instance / packaged template of an application.
**CORS**: browser rule limiting which websites may call an API.
**Deployment**: Kubernetes object that keeps N copies of a pod running and does rolling updates.
**DTO**: Data Transfer Object; the shape of JSON in and out of the API.
**ECR**: Elastic Container Registry; AWS's Docker image store.
**EKS**: Elastic Kubernetes Service; managed Kubernetes control plane.
**External Secrets Operator**: copies secrets from AWS Secrets Manager into Kubernetes Secrets.
**Flyway**: versioned database migrations.
**Helm**: package manager for Kubernetes (charts).
**HPA**: Horizontal Pod Autoscaler; scales pod count by load.
**IaC**: Infrastructure as Code (Terraform).
**Ingress**: Kubernetes rule that exposes services through a load balancer.
**Instance profile**: an IAM role attached to an EC2 so it gets AWS access without keys.
**JWT**: signed token proving who the caller is, sent as `Authorization: Bearer ...`.
**KMS**: AWS key management; encrypts secrets and disks.
**Namespace**: a logical partition of a cluster.
**NAT gateway**: lets private subnets reach the internet outbound only.
**NetworkPolicy**: pod-level firewall rules.
**Pod**: smallest Kubernetes unit; one or more containers.
**Pod Identity**: gives a pod an AWS IAM role without stored keys.
**Prometheus**: pulls and stores metrics.
**Quality gate**: pass/fail rules in SonarQube.
**RDS**: managed relational database.
**Rollout / Rollback**: gradual replacement of pods with a new version / return to the previous version.
**SAST**: static application security testing (SonarQube).
**Security group**: AWS stateful firewall around instances/ENIs.
**Service (Kubernetes)**: stable address that load-balances to pods.
**State (Terraform)**: Terraform's record of what it built.
**Subnet (public/private)**: a slice of the VPC; public has a route to the internet gateway.
**Terraform module**: reusable group of resources.
**Trivy**: scanner for vulnerabilities, secrets and misconfigurations.
**VPC**: your private network inside AWS.
**Webhook**: an HTTP call one system makes to another when something happens.
