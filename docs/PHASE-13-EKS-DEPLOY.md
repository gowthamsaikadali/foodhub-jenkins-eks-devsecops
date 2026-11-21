# PHASE 13: Kubernetes Deployment on EKS

Cost: the ALB adds roughly ₹1,800 per month (about ₹60 per day) while it exists. Delete the Ingress when you stop (Phase 16).

---

### A. What are we doing?
Preparing the EKS cluster once (controllers, secrets, policies), deploying the app, exposing it through an ALB, enabling autoscaling, and creating the first admin user.

### B. Why are we doing it?
This is the production-style runtime: self-healing pods, rolling updates, autoscaling, network isolation, secrets from a vault.

### C. How does it work?
```
Internet -> ALB (public subnets) -> frontend pods (Nginx) -> backend Service -> backend pods -> RDS (private)
```
* **Namespace `foodhub`** with Pod Security `restricted` (pods must be non-root, no privilege escalation, drop all capabilities).
* **Deployments** (2 replicas each, probes, resource requests/limits, read-only root filesystem, `topologySpreadConstraints`, rolling update `maxUnavailable: 0`).
* **Services** (ClusterIP).
* **Ingress** class `alb`: the AWS Load Balancer Controller creates a real ALB, target type `ip` (straight to pod IPs).
* **HPA**: scales backend and frontend on CPU (needs metrics-server).
* **NetworkPolicies**: default deny all, then explicit allows (ALB to frontend, frontend to backend, backend to RDS port and DNS, Prometheus to metrics).
* **External Secrets Operator** reads AWS Secrets Manager (JWT secret, DB connection secret) using Pod Identity (no keys) and creates the Kubernetes Secret `foodhub-secrets`. Secret values are never in Git, in the ConfigMap, or in the pipeline.
* **RBAC**: Jenkins deploys only inside `foodhub`; a read-only role exists for viewers.

### D. Where should I execute it?
**Windows local machine (WSL2)**, with kubeconfig from Phase 8, `AWS_PROFILE=foodhub`. Cluster API access is limited by `admin_cidrs`.

### E. Which directory should I be in?
```bash
cd foodhub-devsecops
```

### F. Which file should I create?
None. Manifests are in `kubernetes/` and are templates: `${ECR_REGISTRY}` and `${IMAGE_TAG}` are filled in by `scripts/deploy.sh`.

### G. Complete code
`kubernetes/` tree in the zip; scripts `bootstrap-cluster.sh`, `apply-external-secrets.sh`, `deploy.sh`, `create-admin.sh`, `rollback.sh`, `health-check.sh`.

### H. Explain the code (key choices)
* `readOnlyRootFilesystem: true` plus `emptyDir` mounts at `/tmp` (and Nginx's cache/run dirs): the container cannot be modified at runtime. *Untested note:* the Nginx image writes rendered config at start; if the frontend pod crashes with a read-only filesystem error, see Troubleshooting.
* The backend `envFrom` takes the ConfigMap (non-secret settings), the secret `foodhub-secrets` (DB_URL, DB_USERNAME, DB_PASSWORD, JWT_SECRET) and an **optional** secret `foodhub-seed`.
* Probes: backend uses the actuator on port 8081 (`/actuator/health/liveness` and `/readiness`); the actuator port is **not** in the Service or Ingress, so it is not public.
* `ingress.yaml` is HTTP-only for a first working version; `ingress-https.yaml` adds an ACM certificate, port 443 and an HTTP to HTTPS redirect.
* HPA min 2 / max 4 (backend) and min 2 / max 4 (frontend) to protect a small dev cluster's capacity.

### I. Execute commands
**1. Check cluster access**
```bash
kubectl get nodes
```
**2. One-time cluster setup** (namespace, metrics-server, Load Balancer Controller, External Secrets Operator, then secrets, policies, RBAC)
```bash
bash scripts/bootstrap-cluster.sh dev
```
Then record the chart versions it installed so future runs are reproducible:
```bash
helm list -A
```
**3. Wait for the controllers**
```bash
kubectl -n kube-system get deploy aws-load-balancer-controller
```
```bash
kubectl -n external-secrets get pods
```
**4. Check the secret sync**
```bash
kubectl -n foodhub get externalsecret
```
`STATUS SecretSynced` and `READY True` are expected. Then confirm the Secret exists **without printing it**:
```bash
kubectl -n foodhub get secret foodhub-secrets
```
**5. Deploy the application** (normally Jenkins does this; by hand once, using the tags from ECR)
```bash
export ECR_REGISTRY="$(aws sts get-caller-identity --query Account --output text).dkr.ecr.ap-south-1.amazonaws.com"
```
```bash
aws ecr list-images --repository-name foodhub-backend --query 'imageIds[].imageTag' --output text
```
```bash
IMAGE_TAG=build-1 bash scripts/deploy.sh
```
(use a tag that exists in **both** repositories).
**6. Watch the rollout**
```bash
kubectl -n foodhub rollout status deploy/foodhub-backend
```
```bash
kubectl -n foodhub get pods,svc,ingress,hpa
```
**7. Get the public address** (the ALB takes 2-4 minutes)
```bash
kubectl -n foodhub get ingress foodhub -o jsonpath='{.status.loadBalancer.ingress[0].hostname}{"\n"}'
```
**8. Create the first admin** (prompts for a password; nothing stored in Git)
```bash
bash scripts/create-admin.sh admin@yourdomain.com
```
**9. Restrict the ALB to your IP while testing** (optional, recommended): in `kubernetes/ingress/ingress.yaml` add the annotation `alb.ingress.kubernetes.io/inbound-cidrs: "<YOUR_IP>/32"` and re-deploy.

**10. HTTPS (needs a domain you own):**
1. Console > Certificate Manager (region **ap-south-1**) > Request public certificate for `foodhub.yourdomain.com`, DNS validation; add the CNAME record at your DNS provider; wait for `Issued`.
2. Put the certificate ARN in `kubernetes/ingress/ingress-https.yaml` (`alb.ingress.kubernetes.io/certificate-arn`), and the host name in `spec.rules[0].host`.
3. Deploy with `INGRESS_FILE=kubernetes/ingress/ingress-https.yaml IMAGE_TAG=build-N bash scripts/deploy.sh`.
4. Create a DNS CNAME `foodhub.yourdomain.com` to the ALB hostname.
Without a domain, ACM cannot issue a certificate; use the HTTP version for the learning exercise and say so honestly in any demo.

**11. Autoscaling test (watch it scale)**
```bash
kubectl -n foodhub get hpa -w
```
In another terminal generate load, for example with a throw-away pod (stop with Ctrl+C):
```bash
kubectl -n foodhub run load --rm -it --image=busybox:1.36 --restart=Never -- sh -c 'while true; do wget -q -O- http://foodhub-frontend:80/api/restaurants >/dev/null; done'
```
(The pod is rejected if Pod Security `restricted` blocks it; in that case run it in a separate test namespace without the restriction.)

### J. Expected output
* `ExternalSecret` shows `SecretSynced`.
* Pods: 2 backend and 2 frontend, all `1/1 Running` (backend can take about 60-90 seconds to become Ready).
* `get hpa` shows `cpu: <x>%/70%` once metrics are available (at first `<unknown>`).
* Ingress shows a hostname like `k8s-foodhub-...ap-south-1.elb.amazonaws.com`.
* Browser opens the site; admin login works with the password you chose.

### K. Verification
1. `curl -s http://<alb-hostname>/api/restaurants | head -c 200` returns JSON.
2. `kubectl -n foodhub describe pod <backend-pod>` shows `Running as non-root`, resource limits, probes passing.
3. **Self-healing:** `kubectl -n foodhub delete pod <one backend pod>`; a new one appears and traffic continues.
4. **Rolling update:** deploy a new tag and watch `kubectl rollout status` (zero downtime because `maxUnavailable: 0`).
5. **Rollback:** `bash scripts/rollback.sh` (previous revision) and `kubectl -n foodhub rollout history deploy/foodhub-backend`.
6. **Network policy:** from a test pod in another namespace, connecting to the backend must time out.
7. **RDS privacy:** `aws rds describe-db-instances --query 'DBInstances[].PubliclyAccessible'` is `false`.
8. `kubectl auth can-i --as=system:serviceaccount:foodhub:default get secrets -n foodhub` is `no`.

### L. Troubleshooting
| Symptom | Likely cause and fix |
|---|---|
| Pods `Pending` | Not enough node capacity: `kubectl describe pod`; reduce replicas/requests or use a bigger node type. |
| `ImagePullBackOff` | Tag missing in ECR or node role lacks ECR read: `kubectl describe pod`; list tags in both repos. |
| `CreateContainerConfigError: secret "foodhub-secrets" not found` | ExternalSecret not synced: `kubectl -n foodhub describe externalsecret`; check Pod Identity role, secret names, ESO pods. |
| Backend `CrashLoopBackOff` | `kubectl logs deploy/foodhub-backend`: DB connection (security group, URL), JWT secret length, Flyway error. |
| Backend not Ready but running | Readiness probe: actuator port 8081; check `kubectl describe`. |
| Frontend `CrashLoopBackOff` with `read-only file system` | The Nginx template step needs writable `/etc/nginx/conf.d`: read the pod log for the exact path; add one more `emptyDir` mount for it (for example `/var/run`) in `kubernetes/frontend/deployment.yaml`. This combination is the least tested part of the project. |
| Ingress has no address after 5 min | `kubectl -n kube-system logs deploy/aws-load-balancer-controller`: subnet tags missing or IAM permission. |
| ALB shows 503/502 | Targets unhealthy: check target group health in console; ensure NetworkPolicy allows ALB to frontend pods (VPC CIDR). |
| `pods "..." is forbidden: violates PodSecurity` | A manifest breaks the `restricted` profile. The error names the field. |
| HPA shows `<unknown>` | metrics-server not ready or no resource requests set. |
| `Unauthorized` from kubectl | `aws eks update-kubeconfig` again; ensure your IAM user ARN is in `admin_principal_arns`; check `admin_cidrs` matches your current IP. |
| NetworkPolicy seems ignored | VPC CNI network policy not enabled: check the add-on config in Terraform (`enableNetworkPolicy`). |

### M. Completion checklist
- [ ] Controllers and ESO running; ExternalSecret synced.
- [ ] 2+2 pods Running; Ingress has an ALB hostname.
- [ ] I created an admin with `create-admin.sh`; customer and admin flows work through the ALB.
- [ ] HPA reports metrics; self-healing and rollback demonstrated.
- [ ] NetworkPolicy and non-root checks done.
- [ ] I know which resources (ALB) are outside Terraform and must be deleted first.
