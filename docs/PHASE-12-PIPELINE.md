# PHASE 12: Jenkins CI/CD Pipeline

Cost: free beyond the Jenkins server. Pushing images costs a few rupees of ECR storage per month.

---

### A. What are we doing?
Running the complete pipeline defined in `Jenkinsfile`, and a **separate** manual pipeline for infrastructure (`jenkins/Jenkinsfile.infra`).

### B. Why are we doing it?
So that every change goes through the same gates (tests, quality, security) in the same order and only a passing `main` reaches production, with a way back.

### C. How does it work? Stage by stage (the application pipeline)
| # | Stage | What it does and why |
|---|---|---|
| 1 | Checkout | Gets the commit; computes `build-<N>` and `sha-<8>` tags. |
| 2 | Dependency installation | `npm ci` and `mvn dependency:go-offline` in parallel. |
| 3 | Frontend build | `npm run build` proves the UI compiles. |
| 4 | Backend Maven build | Compiles Java 21 and packages the jar. |
| 5 | Unit testing | Vitest (frontend) and JUnit 5 + Mockito (backend); JUnit results are published. |
| 6 | SonarQube analysis | `sonar-scanner` uploads code, coverage, issues. |
| 7 | Quality gate | `waitForQualityGate abortPipeline: true`: stops here if the gate fails. |
| 8 | Trivy filesystem scan | Dependencies and secrets in source. |
| 9 | Terraform validation | `fmt -check` and `validate` (no AWS calls, no backend). |
| 10 | Trivy IaC scan | Terraform, K8s YAML, Dockerfiles. |
| 11 | AWS authentication | Uses the EC2 instance role (no keys), reads the account id to build the ECR name. *Moved before the image build only because the image name contains the account id.* |
| 12 | Docker image build | Builds both images, each with two tags. |
| 13 | Trivy image scan | Fails on HIGH/CRITICAL **before** anything is pushed. |
| 14-15 | ECR login and push | `aws ecr get-login-password` piped to `docker login --password-stdin` (the password never appears in logs); pushes immutable tags; no `latest`. |
| 16 | EKS authentication | `aws eks update-kubeconfig`; `kubectl auth can-i` proves permission. **Main only.** |
| 17 | Kubernetes deployment | `scripts/deploy.sh` renders the manifests with exact tags (`envsubst`) and applies them. |
| 18 | Rollout verification | `kubectl rollout status` for both deployments. |
| 19 | API health check | Calls the ALB `/api/restaurants` and the health endpoint. |
| 20 | Post actions | Archive reports, publish HTML, prune images, **automatic rollback** if a deployed build then failed a check, optional email. |

Design points to be able to explain:
* **Fail fast**: cheap checks first, expensive ones later.
* **Build once, deploy that artifact**: the image scanned is the exact image pushed and deployed (by tag).
* **Immutability**: ECR rejects overwriting a tag; deploys refuse `latest`.
* **Separation of duties**: this pipeline cannot change infrastructure; the infra pipeline is manual with approval.
* **Branches**: `develop` runs stages 1-15 (build, scan, push) but does **not** deploy; `main` deploys.

### D. Where should I execute it?
Jenkins UI (browser), plus GitHub for the webhook.

### E. Which directory should I be in?
Nowhere on the server: Jenkins checks the repository out itself. On your laptop, `foodhub-devsecops` for edits and `git push`.

### F. Which file should I create?
None; check these exist: `Jenkinsfile`, `jenkins/Jenkinsfile.infra`, `scripts/*.sh`. Before the first run, fix values at the top of `Jenkinsfile` if you changed names: `EKS_CLUSTER_NAME`, `K8S_NAMESPACE`, `AWS_REGION`.

### G. Complete code
`Jenkinsfile` (application) and `jenkins/Jenkinsfile.infra` (infrastructure) in the zip.

### H. Explain the infra pipeline
`Jenkinsfile.infra`: stages `Checkout`, `Init`, `Validate`, `Plan` (saved plan file archived), **`input` approval** (a human must press Proceed; a timeout aborts), `Apply` of **that exact saved plan**. There is no destroy stage by design: destruction is a deliberate human action from a laptop (Phase 16). It assumes the `terraform-deployer` role via `sts:AssumeRole`, which is the only extra AWS permission Jenkins has.

### I. Execute commands / steps
**1. Webhook (GitHub > repository > Settings > Webhooks > Add):** `http://<JENKINS_PUBLIC_IP>:8080/github-webhook/`, `application/json`, push events. GitHub's IPs must be allowed by `github_webhook_cidrs` in Terraform. If you left it empty the 5-minute polling in the Jenkinsfile still triggers builds.

**2. Grant Jenkins access to the cluster.** Terraform already created an access entry for the Jenkins role. Namespace-scoped RBAC for deployments is applied by `scripts/bootstrap-cluster.sh` in Phase 13. **Do Phase 13 once before the first deploying build**, otherwise stage 16 fails on `can-i`.

**3. First run on `develop` (safe: builds, scans, pushes, does not deploy).**
```bash
git switch develop
git commit --allow-empty -m "Trigger first pipeline run"
git push
```
Open Jenkins > foodhub > develop > the running build > *Stage View* and *Console Output*.

**4. Read results:** Test Result trend, SonarQube link, *Trivy security reports*, Build Artifacts.

**5. See the images in ECR**
```bash
aws ecr list-images --repository-name foodhub-backend --query 'imageIds[].imageTag'
```
**6. Release to the cluster:** open a Pull Request `develop` into `main` on GitHub, merge, and watch the `main` build deploy (needs Phase 13 done).

**7. Test the rollback path deliberately (after a good deploy):** push a change that breaks the health check (for example set a wrong `DB_URL` in the ConfigMap) and watch the `post > failure` branch roll back; then revert the change.

**8. Infrastructure pipeline (optional):** create a second job *Pipeline* named `foodhub-infra` with script path `jenkins/Jenkinsfile.infra`, run **Build Now** manually, review the plan in the console, press **Proceed** only if the plan is what you expect.

### J. Expected output
A green Stage View of all stages on `main` (stages 16-19 skipped on `develop`), ending with `SUCCESS: build-<N> (<sha>)`. The first run of each stage that downloads things (Maven, npm, Trivy DB) is slow (10+ minutes); later runs are faster.
ECR shows tags `build-<N>` and `sha-<8 chars>` on both repositories.

### K. Verification
1. Break a unit test on a branch: stage 5 fails and nothing is pushed.
2. Add a fake secret: Trivy stage fails.
3. Only `main` shows stages 16-19 executed.
4. `kubectl -n foodhub get deploy -o wide` shows the `build-<N>` tag from the latest build, never `latest`.
5. ECR refuses re-pushing the same tag (immutability): a second `docker push` of an existing tag errors.

### L. Troubleshooting
| Problem | Fix |
|---|---|
| Build does not start on push | Webhook delivery red in GitHub > Webhooks > Recent deliveries: URL/port/IP allow-list; fall back to polling or **Scan Multibranch Pipeline Now**. |
| `docker: permission denied` | Add `jenkins` to `docker` group and restart Jenkins. |
| `No such property: ...` / Groovy syntax | Read the line number in the console; the `Jenkinsfile` was authored without running it in Jenkins, so small fixes are possible. |
| `waitForQualityGate` hangs | Webhook problem; see Phase 10. |
| Maven cannot reach Maven Central | Jenkins outbound must be allowed (default egress is open in the security group). |
| Trivy stage fails | Read the table, follow Phase 11 triage. |
| `RepositoryNotFoundException` on push | ECR repository names must match Terraform outputs (`foodhub-backend`, `foodhub-frontend` unless you changed `project`). |
| `tag invalid: The image tag ... already exists` | Immutable tags working as intended; the build number must increase (do not re-run an old pushed tag). |
| `error: You must be logged in to the server (Unauthorized)` at stage 16 | Jenkins role not mapped in EKS access entries, or cluster in another account/region. |
| Disk full on Jenkins | `docker system prune -af` and `df -h`; enlarge the volume if needed. |

### M. Completion checklist
- [ ] `develop` build passes all stages through ECR push.
- [ ] Failing test, failing quality gate, and failing scan each stop the pipeline.
- [ ] `main` build deploys and verifies (after Phase 13).
- [ ] Images in ECR carry immutable tags.
- [ ] I can narrate every stage and explain the rollback strategy.
