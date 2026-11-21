# PHASE 10: SonarQube

Cost: SonarQube EC2 is part of the Phase 8 estimate. Stop it when idle.

---

### A. What are we doing?
Running SonarQube Community Build (with PostgreSQL) on its own server, creating a project token, connecting Jenkins to it, and enforcing a **quality gate** that fails the pipeline if the code is not good enough.

### B. Why are we doing it?
SonarQube performs static analysis (SAST): bugs, code smells, security hotspots, duplicated code, and test coverage. Catching a SQL-injection pattern in review is far cheaper than in production.

### C. How does it work?
Jenkins runs `sonar-scanner`, which uploads results to the SonarQube server. The server computes a verdict against the **Quality Gate**. SonarQube then calls a **webhook** back to Jenkins so the stage `waitForQualityGate` knows the verdict and aborts the pipeline on failure.

### D. Where should I execute it?
The **SonarQube EC2** (Session Manager) for installation; browser for configuration.

### E. Which directory should I be in?
On the server: wherever you cloned the repository.

### F. Which file should I create?
None to author. `sonar-project.properties` (repository root) is already in the zip: project key `foodhub`, sources `backend/src/main/java` and `frontend/src`, JaCoCo report path.

### G. Complete code
`scripts/install-sonarqube.sh` (runs SonarQube and PostgreSQL in Docker Compose, creates the random DB password in `/opt/sonarqube/.env` with mode 600, sets the required kernel settings `vm.max_map_count` and file limits).

### H. Explain the code
* Elasticsearch inside SonarQube refuses to start unless `vm.max_map_count >= 524288`; the script writes `/etc/sysctl.d/99-sonarqube.conf`.
* Two named volumes keep data and extensions across container restarts.
* Port 9000 is open **only to your IP** (security group).
* `sonarqube:community` is the free edition. It analyses the default branch only; for this project the pipeline analyses whichever branch runs and that is fine for learning.

### I. Execute commands
**1. Get the address (laptop)**
```bash
cd terraform && terraform output sonarqube_url && terraform output sonarqube_instance_id
```
**2. Shell on the server**
```bash
aws ssm start-session --target <sonarqube_instance_id>
```
**3. Install**
```bash
sudo -iu ubuntu
git clone https://github.com/YOUR_USER/foodhub-devsecops.git
bash foodhub-devsecops/scripts/install-sonarqube.sh
```
(about 3-5 minutes; ends with `SonarQube is UP`.)

**4. First login (browser):** `http://<sonarqube address>:9000`, user `admin`, password `admin`; it forces you to change the password. Choose a strong one and store it in a password manager.

**5. Create the token:** top-right avatar > My Account > Security > Generate Token: name `jenkins`, type **Project Analysis Token** for project `foodhub` (or a User token for simplicity), expiry 90 days. Copy it now; it is shown once.

**6. Add it to Jenkins:** Manage Jenkins > Credentials > Global > Add > *Secret text*, ID `sonar-token`.

**7. Tell Jenkins where SonarQube is:** Manage Jenkins > System > **SonarQube servers** > Add: Name **`sonarqube`** (must match `SONARQUBE_SERVER` in the Jenkinsfile), URL `http://<sonarqube private or public address>:9000`, server authentication token = `sonar-token`.

**8. Webhook back to Jenkins:** SonarQube > Administration > Configuration > Webhooks > Create: Name `jenkins`, URL `http://<jenkins address>:8080/sonarqube-webhook/` (slash at the end).
> The Jenkins security group allows port 8080 from your IP only. For the webhook to arrive, use Jenkins' **private IP** (both servers are in the same VPC, and the security groups created by Terraform allow SonarQube to call Jenkins on 8080 inside the VPC). Check `terraform output` or the EC2 console for the private IP.

**9. Quality gate:** Quality Gates > use the built-in **Sonar way** (new code: no new bugs/vulnerabilities, hotspots reviewed, coverage >= 80% on new code, duplication <= 3%). It is strict. For a first run on a learning project you can **copy** it as `foodhub-gate` and relax *coverage on new code* (for example to 50%); document the reason. Set `foodhub-gate` as default. Never lower the security conditions.

**10. Run the pipeline** (Phase 12) or test the scanner by hand on the Jenkins server:
```bash
cd foodhub-devsecops/backend && mvn -B verify
cd .. && sonar-scanner -Dsonar.host.url=http://<sonarqube>:9000 -Dsonar.token=<token>
```

### J. Expected output
* `SonarQube is UP.` from the installer.
* After the first analysis the project page shows Quality Gate **Passed** or **Failed** with the metrics: bugs, vulnerabilities, hotspots, coverage, duplications, size.
* In Jenkins the stage `Quality gate` is green, or red with the message `Pipeline aborted due to quality gate failure: ERROR`.

### K. Verification
1. SonarQube > Projects > FoodHub exists after the first run.
2. Open a finding, read "Why is this an issue?", fix one deliberately (for example add a short test), re-run: the count drops.
3. Prove the gate works: temporarily add `String password = "admin123";` in a Java class, push, and watch the gate (or the hotspot) catch it. Revert it.
4. Backend coverage is only reported if `mvn verify` produced `backend/target/site/jacoco/jacoco.xml` (JaCoCo is configured in `pom.xml`).

### L. Troubleshooting
| Problem | Fix |
|---|---|
| Container exits: `max virtual memory areas vm.max_map_count [65530] is too low` | `sudo sysctl -w vm.max_map_count=524288` (the script does this; re-run it). |
| `Not enough memory` / SonarQube keeps restarting | Needs about 4 GB RAM: use `t3.medium` or larger (`sonarqube_instance_type`). |
| Stage hangs at `waitForQualityGate` | The webhook did not arrive: check URL ends with `/sonarqube-webhook/`, uses the Jenkins private IP, and port 8080 is allowed from the SonarQube security group. Check SonarQube > Administration > Webhooks > last delivery status. |
| `401 Unauthorized` in the scan | Wrong or expired token credential `sonar-token`. |
| `Not authorized. Analyzing this project requires authentication` | Same as above. |
| Coverage shows 0% | The Jacoco XML was not generated or the path in `sonar.coverage.jacoco.xmlReportPaths` is wrong. |
| Cannot open `:9000` from browser | `admin_cidrs` out of date, or still starting (first start 2-4 minutes). |

### M. Completion checklist
- [ ] SonarQube reachable, admin password changed.
- [ ] Token created and stored **only** as a Jenkins credential.
- [ ] Jenkins "SonarQube servers" entry named `sonarqube` works (Test connection).
- [ ] Webhook to Jenkins created and delivering.
- [ ] I understand the quality gate and why I did not weaken security conditions.
