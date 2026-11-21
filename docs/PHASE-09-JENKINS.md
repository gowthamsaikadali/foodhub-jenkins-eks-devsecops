# PHASE 9: Jenkins on EC2

Cost: Jenkins EC2 (instance size in `jenkins_instance_type`) is already included in the Phase 8 estimate (about ₹2,000-3,500/month if left on 24x7). **Stop the instance when not in use** (Phase 16).

---

### A. What are we doing?
Installing Jenkins and every tool the pipeline calls (Java 21, Maven, Node, Docker, Trivy, Terraform, kubectl, Helm, AWS CLI, SonarScanner) on the Jenkins server that Terraform created, then configuring plugins, credentials and the SonarQube connection.

### B. Why are we doing it?
Jenkins is the automation engine: on every push it builds, tests, scans, packages and deploys. A server (not your laptop) makes releases consistent and auditable.

### C. How does it work?
* The EC2 instance has an **instance profile** (IAM role), so Jenkins gets AWS permissions **without access keys stored anywhere**. The AWS CLI finds them automatically.
* Jenkins listens on port 8080; the security group allows it only from `admin_cidrs` (your IP).
* The pipeline (`Jenkinsfile`) runs shell steps on the Jenkins machine, so the tools must be installed there. `scripts/install-jenkins-tools.sh` does it.

### D. Where should I execute it?
Browser (Jenkins UI) and **the Jenkins EC2** over SSH or, preferably, **AWS Systems Manager Session Manager** (the instance profile includes SSM, so no SSH key or open port 22 is required).

### E. Which directory should I be in?
On your laptop: `foodhub-devsecops/terraform` (to read outputs). On the server: your home directory.

### F. Which file should I create?
None to author. Copy `scripts/install-jenkins-tools.sh` onto the server (or `git clone` your repository there).

### G. Complete code
`scripts/install-jenkins-tools.sh` is in the zip. It runs 10 numbered steps and is safe to re-run.

### H. Explain the code
Steps: base packages; Java 21; Jenkins LTS repo and install; Docker (adds `jenkins` to the `docker` group); Maven; Node.js 20+; AWS CLI v2; Terraform; kubectl (minor version should be within one of the cluster: `K8S_MINOR`); Helm; Trivy (apt repository); SonarScanner CLI; then restarts Jenkins and prints the initial admin password location.
Tool versions can be overridden with environment variables at the top of the script; **check the latest versions** you want to use.

### I. Execute commands
**1. Get the server details (laptop)**
```bash
cd terraform
```
```bash
terraform output jenkins_url
```
```bash
terraform output jenkins_instance_id
```
**2. Open a shell on the server without SSH (laptop; needs the Session Manager plugin, or use Console > EC2 > Connect > Session Manager)**
```bash
aws ssm start-session --target <jenkins_instance_id>
```
**3. On the server: get the script and run it**
```bash
sudo -iu ubuntu
```
```bash
git clone https://github.com/YOUR_USER/foodhub-devsecops.git
```
(private repository: use a token, or copy the file with the console's upload, or paste it with `nano`.)
```bash
bash foodhub-devsecops/scripts/install-jenkins-tools.sh
```
**4. Verify the tools**
```bash
for t in java mvn node docker trivy terraform kubectl helm aws sonar-scanner; do printf '%-14s' $t; command -v $t >/dev/null && echo OK || echo MISSING; done
```
**5. Prove the instance profile works (no keys configured)**
```bash
aws sts get-caller-identity
```
**6. Read the first-login password**
```bash
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
```
**7. Open Jenkins in the browser** at the `jenkins_url` output, paste the password, choose **Install suggested plugins**, create your admin user.

**8. Install extra plugins:** Manage Jenkins > Plugins > Available: *SonarQube Scanner*, *Pipeline: Stage View*, *HTML Publisher*, *Docker Pipeline*, *Credentials Binding*, *JUnit*, *GitHub Integration*, *Timestamper*, *Workspace Cleanup*, *Email Extension* (optional), *Pipeline Utility Steps*. Restart when asked.

**9. Credentials** (Manage Jenkins > Credentials > System > Global > Add):
* Kind *Secret text*, ID `sonar-token`: the token from Phase 10 (done after SonarQube exists).
* GitHub access: *Username with password*, ID `github-pat`, username = GitHub user, password = a **fine-grained PAT with read-only "Contents"** for this repo (only if the repository is private).
* **No AWS credentials are added.** The instance profile does that job.

**10. Create the pipeline job:** New Item > `foodhub` > *Multibranch Pipeline* > Branch Sources > GitHub (or Git) > repository URL and `github-pat` > Build Configuration: *by Jenkinsfile*, script path `Jenkinsfile`. Save; it scans branches `main` and `develop`.

**11. Harden Jenkins:** Manage Jenkins > Security: *Security Realm* = Jenkins' own user database, **disable sign-ups**, *Authorization* = Logged-in users can do anything (single user) or Matrix; *Agents > Built-in node executors* = 2 (small box).

### J. Expected output
* Step 4 prints `OK` for all ten tools.
* Step 5 prints an `Arn` like `arn:aws:sts::<account>:assumed-role/foodhub-dev-jenkins-role/i-...`.
* Browser shows the Jenkins dashboard; the multibranch job scans and finds the `Jenkinsfile`.

### K. Verification
1. `sudo systemctl status jenkins` shows `active (running)`.
2. Jenkins > Manage Jenkins > System Information lists `JAVA_HOME` of Java 21.
3. Run `aws ecr describe-repositories --region ap-south-1` on the server: it works (role allows ECR). Run `aws iam list-users`: it must be **denied** (least privilege).
4. Run `kubectl get nodes` after Phase 13 grants the Jenkins role access.

### L. Troubleshooting
| Problem | Fix |
|---|---|
| Browser cannot reach `:8080` | Your public IP changed: update `admin_cidrs` and re-apply. Or instance stopped. |
| `Jenkins failed to start` | `sudo journalctl -u jenkins -n 100 --no-pager`; usually Java version or RAM. Use at least `t3.medium`. |
| `permission denied ... docker.sock` in a build | `sudo usermod -aG docker jenkins && sudo systemctl restart jenkins`. |
| `Unable to locate credentials` | The instance profile is missing: check the EC2's IAM role in the console. |
| Plugin install fails | Wait and retry; check disk with `df -h`. |
| Trivy first run very slow | It is downloading its vulnerability database; the cache is kept in `TRIVY_CACHE_DIR`. |

### M. Completion checklist
- [ ] Jenkins reachable only from my IP; admin user created; sign-up disabled.
- [ ] All ten tools verified.
- [ ] `aws sts get-caller-identity` shows the instance role; there are no AWS keys in Jenkins.
- [ ] Required plugins installed.
- [ ] Multibranch job created and scans the repository.
