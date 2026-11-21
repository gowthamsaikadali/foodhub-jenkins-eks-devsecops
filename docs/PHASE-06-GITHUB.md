# PHASE 6: GitHub

Cost: **free**.

---

### A. What are we doing?
Putting the project under Git version control, publishing it to a GitHub repository with `main` and `develop` branches, protecting secrets, and preparing the webhook (the webhook itself is connected in Phase 12, when Jenkins exists).

### B. Why are we doing it?
Git is the single source of truth: Jenkins builds from it, Terraform and Kubernetes definitions live in it. A leaked password in Git history is a real incident, so we set up protection **before** the first commit.

### C. How does it work?
* `git init` creates a hidden `.git` folder that records history.
* `.gitignore` lists files Git must never track: `.env`, `*.tfstate`, personal `terraform.tfvars`, `*.pem`, `node_modules`, `target`.
* **Branches**: `main` = what is deployed to the cluster; `develop` = integration branch where work is tested first. Jenkins builds both, deploys only `main`.
* A **webhook** is GitHub calling a URL on every push so Jenkins starts immediately.

### D. Where should I execute it?
**Windows local machine** (WSL2) plus the GitHub website in your browser.

### E. Which directory should I be in?
```bash
cd foodhub-devsecops
```

### F. Which file should I create?
None. `.gitignore` already exists in the repository root. Create an **empty repository on GitHub** (website): New repository, name `foodhub-devsecops`, **Private**, do **not** add a README/.gitignore/license (the project already has them).

### G. Complete code
`.gitignore` is in the zip. Its most important lines:
```
.env
*.env
!.env.example
*.pem
*.key
*.tfvars
!*.tfvars.example
!terraform/environments/*/*.tfvars
**/.terraform/
*.tfstate
*.tfstate.*
backend/target/
frontend/node_modules/
frontend/dist/
```

### H. Explain the code
* `*.env` + `!.env.example`: ignore every env file **except** the template that has no real values.
* `*.tfvars` ignored (they contain your IP and ARNs), but `!terraform/environments/*/*.tfvars` re-allows the shared environment presets, which contain only sizes and flags.
* `**/.terraform/`: provider plugins (hundreds of MB). `*.tfstate`: state can contain sensitive values, and the real state lives in S3.

### I. Execute commands
**1. Identify yourself to Git (once per computer)**
```bash
git config --global user.name "Your Name"
```
```bash
git config --global user.email "you@example.com"
```
```bash
git config --global core.autocrlf input
```
**2. Initialise the repository with `main` as the first branch**
```bash
git init -b main
```
**3. See what Git would add, and CHECK that no secret file appears**
```bash
git status --short
```
```bash
git check-ignore -v .env
```
(`.env` must be reported as ignored. If you have no `.env` yet, run `touch .env` first to test, or skip.)
**4. Add everything**
```bash
git add .
```
**5. Double-check nothing sensitive is staged**
```bash
git ls-files | grep -Ei '(\.env$|\.tfstate|\.pem$|terraform\.tfvars$|node_modules|/target/)' || echo "clean: no secret or build files tracked"
```
**6. First commit**
```bash
git commit -m "Initial commit: FoodHub three-tier DevSecOps project"
```
**7. Connect to GitHub** (replace `YOUR_USER`)
```bash
git remote add origin https://github.com/YOUR_USER/foodhub-devsecops.git
```
**8. Push `main`** (GitHub asks you to sign in; use a Personal Access Token as the password, or `gh auth login`)
```bash
git push -u origin main
```
**9. Create and push `develop`**
```bash
git switch -c develop
```
```bash
git push -u origin develop
```
**10. Normal daily work**
```bash
git switch develop
git switch -c feature/my-change
# ...edit files...
git add -p
git commit -m "Describe the change"
git push -u origin feature/my-change
```
then open a **Pull Request** into `develop` on GitHub; merge `develop` into `main` to release.

**11. Protect `main` (GitHub website):** Settings > Branches > Add branch protection rule, branch `main`: require a pull request before merging, require status checks (later, the Jenkins build), block force pushes.

**12. Turn on GitHub secret scanning:** Settings > Code security > enable **Secret scanning** and **Push protection** (free for public repos; private repos depend on plan).

### J. Expected output
`git push` ends with `Branch 'main' set up to track remote branch 'main' from 'origin'.` The repository page on GitHub shows all the folders. The check in step 5 prints `clean: no secret or build files tracked`.

### K. Verification
1. On GitHub, open the repository: you must **not** see `.env`, `node_modules`, `target`, `*.tfstate`.
2. `git log --oneline` shows your commit.
3. `git branch -a` lists `main`, `develop`, and their `remotes/origin/...` versions.
4. Search the history for accidental secrets:
```bash
git log -p --all | grep -Ei 'password *[:=] *[^ ]{6,}' | head
```
Only template/placeholder values (like `change-me`) may appear.

**If you ever commit a secret:** deleting it in a later commit is **not enough**: it stays in history. Treat the secret as compromised: rotate it (change the password/key), then clean history (`git filter-repo`) if needed.

**Webhook (do this in Phase 12 once Jenkins is running):** repository Settings > Webhooks > Add webhook: Payload URL `http://<JENKINS_IP>:8080/github-webhook/` (the trailing slash matters), content type `application/json`, event "Just the push event". Jenkins' security group must allow GitHub's webhook IP ranges (`github_webhook_cidrs` in Terraform) or you rely on the pipeline's 5-minute polling.

### L. Troubleshooting
| Error | Fix |
|---|---|
| `remote: Support for password authentication was removed` | Use a Personal Access Token (Settings > Developer settings > Tokens) or `gh auth login`. |
| `fatal: not a git repository` | You are in the wrong folder. `cd foodhub-devsecops`. |
| `.env` shows in `git status` | It is not ignored: check the filename is exactly `.env` and `.gitignore` is in the repo root; if already staged, `git rm --cached .env`. |
| `rejected ... non-fast-forward` | The remote has commits you lack: `git pull --rebase origin main`, then push. Never `--force` on `main`. |
| Large file rejected (>100 MB) | A build folder was staged: `git rm -r --cached frontend/node_modules`. |

### M. Completion checklist
- [ ] Repository exists on GitHub (private) with `main` and `develop`.
- [ ] `.env`, tfstate, keys and node_modules are NOT in the repository.
- [ ] Branch protection on `main` is enabled.
- [ ] I can explain why a secret deleted in a later commit is still leaked.
- [ ] I know the webhook URL format and that it is connected in Phase 12.
