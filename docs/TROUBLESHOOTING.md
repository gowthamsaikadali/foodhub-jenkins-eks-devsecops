# Troubleshooting guide

Method: (1) read the **exact** error, (2) find which layer printed it, (3) reproduce with the smallest command, (4) change one thing, (5) re-test. Never fix by guessing several things at once.

## Where to look
| Layer | Command or place |
|---|---|
| Browser | DevTools > Console and Network tab (status codes, response bodies) |
| Nginx (frontend) | `kubectl -n foodhub logs deploy/foodhub-frontend` or `docker compose logs frontend` |
| Backend | `kubectl -n foodhub logs deploy/foodhub-backend --tail=200` (add `-p` for the previous crashed container) |
| Why a pod is not starting | `kubectl -n foodhub describe pod <name>` (look at Events at the bottom) |
| Database | `docker exec -it foodhub-mysql mysql ...` locally; from the cluster use a temporary client pod |
| Jenkins | Build page > Console Output; `sudo journalctl -u jenkins` on the server |
| Terraform | The error names the resource and file; `TF_LOG=INFO terraform plan` for detail |
| AWS | CloudTrail event history shows denied API calls (AccessDenied) |

## Backend build (the first thing to run)
The backend source was written without being compiled in the authoring environment. Run `cd backend && mvn -B test` first. Typical fixes: a library version in `pom.xml` that does not exist (check Maven Central and use the latest 3.5.x Spring Boot / 0.12.x jjwt), a missing import, or a typo. Fix the line the compiler names; each is small.

## Quick table
| Symptom | Cause | Fix |
|---|---|---|
| `Could not resolve placeholder 'DB_URL'` | env var missing in this terminal | export it again; variables are per terminal |
| `Access denied for user` | password differs from the one MySQL was created with | `docker compose down -v`, recreate |
| `Migration checksum mismatch` | edited an applied Flyway file | local: reset volume; real DB: add a new V file |
| `Schema-validation: wrong column type` | Hibernate `validate` vs MySQL TINYINT(1) | leave `JPA_DDL_AUTO` at `none` |
| 401 on every call | token missing or expired; `Authorization: Bearer <token>` header | log in again |
| 403 on an admin call | customer token or not the restaurant owner | log in as admin |
| CORS error in browser | origin not allowed | set `CORS_ALLOWED_ORIGINS` to your site URL |
| `502 Bad Gateway` | frontend cannot reach backend | check backend is Ready and `BACKEND_URL` |
| `ImagePullBackOff` | tag not in ECR or node role cannot pull | list ECR tags; `describe pod` |
| `CrashLoopBackOff` | app exits at start | logs with `-p` |
| `Pending` pod | no capacity or unbound volume | `describe pod` events |
| `Unauthorized` from kubectl | not in access entries or IP changed | update `admin_principal_arns` / `admin_cidrs`; `aws eks update-kubeconfig` |
| Ingress has no address | LBC problem | `kubectl -n kube-system logs deploy/aws-load-balancer-controller` |
| ExternalSecret `SecretSyncedError` | wrong secret name or missing permission | `kubectl describe externalsecret`; check Pod Identity association |
| Terraform `state lock` | previous run aborted | `terraform force-unlock <ID>` (only if sure) |
| Terraform `AccessDenied` | wrong profile or permissions | `aws sts get-caller-identity` |
| Jenkins cannot reach SonarQube | security group / address | use the private IP; port 9000 allowed from Jenkins |
| `docker: permission denied` in Jenkins | jenkins not in docker group | `usermod -aG docker jenkins`; restart |
| Trivy fails the build | real finding | upgrade the dependency/base image; ignore only with reason and expiry |
| Destroy fails on VPC | ALB or ENI left behind | run `scripts/cleanup-aws.sh`, delete leftovers, retry |

## Likely first-run fixes in Terraform
This code was parsed but never run with `terraform validate`. Expect a few of: an argument renamed in a newer AWS provider (the error says `Unsupported argument`), a missing module output reference, or a value that is known only after apply (use `-target` for the first apply). Fix the exact line named.

## Likely first-run fixes in the Jenkinsfile
Groovy errors name the line. Common ones: a missing credential id, tool not on PATH for the `jenkins` user (run `sudo -u jenkins which trivy`), or a plugin step not installed (the error says `No such DSL method`).

## When to stop and ask
If the same error survives two honest attempts, copy the exact error plus the last 30 lines of the log, the command you ran, and what you changed. That is what any senior engineer will ask for first.
