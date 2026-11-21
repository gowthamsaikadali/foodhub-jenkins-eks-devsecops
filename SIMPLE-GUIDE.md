# FoodHub on AWS: Simple Execution Guide

No local testing. Steps and commands only. Replace `<PLACEHOLDERS>`. Use a WSL2 Ubuntu terminal on your laptop.
AWS costs money from Step 3 on (about ₹800-950/day). Do Step 11 when you stop.
Without local testing, the first Jenkins build is where any compile/test error shows up. Read the error in the console, fix that line, push again.

---

## Step 1: Install tools on your laptop
```bash
sudo apt update && sudo apt install -y git unzip curl jq
```
Install AWS CLI v2:
```bash
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o awscliv2.zip
unzip awscliv2.zip && sudo ./aws/install
```
Install Terraform (1.10+), kubectl, helm, and the Session Manager plugin (follow each tool's official Ubuntu install page). Check:
```bash
aws --version && terraform version && kubectl version --client && helm version
```

## Step 2: Push the project to GitHub
1. GitHub website: create an empty **private** repo `foodhub-jenkins-eks-devsecops` (no README, no .gitignore).
2. Unzip the project and run:
```bash
cd foodhub-devsecops
git config --global user.name "<Your Name>"
git config --global user.email "<you@example.com>"
git init -b main
git add .
git ls-files | grep -Ei '(\.env$|\.tfstate|\.pem$|node_modules)' || echo clean
git commit -m "Initial commit"
git remote add origin https://github.com/<YOUR_USER>/foodhub-jenkins-eks-devsecops.git
git push -u origin main
git switch -c develop
git push -u origin develop
```
3. GitHub: create a Personal Access Token (fine-grained, read-only Contents on this repo) for Jenkins. Protect branch `main`.

## Step 3: Prepare AWS
1. AWS Console: turn on MFA for the root user.
2. IAM > Users > create `foodhub-admin`, attach `AdministratorAccess`, enable MFA, create an access key (CLI).
3. Configure the CLI:
```bash
aws configure --profile foodhub        # region: ap-south-1, output: json
export AWS_PROFILE=foodhub
aws sts get-caller-identity
curl -s https://checkip.amazonaws.com   # note your public IP
```
4. Create the Terraform state bucket and budget alarm:
```bash
cd foodhub-devsecops/terraform/bootstrap
cp terraform.tfvars.example terraform.tfvars
```
Edit `terraform.tfvars`: set `budget_email`.
```bash
terraform init
terraform apply
```
Note the bucket name printed.

## Step 4: Create the infrastructure (Terraform)
```bash
cd foodhub-devsecops/terraform
cp terraform.tfvars.example terraform.tfvars
```
Edit `terraform.tfvars`:
```hcl
state_bucket_name    = "foodhub-tfstate-<ACCOUNT_ID>-ap-south-1"
admin_cidrs          = ["<YOUR_PUBLIC_IP>/32"]
admin_principal_arns = ["arn:aws:iam::<ACCOUNT_ID>:user/foodhub-admin"]
```
Edit `environments/dev/backend.hcl`: set the same bucket name. Then:
```bash
terraform fmt -recursive
terraform init -backend-config=environments/dev/backend.hcl
terraform validate
terraform plan -var-file=environments/dev/dev.tfvars -out=dev.plan
terraform apply dev.plan
terraform output
aws eks update-kubeconfig --region ap-south-1 --name foodhub-dev-eks
kubectl get nodes
```
Takes 15-25 minutes. If `validate` or `plan` errors, fix the file and line it names, then rerun.

## Step 5: Set up Jenkins
Get the server ID:
```bash
terraform output jenkins_url
terraform output jenkins_instance_id
aws ssm start-session --target <JENKINS_INSTANCE_ID>
```
On the Jenkins server:
```bash
sudo -iu ubuntu
git clone https://<YOUR_USER>:<GITHUB_TOKEN>@github.com/<YOUR_USER>/foodhub-jenkins-eks-devsecops.git
bash foodhub-jenkins-eks-devsecops/scripts/install-jenkins-tools.sh
aws sts get-caller-identity
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
```
In the browser (`jenkins_url`):
1. Paste the password, install suggested plugins, create your admin user.
2. Manage Jenkins > Plugins: install SonarQube Scanner, Pipeline Stage View, HTML Publisher, Docker Pipeline, Credentials Binding, JUnit, GitHub Integration, Timestamper, Workspace Cleanup, Pipeline Utility Steps.
3. Manage Jenkins > Credentials > Global > add *Username with password*, ID `github-pat` (GitHub user + token).
4. New Item > `foodhub` > Multibranch Pipeline > GitHub repo + `github-pat` > script path `Jenkinsfile` > Save.

## Step 6: Set up SonarQube
```bash
terraform output sonarqube_url
terraform output sonarqube_instance_id
aws ssm start-session --target <SONARQUBE_INSTANCE_ID>
```
On the SonarQube server:
```bash
sudo -iu ubuntu
git clone https://<YOUR_USER>:<GITHUB_TOKEN>@github.com/<YOUR_USER>/foodhub-jenkins-eks-devsecops.git
bash foodhub-jenkins-eks-devsecops/scripts/install-sonarqube.sh
```
In the browser (`http://<SONAR_ADDRESS>:9000`):
1. Login `admin` / `admin`, set a new password.
2. My Account > Security > Generate token. Copy it.
3. Administration > Webhooks > Create: URL `http://<JENKINS_PRIVATE_IP>:8080/sonarqube-webhook/`.

In Jenkins:
1. Credentials > add *Secret text*, ID `sonar-token`, value = the token.
2. Manage Jenkins > System > SonarQube servers > Add: name `sonarqube`, URL `http://<SONAR_ADDRESS>:9000`, token `sonar-token`. Save.

## Step 7: Prepare the cluster (once)
On your laptop:
```bash
cd foodhub-devsecops
bash scripts/bootstrap-cluster.sh dev
kubectl -n kube-system get deploy aws-load-balancer-controller
kubectl -n external-secrets get pods
kubectl -n foodhub get externalsecret
```
Wait until the ExternalSecret shows `SecretSynced`.

## Step 8: Run the pipeline and deploy
1. GitHub > Settings > Webhooks > Add: `http://<JENKINS_PUBLIC_IP>:8080/github-webhook/`, `application/json`, push events.
2. Build `develop` (builds, scans, pushes images, no deploy):
```bash
git switch develop
git commit --allow-empty -m "Trigger pipeline"
git push
```
3. Jenkins > foodhub > develop: open the build, watch Console Output. If a stage fails (compile, test, Sonar, Trivy), fix the cause and push again.
4. Check images:
```bash
aws ecr list-images --repository-name foodhub-backend --query 'imageIds[].imageTag'
aws ecr list-images --repository-name foodhub-frontend --query 'imageIds[].imageTag'
```
5. Deploy: on GitHub open a Pull Request `develop` > `main` and merge. The `main` build deploys to EKS.
6. Get the site address and create the admin:
```bash
kubectl -n foodhub get pods
kubectl -n foodhub get ingress foodhub -o jsonpath='{.status.loadBalancer.ingress[0].hostname}{"\n"}'
bash scripts/create-admin.sh admin@example.com
```
Open `http://<ALB_HOSTNAME>` (customer) and `http://<ALB_HOSTNAME>/admin/login` (admin). The ALB takes 2-4 minutes to appear.

Manual deploy (only if you skip Jenkins):
```bash
export ECR_REGISTRY="$(aws sts get-caller-identity --query Account --output text).dkr.ecr.ap-south-1.amazonaws.com"
IMAGE_TAG=build-1 bash scripts/deploy.sh
```

## Step 9: Install monitoring
```bash
bash scripts/install-monitoring.sh
kubectl -n monitoring get pods
kubectl -n monitoring get secret grafana-admin -o jsonpath='{.data.admin-password}' | base64 -d; echo
kubectl -n monitoring port-forward svc/kube-prometheus-stack-grafana 3000:80
```
Open http://localhost:3000, user `admin`, open the FoodHub dashboards.

## Step 10: Check everything works
```bash
ALB=$(kubectl -n foodhub get ingress foodhub -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
bash scripts/smoke-test.sh "http://$ALB" admin@example.com '<ADMIN_PASSWORD>'
kubectl -n foodhub get deploy,pods,hpa,ingress,networkpolicy,externalsecret
terraform -chdir=terraform plan -var-file=environments/dev/dev.tfvars
```
Take screenshots: the website, the Jenkins stage view, the SonarQube result, the Trivy report, Grafana, `kubectl get pods`.

## Step 11: Delete everything (do this every time you stop)
```bash
cd foodhub-devsecops
bash scripts/cleanup-aws.sh
kubectl delete namespace foodhub monitoring --wait=true
terraform -chdir=terraform destroy -var-file=environments/dev/dev.tfvars
```
Check nothing is left:
```bash
aws eks list-clusters
aws rds describe-db-instances --query 'DBInstances[].DBInstanceIdentifier'
aws ec2 describe-instances --filters Name=instance-state-name,Values=running,stopped --query 'Reservations[].Instances[].InstanceId'
aws ec2 describe-nat-gateways --filter Name=state,Values=available --query 'NatGateways[].NatGatewayId'
aws ec2 describe-addresses --query 'Addresses[].PublicIp'
aws elbv2 describe-load-balancers --query 'LoadBalancers[].LoadBalancerName'
aws ec2 describe-volumes --filters Name=status,Values=available --query 'Volumes[].VolumeId'
```
All lists must be empty. Check Billing the next day.

---

## Quick fixes
| Problem | Command or action |
|---|---|
| Pod not starting | `kubectl -n foodhub describe pod <POD>` and `kubectl -n foodhub logs <POD>` |
| Backend crashing | `kubectl -n foodhub logs deploy/foodhub-backend --tail=100` |
| Can't reach Jenkins/SonarQube | your IP changed: update `admin_cidrs`, run `terraform apply -var-file=environments/dev/dev.tfvars` |
| kubectl Unauthorized | `aws eks update-kubeconfig --region ap-south-1 --name foodhub-dev-eks` |
| Trivy fails the build | upgrade the dependency/base image named in the report |
| Rollback | `bash scripts/rollback.sh` |
| Destroy stuck on VPC | `bash scripts/cleanup-aws.sh`, delete leftover load balancers, retry |
