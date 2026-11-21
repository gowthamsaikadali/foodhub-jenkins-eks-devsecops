# PHASE 15: Final Validation

Cost: none beyond what is running. Do this while the environment is up, then go to Phase 16 to clean up.

---

### A. What are we doing?
A full, systematic acceptance test of every tier, every pipeline stage and every security control, with evidence.

### B. Why are we doing it?
"It seems to work" is not a result. Validation turns assumptions into checked facts, and it is exactly what an interviewer or reviewer will ask about.

### C. How does it work?
Go top-down through the checklist. Tick a box only when you have seen the evidence yourself. Anything you cannot verify stays unticked and is written up honestly.

### D. Where should I execute it?
WSL2 terminal and browser; Jenkins and Grafana UIs.

### E. Which directory should I be in?
```bash
cd foodhub-devsecops
```

### F. Which file should I create?
Optionally `VALIDATION-NOTES.md` (not committed if it contains addresses) for your evidence: screenshots and command output.

### G. Complete code
`scripts/smoke-test.sh` automates the API journey: register, login, list restaurants, cart, order, payment, admin status changes, dashboard.

### H. Explain the code
The smoke test checks **business rules**, not just HTTP 200: prices come from the server, an invalid status transition is rejected (400), a customer cannot use admin APIs (403), and an anonymous request to a protected API is 401.

### I. Execute commands
**Application**
```bash
ALB=$(kubectl -n foodhub get ingress foodhub -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
bash scripts/smoke-test.sh "http://$ALB" admin@yourdomain.com '<your admin password>'
```
**Infrastructure**
```bash
terraform -chdir=terraform plan -var-file=environments/dev/dev.tfvars
```
(expect `No changes.`)
```bash
kubectl -n foodhub get deploy,pods,hpa,ingress,networkpolicy,externalsecret
```
```bash
kubectl -n foodhub get deploy -o jsonpath='{range .items[*]}{.metadata.name}{" "}{.spec.template.spec.containers[0].image}{"\n"}{end}'
```
Images must show `build-N` tags.
**Security spot checks**
```bash
aws rds describe-db-instances --query 'DBInstances[].[PubliclyAccessible,StorageEncrypted]'
```
```bash
aws ecr describe-repositories --query 'repositories[].[repositoryName,imageTagMutability,imageScanningConfiguration.scanOnPush]'
```
```bash
git -C . log -p --all | grep -Ei 'AKIA[0-9A-Z]{16}' || echo "no AWS access keys in Git history"
```

### J. Expected output
The smoke test prints `PASS` lines and `ALL SMOKE TESTS PASSED`. Output of the other commands matches the descriptions above: `No changes.`; tags `build-N`; RDS `false true`; ECR `IMMUTABLE true`; no keys found.

### K. Verification (the master checklist)
**Tier 1, frontend**
- [ ] Home, restaurant, cart, checkout, orders, tracking, profile work through the ALB.
- [ ] Refreshing `/orders/<id>` does not 404 (SPA fallback).
- [ ] Admin: dashboard, restaurants, foods, orders, customers.

**Tier 2, backend**
- [ ] Swagger lists all endpoints; JWT required for protected ones.
- [ ] Customer cannot call `/api/admin/**` (403); admin cannot manage another admin's restaurant (404/403).
- [ ] Order totals come from the server; status transitions enforced.
- [ ] `/actuator` is not reachable from the internet.

**Tier 3, database**
- [ ] RDS private and encrypted, reachable only from nodes.
- [ ] Flyway history has V1-V3; data persists across backend restarts.

**Infrastructure and delivery**
- [ ] `terraform plan` shows no drift. State in S3 with versioning.
- [ ] Jenkins uses the instance role; no AWS keys anywhere.
- [ ] SonarQube gate enforced; Trivy fs / IaC / image scans enforced.
- [ ] ECR images immutable-tagged and scanned.
- [ ] A bad build rolls back automatically (demonstrated once).

**Operations**
- [ ] HPA, NetworkPolicies, Pod Security verified.
- [ ] Grafana dashboards live; an alert fired and was seen.
- [ ] Secrets only in Secrets Manager / Kubernetes Secrets, never in Git or logs.

### L. Troubleshooting
Use the table for the failing tier in its phase guide, or `docs/TROUBLESHOOTING.md`. Method: read the exact error, find which component printed it (browser console, Nginx, backend log, RDS, Jenkins console), reproduce with the smallest command, fix one thing, re-test.

### M. Completion checklist
- [ ] Every box in section K is ticked or has a written, honest exception.
- [ ] Screenshots saved: ALB site, Jenkins stage view, SonarQube result, Trivy report, Grafana, `kubectl get all`.
- [ ] I can demo the project in 10 minutes and answer "what would you change for real production?" (see `docs/INTERVIEW-QA.md`).
