# PHASE 11: Trivy Security Scanning

Cost: free (runs on the Jenkins server).

---

### A. What are we doing?
Adding three automated security scans, all driven by one policy file (`trivy.yaml`):
1. **Filesystem scan** (`trivy fs`): known-vulnerable dependencies (Maven, npm), hard-coded secrets, misconfigurations in the source tree.
2. **IaC scan** (`trivy config`): risky settings in Terraform, Kubernetes manifests, Dockerfiles and `docker-compose.yml`.
3. **Image scan** (`trivy image`): vulnerabilities in the built Docker images (OS packages and libraries).

### B. Why are we doing it?
Most real breaches use a known vulnerability or a leaked secret. Scanning every build in the pipeline ("shift left") stops them before they reach a cluster.

### C. How does it work?
* Trivy keeps a vulnerability database (downloaded on first use, cached in `TRIVY_CACHE_DIR`).
* Each scan runs **twice**: pass 1 writes JSON/HTML reports and always succeeds (so you get a report even when the gate fails); pass 2 enforces the policy and exits non-zero on **HIGH or CRITICAL** findings, which fails the stage.
* `ignore-unfixed: true`: findings with no available fix do not fail the build (you cannot patch what is not patched); they still appear in the reports.
* **Exceptions** go only in `.trivyignore.yaml`, each with a statement and an **expiry date**, so an ignored finding must be reviewed again.

### D. Where should I execute it?
On the **Jenkins EC2** (Trivy was installed in Phase 9). You can also run it on your laptop.

### E. Which directory should I be in?
```bash
cd foodhub-devsecops
```

### F. Which file should I create?
None. Policy files exist: `trivy.yaml`, `.trivyignore.yaml`, `jenkins/trivy/html.tpl` (HTML report template).

### G. Complete code
All in the zip. Core of `trivy.yaml`: severities `HIGH,CRITICAL`, scanners `vuln,secret,misconfig`, `ignore-unfixed`, skip-dirs `node_modules`, `target`, `.terraform`, and `ignorefile: .trivyignore.yaml`.

### H. Explain the code
`.trivyignore.yaml` currently carries **three justified exceptions** for the IaC scan, each with a reason and expiry:
* `AVD-AWS-0104` (egress to 0.0.0.0/0): Jenkins and SonarQube must reach GitHub, package mirrors and AWS APIs.
* `AVD-AWS-0040` (public EKS endpoint): a learning-friendly setting restricted by `admin_cidrs`; production should use a private endpoint plus VPN.
* `AVD-AWS-0057` (wildcard in IAM policy): the ELB controller's policy is AWS's official one.
Read each in the file. **Honest note:** these were predicted, not discovered by running Trivy (it could not be installed in the authoring environment), so your first run may show different findings. That is expected: see the triage procedure below.

### I. Execute commands
**1. Confirm Trivy**
```bash
trivy --version
```
**2. Scan the source tree**
```bash
trivy fs --config trivy.yaml .
```
**3. Scan IaC**
```bash
trivy config --config trivy.yaml terraform kubernetes docker-compose.yml backend/Dockerfile frontend/Dockerfile
```
**4. Build and scan an image** (Docker needed)
```bash
docker build -t foodhub-backend:scan backend
trivy image --config trivy.yaml foodhub-backend:scan
```
**5. Triage each finding (the important skill).** For every HIGH/CRITICAL result ask, in order:
1. **Is a fixed version listed?** Upgrade the dependency or base image (for example a newer `eclipse-temurin` or `nginx-unprivileged` tag, or a newer Spring Boot patch version in `pom.xml`) and re-scan. This is the right answer almost always.
2. **Is it a real misconfiguration?** Fix the Terraform/YAML.
3. **Is it a false positive or an accepted risk?** Only then add an entry to `.trivyignore.yaml` with: the id, `statement` explaining why, and `expired_at` no more than 90 days away. Never ignore a finding just to turn the build green.

**6. Prove the gate works:** temporarily add a fake secret line like `AWS_SECRET="AKIAIOSFODNN7EXAMPLE"` in a scratch file, run step 2, see the secret finding and non-zero exit (`echo $?`), then delete the file.

### J. Expected output
Trivy prints a table per target with columns Library / Vulnerability / Severity / Status / Installed Version / Fixed Version / Title, or `Total: 0 (HIGH: 0, CRITICAL: 0)` for clean targets. The exact findings depend on the day because the database updates daily; do not expect identical results.
Exit code `0` = clean under the policy, `1` = policy violated.

### K. Verification
1. After a Jenkins run, open the build page > **Trivy security reports** (HTML) and **Build Artifacts** `reports/*.json`.
2. A deliberately planted fake secret turns the filesystem stage red.
3. Each `.trivyignore.yaml` entry has a statement and an `expired_at` date.
4. Registry side: ECR has **scan on push** enabled (Terraform), a second, independent check you can view in Console > ECR > image > Vulnerabilities.

### L. Troubleshooting
| Problem | Fix |
|---|---|
| `failed to download vulnerability DB` / rate limit (TOOMANYREQUESTS) | Retry later; the cache avoids repeats. Mirrors can be set with `--db-repository`; check the Trivy docs for current values. |
| Scan takes very long first time | DB download; later runs are fast. |
| Many findings in `node_modules` | They are real dependency findings if reported by `package-lock.json`; fix with `npm audit fix` or upgrading the parent package. Do not skip directories to hide them. |
| Findings in base image OS packages | Rebuild with a newer base tag; pin the tag, not `latest`. |
| IaC scan reports something in a `.terraform` folder | That folder is skipped by config; make sure you run from the repo root. |
| `unknown field` in `.trivyignore.yaml` | The YAML ignore format needs `vulnerabilities:`, `misconfigurations:`, `secrets:` sections; compare with the file in the zip and the current Trivy docs. |

### M. Completion checklist
- [ ] I ran fs, config and image scans.
- [ ] I triaged every HIGH/CRITICAL result: fixed, or ignored with reason and expiry.
- [ ] A planted fake secret failed the scan, then was removed.
- [ ] I can explain why scans run twice (report first, then enforce).
- [ ] I understand why `latest` and unpinned base images defeat scanning.
