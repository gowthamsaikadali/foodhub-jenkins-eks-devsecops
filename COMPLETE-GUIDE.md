# FoodHub: Complete Step-by-Step Implementation Guide (Start to End)

One file, 16 phases, in the order you do them. Every phase follows the same A-M format: **A** What, **B** Why, **C** How it works, **D** Where to run, **E** Directory, **F** File, **G** Code, **H** Explanation, **I** Commands, **J** Expected output, **K** Verification, **L** Troubleshooting, **M** Completion checklist.

**Rules for following it**
1. Do the phases in order. Do not skip ahead.
2. Finish a phase's verification (K) before starting the next.
3. Phases 1-6 are free and local. From Phase 7 onward AWS costs real money: set the budget alarm first and **destroy everything when you stop (Phase 16)**.
4. The code itself is in the project folders; each phase tells you which file to open. Parts of the code were never run by the author (backend compile, Terraform validate, Trivy): expect small first-run fixes, see Troubleshooting in each phase.

## Contents

- [PHASE 1: Architecture and Prerequisites](#phase-1-architecture-and-prerequisites)
- [PHASE 2: React Frontend](#phase-2-react-frontend)
- [PHASE 3: Spring Boot Backend](#phase-3-spring-boot-backend)
- [PHASE 4: MySQL Integration](#phase-4-mysql-integration)
- [PHASE 5: Local Docker Deployment](#phase-5-local-docker-deployment)
- [PHASE 6: GitHub](#phase-6-github)
- [PHASE 7: AWS Preparation](#phase-7-aws-preparation)
- [PHASE 8: Terraform Infrastructure](#phase-8-terraform-infrastructure)
- [PHASE 9: Jenkins on EC2](#phase-9-jenkins-on-ec2)
- [PHASE 10: SonarQube](#phase-10-sonarqube)
- [PHASE 11: Trivy Security Scanning](#phase-11-trivy-security-scanning)
- [PHASE 12: Jenkins CI/CD Pipeline](#phase-12-jenkins-cicd-pipeline)
- [PHASE 13: Kubernetes Deployment on EKS](#phase-13-kubernetes-deployment-on-eks)
- [PHASE 14: Monitoring with Prometheus, Grafana and Alertmanager](#phase-14-monitoring-with-prometheus-grafana-and-alertmanager)
- [PHASE 15: Final Validation](#phase-15-final-validation)
- [PHASE 16: Production Hardening and Cleanup](#phase-16-production-hardening-and-cleanup)

See also: `docs/COST.md`, `docs/TROUBLESHOOTING.md`, `docs/CHECKLIST.md`, `docs/GLOSSARY.md`, `docs/INTERVIEW-QA.md`.

---

## PHASE 1: Architecture and Prerequisites

Cost of this phase: **free** (reading only).

---

#### A. What are we doing?
Understanding what we will build before we build it: the application, the cloud network, the delivery pipeline and the monitoring.

#### B. Why are we doing it?
In a DevOps interview you are expected to explain **why** each piece exists and how the pieces talk to each other. If you can draw and explain this phase from memory, you can answer most architecture questions.

#### C. How does it work?

#### 1. Two halves

| Half | What it is | Tools |
|---|---|---|
| **The application** | The product users touch | React, Spring Boot, MySQL |
| **The platform** | How code reaches production safely and is watched | Terraform, Jenkins, SonarQube, Trivy, ECR, EKS, Prometheus, Grafana |

#### 2. Three-tier architecture

A three-tier app splits into layers. Each layer talks only to its neighbour, which makes it secure and independently scalable.

| Tier | Technology | Runs on | Job |
|---|---|---|---|
| 1. Presentation | React served by Nginx | Pods on EKS | Draws the UI in the browser, calls the backend over HTTP |
| 2. Application | Spring Boot (Java 21) | Pods on EKS | Login and JWT, business rules, order totals, payment simulation |
| 3. Database | RDS MySQL 8 | AWS managed, private subnet | Users, restaurants, foods, carts, orders, payments |

Rules to remember: (1) the browser never talks to the database; (2) the backend computes prices, never the browser, because the browser can be tampered with; (3) the database has no public IP and only the worker nodes may connect.

#### 3. AWS network (what Terraform builds in Phase 8)

```
                          Internet
                             |
                    +--------v--------+
                    |  ALB (HTTP/S)   |   created by the AWS Load Balancer Controller from the Kubernetes Ingress
                    +--------+--------+
+----------------------------|------------------------------------------------------+
| VPC 10.0.0.0/16            |                                  region ap-south-1    |
|  PUBLIC subnets (2 AZ)     |                                                       |
|   ALB   NAT gateway   Jenkins EC2   SonarQube EC2                                  |
|  PRIVATE APP subnets (2 AZ)|                                                       |
|   EKS worker nodes:  ns foodhub (frontend, backend)  ns monitoring  ns external-secrets |
|  PRIVATE DB subnets (2 AZ)    <-- no route to the internet at all                  |
|   RDS MySQL 8 (encrypted, not public)        port 3306 allowed only from the EKS SG |
+-------------------------------------------------------------------------------------+
 Outside the VPC (AWS managed): ECR, Secrets Manager, S3 (Terraform state), IAM, KMS, CloudWatch
```

| AWS service | Purpose | Analogy |
|---|---|---|
| VPC | Your private network | Your fenced property |
| Public subnet | Has a route to the Internet Gateway | Front gate and driveway |
| Private subnet | No inbound internet route | Rooms inside the house |
| Internet Gateway | Two-way door to the internet | Front door |
| NAT Gateway | Lets private resources go out but blocks inbound | One-way exit door |
| Security Group | Stateful firewall per resource | Bouncer with a guest list |
| EKS | Managed Kubernetes control plane | A manager who schedules your containers |
| ECR | Private Docker registry | Private warehouse for images |
| RDS | Managed MySQL with backups | Database with a built-in admin |
| Secrets Manager | Stores credentials, rotatable, audited | Locked safe |
| IAM | Who may do what | Keycards |
| ACM | Free TLS certificates | The padlock |
| ALB | Layer-7 load balancer | Receptionist routing visitors |
| S3 | Holds Terraform state | Filing cabinet for infrastructure records |

#### 4. Runtime request path (a customer ordering food)
1. Browser requests the site; the ALB (TLS terminated with an ACM certificate when you have a domain) forwards it.
2. The ALB sends `/` to the frontend Service (Nginx pod, which returns the React files).
3. React calls `/api/...`; the ALB routes `/api/*` to the backend Service.
4. The backend validates the JWT, runs business logic and queries RDS on 3306.
5. The DB password reached the pod through: **RDS generates it -> Secrets Manager stores it -> External Secrets Operator reads it using an IAM role (Pod Identity) -> creates a Kubernetes Secret -> injected as environment variables**. It is never in Git.

#### 5. DevSecOps pipeline ("shift left": find problems as early as possible)

```
git push -> GitHub -> webhook -> Jenkins
 1 Checkout   2 npm ci / mvn deps   3 frontend build   4 backend build   5 unit tests
 6 SonarQube analysis   7 Quality gate  (red = STOP)
 8 Trivy filesystem scan (code, dependencies, secrets)  (HIGH/CRITICAL = STOP)
 9 Terraform validate   10 Trivy IaC scan (Terraform, Kubernetes, Dockerfiles)
 11 AWS identity   12 Docker build   13 Trivy image scan (STOP)
 14 ECR login + push (tags build-N and sha-<commit>)
 15 EKS login   16 kubectl deploy (exact tag, never latest)   17 rollout check   18 API health check
 19 Notify; on failure after deploy -> automatic rollback
```
Why two pipelines: an application commit must never be able to change your VPC or database. The **infrastructure pipeline** (`jenkins/Jenkinsfile.infra`) is manual-only, plans, waits for human approval, then applies, and cannot destroy.

#### 6. How the tools interact

| Interaction | Mechanism |
|---|---|
| GitHub -> Jenkins | Webhook (HTTP POST on push) |
| Jenkins -> SonarQube | Scanner uploads analysis; SonarQube calls Jenkins back (webhook) with the quality gate result |
| Jenkins -> Trivy | CLI in pipeline stages; non-zero exit code fails the build |
| Jenkins -> ECR | `aws ecr get-login-password` using the EC2 **instance profile** (no stored keys) |
| Jenkins -> EKS | `aws eks update-kubeconfig`; authorised by an EKS **access entry** limited to the `foodhub` namespace |
| EKS nodes -> ECR | Node IAM role with `AmazonEC2ContainerRegistryReadOnly` (no imagePullSecrets) |
| Backend -> RDS | JDBC over 3306, allowed by a security-group-to-security-group rule |
| EKS -> Secrets Manager | External Secrets Operator with an IAM role via EKS Pod Identity |
| Prometheus -> backend | ServiceMonitor scrapes `/actuator/prometheus` on port 8081 |

#### 7. Monitoring

```
Spring Boot (Actuator + Micrometer) --/actuator/prometheus--+
node-exporter (per node: CPU, RAM, disk) --------------------+--> Prometheus --> Grafana (dashboards)
kube-state-metrics (pod/deployment state, restarts) ---------+        |
                                                                      +--> Alertmanager --> email/Slack
```
Installed with one Helm chart, `kube-prometheus-stack`. Grafana is reached through `kubectl port-forward`, never a public URL.

#### D. Where should I execute it?
Nowhere yet. This phase is reading. The prerequisite installs below run on your **Windows machine** (preferably inside **WSL2 Ubuntu**).

#### E. Which directory should I be in?
Not applicable yet. From Phase 2 on you work inside `foodhub-devsecops/` (the unzipped repository).

#### F. Which file should I create?
None. Unzip the delivered zip; it creates `foodhub-devsecops/` containing every file.

#### G. Complete code
The whole project is already in the zip. Open `README.md` for the file map.

#### H. Explain the code
Prerequisite list and why each tool is needed:

| Tool | Version | Why |
|---|---|---|
| Git | latest | Source control |
| Node.js | 20 LTS | Builds React |
| JDK | 21 | Runs/builds the backend |
| Maven | 3.9+ | Java build tool |
| Docker Desktop (WSL2 backend) | latest | Local containers |
| AWS CLI | v2 | Talks to AWS |
| Terraform | 1.10 or newer | Infrastructure as code (1.10 adds S3 native state locking) |
| kubectl | within one minor version of the cluster (1.36) | Controls Kubernetes |
| Helm | 3.x | Installs packaged apps (monitoring, controllers) |
| jq | any | Reads JSON in scripts |
| VS Code or IntelliJ | any | Editor |

Accounts: an AWS account with **MFA on the root user**, an IAM admin user for daily work, a GitHub account, and (optional) a domain name for HTTPS.

#### I. Execute commands
Install and check the tools (WSL2 Ubuntu terminal). One command at a time:

```bash
git --version
```
```bash
node -v
```
```bash
java -version
```
```bash
mvn -v
```
```bash
docker --version
```
```bash
docker compose version
```
```bash
aws --version
```
```bash
terraform version
```
```bash
kubectl version --client
```
```bash
helm version --short
```
If a tool is missing, ask Claude for exact install steps for your OS. (Phase 9 contains Linux install commands for most of them in `scripts/install-jenkins-tools.sh`; you can reuse those lines on WSL2 Ubuntu.)

#### J. Expected output
Each command prints a version number. Java must start with 21, Node with v20 (or newer LTS), Terraform 1.10 or higher. The exact numbers on your machine will differ.

#### K. Verification
You can answer these out loud:
1. Why is the database in a private subnet?
2. What is the difference between a public and a private subnet, and what does a NAT gateway do?
3. Describe the path from `git push` to a pod running in EKS.
4. Why are there two pipelines?
5. Which AWS resources bill while idle? (EKS control plane, NAT gateway, ALB, RDS, EC2/EBS, Elastic IPs.)

#### L. Troubleshooting
| Problem | Fix |
|---|---|
| `docker: command not found` in WSL | Docker Desktop > Settings > Resources > WSL integration > enable your Ubuntu distro |
| `java -version` shows 17 or 11 | Install `openjdk-21-jdk` and set `JAVA_HOME` |
| Windows line endings break scripts (`\r: command not found`) | `git config --global core.autocrlf input`, then re-clone/unzip inside WSL |

#### M. Completion checklist
- [ ] I understand the three tiers and why the DB is private.
- [ ] I can explain public vs private subnet and NAT.
- [ ] I can explain the pipeline flow end to end.
- [ ] I know why infrastructure and application pipelines are separate.
- [ ] I know which resources cost money while idle.
- [ ] AWS account with root MFA exists (needed from Phase 7; a Budgets alert is created there).
- [ ] All local tools in section H are installed and verified.
- [ ] I know whether I have a domain name (needed only for HTTPS in Phase 13).

**Design decisions locked in** (change them only deliberately, then update every affected file): Terraform state in S3 with native lockfile (no DynamoDB); EKS Pod Identity for pod-to-AWS permissions; EKS access entries instead of `aws-auth`; two nodes across two AZs; Kubernetes 1.36 (in standard support until Aug 2027; verified at https://endoflife.date/eks on 2026-11-16, re-check before use because older versions cost 6x more per cluster-hour).


---

## PHASE 2: React Frontend

Cost: **free**. Needs Node.js 20.

---

#### A. What are we doing?
Running, testing and understanding the React single-page application: 12 customer pages and 6 admin pages (login, dashboard, restaurants, foods, orders, customers), routing, login handling, a cart, forms with validation, loading and error states.

#### B. Why are we doing it?
This is Tier 1 (presentation). Every user action becomes an HTTP call to the backend. Understanding how the browser stores the login token, protects routes and reports errors is a common interview topic.

#### C. How does it work?
* **Vite** compiles the JSX into plain JavaScript/CSS (`npm run build` produces `dist/`). In development `npm run dev` serves it on port 5173 with hot reload and **forwards `/api/*` to `http://localhost:8080`** (see `vite.config.js`), so there are no CORS problems.
* **React Router** maps URLs to pages (`src/App.jsx`). `ProtectedRoute` guards groups of pages by role.
* **Axios** is configured once in `src/services/api.js`: it adds `Authorization: Bearer <token>` to every request and, if the server answers 401, clears the login and sends the user to login.
* **Context providers** hold shared state: `AuthContext` (who is logged in), `CartContext` (mirror of the server-side cart), `ToastContext` (popup messages).
* **The cart lives on the server**, so it follows the user between devices; the frontend only mirrors it.
* **The frontend never sends prices.** Checkout sends only address, notes and payment method; the backend reads the cart and computes totals.
* In production the same build is served by Nginx and the browser calls `/api` on the same host, so `VITE_API_URL=/api` is used everywhere.

#### D. Where should I execute it?
**Windows local machine** (WSL2 Ubuntu terminal recommended).

#### E. Which directory should I be in?
```bash
cd foodhub-devsecops/frontend
```

#### F. Which file should I create?
None: all files exist. This is the map of what you will read:

| Path | Purpose |
|---|---|
| `package.json` | Dependencies (react, react-router-dom, axios) and scripts |
| `vite.config.js`, `index.html` | Build tool config and the single HTML page |
| `src/main.jsx` | Starts React and wraps the app in the providers |
| `src/App.jsx` | The route table |
| `src/services/*.js` | One file per API area: auth, catalog, cart, orders, admin |
| `src/context/*.jsx` | Auth, cart, toast state |
| `src/components/*.jsx` | Navbar, cards, guards, form field, loader, error box, status badge |
| `src/layouts/*.jsx` | `CustomerLayout` (navbar + footer) and `AdminLayout` (sidebar) |
| `src/pages/*.jsx` | Customer pages: Home, Login, Register, Restaurants, RestaurantDetails, FoodMenu, Cart, Checkout, OrderConfirmation, MyOrders, OrderTracking, Profile |
| `src/pages/admin/*.jsx` | AdminLogin, AdminDashboard, ManageRestaurants, ManageFoods, ManageOrders, ManageCustomers |
| `src/utils/validators.js` | Form validation helpers (with unit tests) |
| `src/styles/main.css` | Responsive styling (mobile menu under 720px, admin sidebar collapses under 860px) |

#### G. Complete code
Every file is complete in the zip at the paths above. Do not retype them; open them in VS Code.

#### H. Explain the code
Read these four files first; they explain the whole app.

**`src/services/api.js`**
* `axios.create({ baseURL: import.meta.env.VITE_API_URL || '/api', timeout: 15000 })`: every call goes to `/api/...`; after 15 seconds it gives up instead of hanging.
* Request interceptor: reads the token from `localStorage` and adds the `Authorization` header.
* Response interceptor: on 401 with a stored token, removes it and fires a `foodhub:logout` event that `AuthContext` listens to.
* `getErrorMessage(error)`: converts any failure into a readable sentence (server message, field errors, timeout, or "Cannot reach the server").

**`src/context/AuthContext.jsx`**: stores `{token, user}` in `localStorage`, exposes `login`, `register`, `logout`, `isAdmin`. Note for interviews: `localStorage` is simple but readable by any script injected through XSS; the safer alternative is an HttpOnly cookie plus CSRF protection. We keep `localStorage` for clarity, and mitigate XSS by never rendering raw HTML (React escapes text) and by sending security headers from Nginx.

**`src/components/ProtectedRoute.jsx`**: not logged in goes to login; a customer opening `/admin` is sent home; an admin opening customer pages is sent to `/admin`. This only hides screens. **Real security is in the backend**, which re-checks every request.

**`src/pages/Checkout.jsx`**: validates the address, calls `POST /api/orders` with `{deliveryAddress, notes, paymentMethod}`, then (for simulated online payment) `POST /api/payments`, refreshes the cart and navigates to the confirmation page.

Other ideas worth knowing:
* `hooks/useFetch.js` wraps "load data, show spinner, show error with Retry" so each page stays short.
* `OrderTracking` polls every 10 seconds until the order is delivered/cancelled/rejected.
* `ManageOrders` (admin) refreshes every 15 seconds and only shows buttons for the **allowed next statuses** that the backend returns (`nextStatuses`), so the UI cannot offer an illegal transition.

#### I. Execute commands
```bash
npm ci
```
```bash
npm test
```
```bash
npm run build
```
```bash
npm run dev
```
(`npm ci` installs exactly the versions in `package-lock.json`. Use `npm install` only when you add a package.)

#### J. Expected output
Real output captured when the project was generated:

`npm test`:
```
 ✓ src/utils/validators.test.js (4 tests)
 Test Files  1 passed (1)
      Tests  4 passed (4)
```
`npm run build`:
```
✓ 136 modules transformed.
dist/index.html                   0.55 kB
dist/assets/index-<hash>.css      8.60 kB
dist/assets/index-<hash>.js     273.38 kB | gzip: 87.53 kB
✓ built in ~1.5s
```
`npm run dev` prints `Local: http://localhost:5173/`.

#### K. Verification
Open http://localhost:5173 in your browser. **The backend is not running yet**, so you should see:
1. The page layout, navbar and hero search box (UI works).
2. A red banner "Cannot reach the server..." with a **Retry** button on the Home page (this proves error handling works).
3. `/login` and `/register`: submit empty forms and see inline validation messages without any network call.
4. Open `/cart` while logged out: you are redirected to `/login`.
5. Open `/admin`: redirected to `/admin/login`.
6. Resize the window below 720px: the navbar turns into a hamburger menu.

The full flow is verified in Phase 4/5 once the backend exists.

#### L. Troubleshooting
| Error | Cause and fix |
|---|---|
| `npm ERR! code EACCES` | Do not use `sudo npm`. Fix folder ownership or use `nvm`. |
| `Error: Cannot find module` after pulling changes | Run `npm ci` again. |
| Port 5173 in use | Stop the other dev server or run `npm run dev -- --port 5174`. |
| Blank page | Open the browser console (F12). A red error names the file and line. |
| `ECONNREFUSED 127.0.0.1:8080` in the terminal | Expected until the backend runs (Phase 3/4). |

#### M. Completion checklist
- [ ] `npm test` passes (4 tests).
- [ ] `npm run build` succeeds.
- [ ] `npm run dev` shows the UI and the "Cannot reach the server" banner with Retry.
- [ ] I can explain what the Axios interceptors do and why prices are never sent by the frontend.
- [ ] I know why `ProtectedRoute` is a convenience and the backend is the real gate.


---

## PHASE 3: Spring Boot Backend

Cost: **free**. Needs JDK 21 and Maven 3.9+.

> **Read this first.** The backend was written without being able to compile it (the workspace had no access to Maven Central).
> Step I-1 below is therefore the real first test. If it prints a compile error, copy the whole error text to Claude: it is normally a one-line fix.

---

#### A. What are we doing?
Building and testing the Java 21 / Spring Boot 3.5 REST API: authentication, restaurants, foods, cart, orders, payments, admin operations, dashboard.

#### B. Why are we doing it?
This is Tier 2: all business rules live here (who may do what, order totals, order status rules). The frontend can be bypassed by anyone with `curl`, so **every rule must be enforced on the server**.

#### C. How does it work?
Request flow inside the backend:

```
HTTP request
  -> JwtAuthenticationFilter  (reads "Authorization: Bearer <jwt>", verifies the signature, loads the user)
  -> Spring Security rules    (SecurityConfig: public / authenticated / ROLE_ADMIN)
  -> Controller               (validates JSON with @Valid, no business logic)
  -> Service (@Transactional) (business rules, ownership checks)
  -> Repository (Spring Data JPA) -> MySQL
  -> Mapper -> DTO (JSON back to the client; entities and password hashes never leave the service layer)
  Any exception -> GlobalExceptionHandler -> consistent JSON error body
```

Package structure (`com.foodhub`): `config`, `controller`, `service`, `repository`, `entity`, `dto`, `security`, `exception`, `mapper`, `validation`.

**Key design rules implemented**
| Rule | Where |
|---|---|
| Passwords hashed with BCrypt, never stored in plain text | `SecurityConfig.passwordEncoder`, `AuthService` |
| Public registration only creates `ROLE_CUSTOMER` | `AuthService.register` |
| Same error for unknown email and wrong password (no user enumeration) | `GlobalExceptionHandler.auth` |
| Server-side prices: totals computed from DB prices with `BigDecimal` | `OrderService.place`, `OrderPricing` |
| Order placement is one transaction (all or nothing) | `@Transactional` on `OrderService.place` |
| Customers see only their own orders (others get 404, not 403, so ids are not revealed) | `OrderService.assertCanView` |
| Admins manage only restaurants they own | `RestaurantService.findOwned`, `OrderService.updateStatus` |
| Order status lifecycle enforced (PLACED to CONFIRMED to PREPARING to READY to DELIVERED, plus CANCELLED/REJECTED) | `OrderStatus.canMoveTo` |
| Snapshot of name/price in `order_items` | `OrderService.place` |
| Simulated payments; no card fields exist at all | `PaymentRequest` has only `orderId` and `simulateFailure` |
| Actuator on a separate port 8081 (never routed by the Ingress) | `application.yml` |
| Secrets only from environment variables | `application.yml` (`DB_PASSWORD`, `JWT_SECRET`) |

**REST API** (all under `/api`)

| Method and path | Who | Purpose |
|---|---|---|
| POST `/auth/register`, `/auth/login` | public | Create account, get JWT |
| GET/PUT `/users/me` | logged in | Profile |
| GET `/restaurants`, `/restaurants/{id}`, `/restaurants/{id}/foods` | public | Browse |
| GET `/foods?q=&categoryId=`, `/categories` | public | Search food |
| GET/POST/PUT/DELETE `/cart`, `/cart/items`, `/cart/items/{foodId}` | customer | Cart |
| POST `/orders`, GET `/orders/my-orders`, GET `/orders/{id}`, POST `/orders/{id}/cancel` | customer | Orders |
| POST `/payments`, GET `/payments/{orderId}` | customer | Simulated payment |
| `/admin/restaurants`, `/admin/foods`, `/admin/categories` (CRUD) | admin | Manage catalogue |
| GET `/admin/orders`, PATCH `/admin/orders/{id}/status` | admin | Process orders |
| GET `/admin/dashboard`, `/admin/customers` | admin | Statistics, customers |

Swagger UI: `http://localhost:8080/swagger-ui.html`.

#### D. Where should I execute it?
**Windows local machine** (WSL2 or PowerShell). MySQL is needed for the *running* app (Phase 4); the unit tests do **not** need a database.

#### E. Which directory should I be in?
```bash
cd foodhub-devsecops/backend
```

#### F. Which file should I create?
None; the project exists. Files to read, in this order:

1. `pom.xml` (dependencies)
2. `src/main/resources/application.yml` (configuration, all secrets from env vars)
3. `entity/*.java`, `repository/*.java` (data)
4. `security/*.java`, `config/SecurityConfig.java` (login and permissions)
5. `service/*.java` (business logic)
6. `controller/*.java` (HTTP)
7. `src/test/java/...` (tests)

#### G. Complete code
All 86 files are complete in the zip under `backend/`.

#### H. Explain the code
**`pom.xml`**: `spring-boot-starter-parent` pins compatible versions of everything. Starters: `web` (REST), `data-jpa` (database), `security`, `validation`, `actuator` (health/metrics), `micrometer-registry-prometheus` (metrics format Prometheus reads). `flyway-core` + `flyway-mysql` run SQL migrations. `jjwt-*` creates/validates tokens. `springdoc` gives Swagger. `lombok` removes getter/setter boilerplate. `jacoco` produces the coverage report SonarQube reads.

**`application.yml`** (important lines):
* `spring.datasource.url: ${DB_URL}`: the value comes from the environment. If it is missing, the app refuses to start (good: no silent default password).
* `spring.jpa.hibernate.ddl-auto: ${JPA_DDL_AUTO:none}`: Hibernate must **not** create tables; Flyway owns the schema. `validate` makes Hibernate compare entities with the tables (enable it in Phase 4 once things work).
* `spring.jpa.open-in-view: false`: database sessions close at the end of the service method, which prevents accidental lazy queries in controllers.
* `management.server.port: 8081` and `management.endpoint.health.probes.enabled: true`: Kubernetes calls `/actuator/health/liveness` and `/readiness` here.
* `app.jwt.secret: ${JWT_SECRET}`: must be 32+ characters (`JwtService` refuses shorter).

**`SecurityConfig`**: `csrf` disabled because we use a bearer token in a header, not cookies; `SessionCreationPolicy.STATELESS` means no server session; the `authorizeHttpRequests` block is the permission table (public GETs, `/api/admin/**` needs `ROLE_ADMIN`, everything else needs login); the custom entry point and access-denied handler return JSON.

**`OrderService.place`** (the most important method):
1. Load the user's cart; refuse if empty.
2. For every cart line check the food is still available, take the **database** price, multiply by quantity, and create an `OrderItem` snapshot.
3. `OrderPricing.calculate` adds delivery fee (free above Rs 500) and 5% tax with `BigDecimal` and `RoundingMode.HALF_UP`.
4. Save the order, create a `PENDING` payment, empty the cart. All inside one transaction.

**Tests** (JUnit 5 + Mockito, no database): `OrderPricingTest`, `OrderStatusTest`, `StrongPasswordValidatorTest`, `JwtServiceTest`, `AuthServiceTest`, `OrderServiceTest` (placing an order with DB prices, empty cart, unavailable item, ownership, status transitions, admin of another restaurant denied, cash payment marked successful on delivery).

#### I. Execute commands
**1. Compile and run the unit tests (this is the first real compile of the backend):**
```bash
mvn -B test
```
**2. Build the jar:**
```bash
mvn -B clean package
```
(Running the application needs MySQL and environment variables; that is Phase 4.)

#### J. Expected output
Maven prints many download lines the first time (a few minutes). A successful test run ends with lines of this shape (your counts and times will differ):
```
[INFO] Tests run: <n>, Failures: 0, Errors: 0, Skipped: 0
[INFO] BUILD SUCCESS
```
There are 6 test classes; all must pass. `target/foodhub-backend.jar` exists after `package`, and `target/site/jacoco/jacoco.xml` after `test`.

#### K. Verification
```bash
ls target/foodhub-backend.jar
```
```bash
ls target/surefire-reports
```
No `*.txt` report may contain `FAILURE`.

#### L. Troubleshooting
| Error | Cause and fix |
|---|---|
| `release version 21 not supported` | Maven uses an older JDK. `java -version` and `mvn -v` must both say 21. Set `JAVA_HOME`. |
| `Could not resolve dependencies ... springdoc/jjwt version` | A version in `pom.xml` is wrong or too new/old. Open https://central.sonatype.com, find the latest 3.5.x of `spring-boot-starter-parent` or the library, update the number in `pom.xml`, rerun. |
| `cannot find symbol ... getId()/builder()` | Lombok not processed. Use JDK 21 with Maven (not an IDE-only build); in IntelliJ enable Annotation Processing. |
| A compile error in a file | Copy the full error to Claude. The code could not be compiled when it was generated. |
| `Mockito ... UnnecessaryStubbingException` | A test stubs something the code no longer calls: remove that `when(...)` line. |
| SSL/proxy errors downloading dependencies | Corporate proxy: configure `~/.m2/settings.xml`. |

#### M. Completion checklist
- [ ] `mvn -B test` passes with 0 failures.
- [ ] `mvn -B clean package` creates `target/foodhub-backend.jar`.
- [ ] I can explain the request flow (filter, security rules, controller, service, repository).
- [ ] I can explain why totals are computed on the server and why money uses `BigDecimal`.
- [ ] I know why customers get 404 (not 403) for other people's orders.


---

## PHASE 4: MySQL Integration

Cost: **free** (MySQL runs in Docker on your computer).

---

#### A. What are we doing?
Starting a local MySQL 8, letting the backend create the schema with **Flyway migrations**, running the backend against it, and testing CRUD plus the complete order flow with real data.

#### B. Why are we doing it?
Tier 3 is where data lives. We prove the whole stack (backend to database) works locally before spending a rupee on AWS. Everything that fails here would also fail on RDS, only more expensively.

#### C. How does it work?
* `docker compose up -d mysql` starts a MySQL container. The database `foodhub` and user are created from the environment variables in `.env`. Data is kept in the Docker **volume** `mysql_data`.
* On startup the backend connects with `DB_URL`, `DB_USERNAME`, `DB_PASSWORD`. **Flyway** looks at the table `flyway_schema_history`, and runs every `V<number>__name.sql` that has not run yet, in order:
  * `V1__create_schema.sql` creates 11 tables with primary keys, foreign keys, indexes, CHECK constraints, DECIMAL money columns.
  * `V2__seed_roles.sql` inserts `ROLE_CUSTOMER` and `ROLE_ADMIN`.
  * `V3__seed_sample_data.sql` inserts 3 restaurants, 6 categories and 13 dishes.
* Flyway stores a **checksum** of each applied file. If you edit an applied migration, startup fails. That is intentional: history must not be rewritten. To change the schema, add `V4__...sql`.
* `DataInitializer` creates the demo admin and customer **only if** you provide `SEED_*_PASSWORD` values, and gives the sample restaurants to the admin (restaurants are owned by an admin; admins manage only their own).

Table overview: see `database/ER-DIAGRAM.md` (diagram and design reasons).

#### D. Where should I execute it?
**Windows local machine** (WSL2 Ubuntu recommended). Docker Desktop must be running.

#### E. Which directory should I be in?
```bash
cd foodhub-devsecops
```
(the repository root, where `docker-compose.yml` is). Maven commands later use `cd backend`.

#### F. Which file should I create?
One file: **`.env`** in the repository root (never committed). Create it from the template:
```bash
cp .env.example .env
```

#### G. Complete code
`.env` content (edit the three passwords; the values below are examples only):
```
DB_USERNAME=foodhub
DB_PASSWORD=choose-a-db-password
MYSQL_ROOT_PASSWORD=choose-a-root-password
JWT_SECRET=<output of: openssl rand -base64 48>
SEED_ADMIN_PASSWORD=Admin12345
SEED_CUSTOMER_PASSWORD=Customer12345
```
Generate the JWT secret:
```bash
openssl rand -base64 48
```
The database files already exist: `backend/src/main/resources/db/migration/V1..V3`.

#### H. Explain the code
* `MYSQL_DATABASE`, `MYSQL_USER`, `MYSQL_PASSWORD`: the official MySQL image creates them on the first start only. If you change them later you must delete the volume (`docker compose down -v`).
* `ports: "127.0.0.1:3307:3306"`: host port 3307 forwards to the container's 3306, **bound to localhost only** so nobody on your Wi-Fi can reach the database. (3307 avoids a clash with a MySQL you may already have on 3306.)
* `healthcheck` with `mysqladmin ping`: Compose marks the container healthy only when MySQL answers, and the backend service waits for that (`depends_on: condition: service_healthy`).
* `docker/mysql/my.cnf`: forces `utf8mb4` and UTC.
* JDBC URL options: `sslMode=DISABLED` (local only, no TLS inside Docker); the cluster URL uses `sslMode=REQUIRED` for RDS.

#### I. Execute commands
One at a time.

**1. Start only the database**
```bash
docker compose up -d mysql
```
**2. Wait until it is healthy**
```bash
docker compose ps
```
**3. Load your `.env` values into this terminal** (`set -a` exports everything the file defines)
```bash
set -a; . ./.env; set +a
```
**4. Tell the backend where the database is** (3307 is the host port)
```bash
export DB_URL='jdbc:mysql://localhost:3307/foodhub?sslMode=DISABLED&allowPublicKeyRetrieval=true&serverTimezone=UTC'
```
**5. Run the backend**
```bash
cd backend
```
```bash
mvn -B spring-boot:run
```
**6. In a second terminal, look at the database**
```bash
docker exec -it foodhub-mysql mysql -ufoodhub -p foodhub
```
(type your `DB_PASSWORD`), then inside MySQL:
```sql
SHOW TABLES;
SELECT version, description, success FROM flyway_schema_history;
SELECT id, name, price FROM food_items LIMIT 5;
SELECT email, enabled FROM users;
SELECT name, owner_id FROM restaurants;
```
**7. Run the automated API test** (second terminal, repository root; needs `jq`: `sudo apt install -y jq`)
```bash
bash scripts/smoke-test.sh http://localhost:8080 admin@foodhub.local 'Admin12345'
```
Use the `SEED_ADMIN_PASSWORD` you put in `.env`.

**8. (Optional hardening) make Hibernate verify the schema.** Stop the backend (Ctrl+C) and start it again with:
```bash
JPA_DDL_AUTO=validate mvn -B spring-boot:run
```
If it starts, entities and tables agree. If it prints `Schema-validation: wrong column type`, leave `JPA_DDL_AUTO` unset (the default `none` is fine; this is a known MySQL `TINYINT(1)` versus boolean quirk).

#### J. Expected output
* Backend log contains lines like `Migrating schema ... to version "1 - create schema"`, then `"2 - seed roles"`, `"3 - seed sample data"`, then `Started FoodHubApplication in N seconds` (numbers differ). On later starts Flyway says `Schema ... is up to date`.
* `SHOW TABLES;` lists 12 tables: the 11 application tables plus `flyway_schema_history`.
* `flyway_schema_history` shows three rows with `success = 1`.
* The smoke test prints a `PASS` line per check and ends with `ALL SMOKE TESTS PASSED`, followed by dashboard JSON with counts and `totalOrderValue`.

#### K. Verification (manual, as a user would)
1. Browse http://localhost:8080/swagger-ui.html, run `GET /api/restaurants`: you should get 3 restaurants.
2. Run the frontend: in another terminal `cd frontend && npm ci && npm run dev`, open http://localhost:5173. Register, log in, open a restaurant, add dishes to the cart, check out, and watch the order appear under **My orders**.
3. Log out; open http://localhost:5173/admin/login with `admin@foodhub.local` and your admin password; open **Orders**, click **Accept**, then **Start preparing**, **Mark ready**, **Mark delivered**. Go back to the customer's **My orders > Track order**: the progress bar follows.
4. **Persistence test:** stop the backend (Ctrl+C), start it again. The order is still there.
5. **Constraint test** (proves the database protects itself even without the app):
```sql
INSERT INTO food_items (restaurant_id, name, price) VALUES (1, 'Bad', -5);
```
MySQL must answer `Check constraint 'chk_food_items_price' is violated`.
6. **Server-side price test:** in Swagger place an order, then compare `unitPrice` in the response to the price in `food_items`. There is no way to send a price at all.

#### L. Troubleshooting
| Error | Cause and fix |
|---|---|
| `Communications link failure` | MySQL not ready or wrong port. `docker compose ps` must say `healthy`; URL must use port **3307** when running Maven on the host. |
| `Access denied for user 'foodhub'` | The password in your shell differs from the one MySQL was created with. Run `docker compose down -v`, fix `.env`, `docker compose up -d mysql`. |
| `Public Key Retrieval is not allowed` | Keep `allowPublicKeyRetrieval=true` in the URL (local only). |
| `Could not resolve placeholder 'DB_URL'` | Step 3/4 not done in **this** terminal. Variables do not carry across terminals. |
| `Migration checksum mismatch` | You edited an already-applied migration. Local only: `docker compose down -v` to start fresh. Never do this to a real database; add a new `V4` file instead. |
| `Flyway: Detected failed migration` | Fix the SQL, `docker compose down -v`, start again. |
| `\r: command not found` / odd values in `.env` | `.env` has Windows line endings: `sed -i 's/\r$//' .env`. |
| `JWT_SECRET must be at least 32 characters` | Make the secret longer. |
| Port 8080 already in use | Stop the other process or `export SERVER_PORT=8090`. |

#### M. Completion checklist
- [ ] MySQL container is `healthy`.
- [ ] Flyway ran V1, V2, V3 successfully (`flyway_schema_history`).
- [ ] `scripts/smoke-test.sh` ends with `ALL SMOKE TESTS PASSED`.
- [ ] I placed an order through the UI and the admin moved it to DELIVERED.
- [ ] The order survived a backend restart.
- [ ] I can explain Flyway checksums and why prices are never accepted from the client.


---

## PHASE 5: Local Docker Deployment

Cost: **free**.

---

#### A. What are we doing?
Packaging the frontend and backend as Docker images and running the whole system (frontend + backend + MySQL) with one command, exactly the way it will later run on Kubernetes.

#### B. Why are we doing it?
"It works on my machine" is the problem containers solve. The same image that passes tests locally is the image that Jenkins pushes to ECR and EKS runs.

#### C. How does it work? (vocabulary first)
| Term | Meaning |
|---|---|
| **Image** | A read-only template: your app plus everything it needs. Built from a `Dockerfile`. |
| **Container** | A running instance of an image. |
| **Network** | A private virtual network. Containers on `foodhub-net` reach each other **by service name** (`mysql`, `backend`). |
| **Volume** | Storage outside the container so data survives container deletion (`mysql_data`). |
| **Port mapping** `3000:8080` | host port 3000 forwards to container port 8080. |
| **Environment variable** | Configuration passed at start, such as `DB_PASSWORD`. |
| **Multi-stage build** | Stage 1 has heavy build tools; the final image copies only the result, so it is small and has fewer vulnerabilities. |

Flow when you open http://localhost:3000:
```
Browser -> frontend container (Nginx, port 8080) -> /api/... proxied to -> backend container (8080) -> mysql container (3306)
```

#### D. Where should I execute it?
**Windows local machine**, WSL2 terminal, Docker Desktop running.

#### E. Which directory should I be in?
```bash
cd foodhub-devsecops
```

#### F. Which file should I create?
Only `.env` (done in Phase 4). Files used:

| File | Purpose |
|---|---|
| `backend/Dockerfile` | Maven build stage, then a small JRE runtime image |
| `frontend/Dockerfile` | Node build stage, then unprivileged Nginx |
| `frontend/nginx.conf.template` | Nginx config; `${BACKEND_URL}` is filled in at start |
| `docker-compose.yml` | Defines the three services, network and volume |
| `docker/mysql/my.cnf` | MySQL character set and timezone |

#### G. Complete code
All files are complete in the zip at the paths above.

#### H. Explain the code
**`backend/Dockerfile`**
* `FROM maven:3.9-eclipse-temurin-21 AS build`: image with Maven and JDK 21, named `build`.
* `COPY pom.xml .` then `RUN mvn dependency:go-offline`: dependencies are downloaded **before** copying the source, so Docker caches that slow layer until `pom.xml` changes.
* `RUN mvn clean package -DskipTests`: tests already ran in Jenkins/your terminal.
* `FROM eclipse-temurin:21-jre-alpine`: tiny runtime (JRE only).
* `addgroup ... -g 10001` / `adduser -u 10001` / `USER 10001`: the app runs as a **non-root user with a fixed id**, so Kubernetes can enforce `runAsNonRoot`.
* `EXPOSE 8080 8081`: documentation of ports (API and actuator).
* `ENTRYPOINT ["sh","-c","exec java $JAVA_OPTS -jar /app/app.jar"]`: `exec` makes Java process 1 so it receives shutdown signals; `JAVA_OPTS` with `MaxRAMPercentage=75` sizes the heap from the container memory limit.

**`frontend/Dockerfile`**
* `npm ci`: reproducible install. `ENV VITE_API_URL=/api`: the browser calls `/api` on the same host.
* Final stage `nginxinc/nginx-unprivileged`: runs as user 101 on port **8080** (non-root cannot use port 80).
* Files in `/etc/nginx/templates/*.template` are run through `envsubst` at start, which is how `BACKEND_URL` gets in.

**`frontend/nginx.conf.template`**
* `location = /healthz`: used by Docker and Kubernetes health checks.
* `location /api/ { proxy_pass ${BACKEND_URL}; ... }`: forwards API calls to the backend.
* `location /assets/`: hashed filenames, so caching for a year is safe.
* `location / { try_files $uri /index.html; }`: **required for React Router**: refreshing `/orders/5` must return `index.html`, not 404.
* Security headers: `X-Content-Type-Options`, `X-Frame-Options`, `Referrer-Policy`; `server_tokens off` hides the Nginx version.

**`docker-compose.yml`**
* `${DB_PASSWORD:?Set DB_PASSWORD in .env}`: Compose stops with a clear message if a required value is missing.
* `depends_on: condition: service_healthy`: correct start order mysql, backend, frontend.
* Backend `ports: 127.0.0.1:8080/8081`: exposed only to your own computer.
* `mysql_data` volume: persistence.
* `restart: unless-stopped`: containers come back after a reboot.

#### I. Execute commands
**1. Check the file is valid**
```bash
docker compose config -q
```
**2. Build both images**
```bash
docker compose build
```
**3. Start everything in the background**
```bash
docker compose up -d
```
**4. Watch the state until all three are healthy**
```bash
docker compose ps
```
**5. Read the backend log**
```bash
docker compose logs -f backend
```
(Ctrl+C stops following; the container keeps running.)

**6. Test through the front door** (frontend proxy to backend to database)
```bash
curl -s http://localhost:3000/api/restaurants | head -c 300
```
**7. Run the full API test through Nginx**
```bash
bash scripts/smoke-test.sh http://localhost:3000 admin@foodhub.local 'Admin12345'
```
**8. Persistence test**
```bash
docker compose down
```
```bash
docker compose up -d
```
Log in again: your earlier users and orders must still exist, because `down` keeps the volume.

**9. See what is running and how big the images are**
```bash
docker images | grep foodhub
```
```bash
docker network ls | grep foodhub
```
```bash
docker volume ls | grep foodhub
```

#### J. Expected output
* `docker compose ps` lists `foodhub-mysql`, `foodhub-backend`, `foodhub-frontend`; the first two show `(healthy)` (the backend takes about a minute).
* The `curl` returns JSON starting with `[{"id":1,"name":"Hyderabad Spice House"...`.
* The smoke test ends with `ALL SMOKE TESTS PASSED`.
* Open http://localhost:3000 : restaurants appear; the customer and admin flows from Phase 4 work.

#### K. Verification
1. Frontend to backend: the Home page shows restaurants (it could only get them through Nginx `/api` to the backend).
2. Backend to database: registering a user and then running
```bash
docker exec -it foodhub-mysql mysql -ufoodhub -p foodhub -e "SELECT email FROM users;"
```
shows the new email.
3. Non-root check:
```bash
docker exec foodhub-backend id
```
```bash
docker exec foodhub-frontend id
```
Neither may say `uid=0(root)`.
4. The actuator is not reachable through the public port 3000:
```bash
curl -s -o /dev/null -w "%{http_code}\n" http://localhost:3000/actuator/health
```
It returns the SPA page (200 from `index.html`) but never health JSON; actuator exists only on 8081 on the backend itself.

#### L. Troubleshooting
| Error | Cause and fix |
|---|---|
| `Set DB_PASSWORD in .env` | `.env` missing or in the wrong folder. It must sit next to `docker-compose.yml`. |
| Backend `unhealthy` / restarting | `docker compose logs backend`. Usually `JWT_SECRET` too short, or a wrong `DB_*` value, or MySQL volume created with a different password: `docker compose down -v` and retry. |
| `port is already allocated` (3000/8080/8081/3307) | Another program uses it. Stop it or change the left side of the mapping in `docker-compose.yml`. |
| `502 Bad Gateway` from Nginx | Backend is not up yet (wait) or crashed (`docker compose logs backend`). |
| Browser shows a blank page after changing code | Rebuild: `docker compose up -d --build`. |
| Build very slow / out of memory | Docker Desktop > Settings > Resources: give at least 4 GB RAM. |
| `npm ci` fails inside the build | `package-lock.json` is missing or out of date: run `npm install` in `frontend/` once and commit the lock file. |
| `exec format error` | Image built for another CPU type (Apple silicon): `docker build --platform linux/amd64 ...` (EKS nodes here are x86_64). |
| Orders 500 error after editing SQL files | See Phase 4 troubleshooting (Flyway checksums). |

Cleanup commands:
```bash
docker compose down        # stop, keep data
docker compose down -v     # stop and DELETE the database volume
```

#### M. Completion checklist
- [ ] `docker compose up -d` shows all three services running, database and backend healthy.
- [ ] http://localhost:3000 works for customer and admin flows.
- [ ] `smoke-test.sh` passes through port 3000.
- [ ] Data survives `docker compose down` / `up`.
- [ ] Containers do not run as root.
- [ ] I can explain image vs container, network, volume, port mapping, and multi-stage builds.
- [ ] **Local testing succeeded, so cloud work may begin** (the master plan forbids going to AWS before this).


---

## PHASE 6: GitHub

Cost: **free**.

---

#### A. What are we doing?
Putting the project under Git version control, publishing it to a GitHub repository with `main` and `develop` branches, protecting secrets, and preparing the webhook (the webhook itself is connected in Phase 12, when Jenkins exists).

#### B. Why are we doing it?
Git is the single source of truth: Jenkins builds from it, Terraform and Kubernetes definitions live in it. A leaked password in Git history is a real incident, so we set up protection **before** the first commit.

#### C. How does it work?
* `git init` creates a hidden `.git` folder that records history.
* `.gitignore` lists files Git must never track: `.env`, `*.tfstate`, personal `terraform.tfvars`, `*.pem`, `node_modules`, `target`.
* **Branches**: `main` = what is deployed to the cluster; `develop` = integration branch where work is tested first. Jenkins builds both, deploys only `main`.
* A **webhook** is GitHub calling a URL on every push so Jenkins starts immediately.

#### D. Where should I execute it?
**Windows local machine** (WSL2) plus the GitHub website in your browser.

#### E. Which directory should I be in?
```bash
cd foodhub-devsecops
```

#### F. Which file should I create?
None. `.gitignore` already exists in the repository root. Create an **empty repository on GitHub** (website): New repository, name `foodhub-devsecops`, **Private**, do **not** add a README/.gitignore/license (the project already has them).

#### G. Complete code
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

#### H. Explain the code
* `*.env` + `!.env.example`: ignore every env file **except** the template that has no real values.
* `*.tfvars` ignored (they contain your IP and ARNs), but `!terraform/environments/*/*.tfvars` re-allows the shared environment presets, which contain only sizes and flags.
* `**/.terraform/`: provider plugins (hundreds of MB). `*.tfstate`: state can contain sensitive values, and the real state lives in S3.

#### I. Execute commands
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

#### J. Expected output
`git push` ends with `Branch 'main' set up to track remote branch 'main' from 'origin'.` The repository page on GitHub shows all the folders. The check in step 5 prints `clean: no secret or build files tracked`.

#### K. Verification
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

#### L. Troubleshooting
| Error | Fix |
|---|---|
| `remote: Support for password authentication was removed` | Use a Personal Access Token (Settings > Developer settings > Tokens) or `gh auth login`. |
| `fatal: not a git repository` | You are in the wrong folder. `cd foodhub-devsecops`. |
| `.env` shows in `git status` | It is not ignored: check the filename is exactly `.env` and `.gitignore` is in the repo root; if already staged, `git rm --cached .env`. |
| `rejected ... non-fast-forward` | The remote has commits you lack: `git pull --rebase origin main`, then push. Never `--force` on `main`. |
| Large file rejected (>100 MB) | A build folder was staged: `git rm -r --cached frontend/node_modules`. |

#### M. Completion checklist
- [ ] Repository exists on GitHub (private) with `main` and `develop`.
- [ ] `.env`, tfstate, keys and node_modules are NOT in the repository.
- [ ] Branch protection on `main` is enabled.
- [ ] I can explain why a secret deleted in a later commit is still leaked.
- [ ] I know the webhook URL format and that it is connected in Phase 12.


---

## PHASE 7: AWS Preparation

Cost: account is free. Phase ends with a **budget alarm**; the S3 state bucket costs a few rupees per month. (INR figures in this guide use roughly ₹88 per US$1; check today's rate. All are estimates; see `docs/COST.md`.)

---

#### A. What are we doing?
Preparing your AWS account safely: MFA on the root user, a non-root admin identity, AWS CLI configured, a budget alarm, and the S3 bucket that will hold Terraform state.

#### B. Why are we doing it?
Mistakes at this stage are the expensive ones: a leaked root key or an unnoticed running cluster can cost thousands of rupees. Security and cost guardrails come **before** any infrastructure.

#### C. How does it work?
* **Root user**: the email you signed up with, can do everything and cannot be restricted. Use it only to create the admin identity, then lock it away with MFA.
* **IAM user / role**: a restricted identity for daily work. Production teams use IAM Identity Center (SSO); a single learner can use one IAM user with MFA.
* **AWS CLI profile**: stores access keys locally in `~/.aws/credentials` (outside the repository).
* **Budget**: emails you when forecast or actual spend crosses limits.
* **Terraform state**: a file recording what Terraform built. It must be shared, versioned and locked, so we store it in S3 (versioned, encrypted, public access blocked). The Terraform in `terraform/bootstrap/` creates that bucket, with local state because it is the chicken before the egg.

#### D. Where should I execute it?
AWS Console (browser) for steps 1-3, then **Windows local machine (WSL2)** for the rest.

#### E. Which directory should I be in?
```bash
cd foodhub-devsecops/terraform/bootstrap
```
(for the Terraform part only)

#### F. Which file should I create?
`terraform/bootstrap/terraform.tfvars` (never committed; ignored by `.gitignore`):
```bash
cp terraform.tfvars.example terraform.tfvars
```

#### G. Complete code
`terraform/bootstrap/main.tf` is complete in the zip. `terraform.tfvars`:
```hcl
budget_email = "your-real-email@example.com"
# monthly_budget_usd = 100   # optional: alarm threshold in US dollars (default is set in the file)
```

#### H. Explain the code
`bootstrap/main.tf` creates:
* `aws_s3_bucket` named `foodhub-tfstate-<account id>-ap-south-1`, with `prevent_destroy = true` (you cannot lose it by accident).
* **Versioning**: every state revision is kept, so a bad apply can be recovered.
* **Encryption** (AES-256) and **public access block**: state may contain sensitive attributes.
* A bucket policy denying non-TLS access.
* `aws_budgets_budget`: monthly limit with alerts at 50%, 80% and 100% actual and 100% forecast, emailed to you.

#### I. Execute commands
**1. Secure the root user (browser).** Console > top-right account menu > Security credentials > Assign MFA device (authenticator app). Do not create root access keys.

**2. Create your admin user (browser).** IAM > Users > Create user `foodhub-admin`; attach the AWS managed policy `AdministratorAccess` (learning account; in a company you would scope this down); enable console access and **MFA** for it.

**3. Create an access key for the CLI (browser).** IAM > Users > foodhub-admin > Security credentials > Create access key > "Command Line Interface". Download or copy it once. Treat it like a password.

**4. Install the AWS CLI v2 (WSL2).**
```bash
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o awscliv2.zip
```
```bash
unzip awscliv2.zip && sudo ./aws/install
```
```bash
aws --version
```
**5. Configure the profile.** Enter the key, the secret, region `ap-south-1`, output `json`.
```bash
aws configure --profile foodhub
```
```bash
export AWS_PROFILE=foodhub
```
**6. Prove who you are.**
```bash
aws sts get-caller-identity
```
**7. Install Terraform** (version 1.10 or newer; follow https://developer.hashicorp.com/terraform/install for Ubuntu), then:
```bash
terraform version
```
**8. Create the state bucket and budget.**
```bash
cd terraform/bootstrap
```
```bash
terraform init
```
```bash
terraform plan
```
Read the plan: it must show only the S3 bucket pieces and the budget. Then:
```bash
terraform apply
```
(type `yes`). Note the printed bucket name.

**9. Find your public IP** (needed for Phase 8):
```bash
curl -s https://checkip.amazonaws.com
```
**10. Confirm the budget email** (AWS sends a confirmation mail for SNS/Budget notifications in some setups; click it if received).

#### J. Expected output
* Step 6 prints JSON with `Account`, `UserId` and an `Arn` ending `user/foodhub-admin` (values are yours).
* Step 8 ends with `Apply complete! Resources: N added` and outputs the bucket name `foodhub-tfstate-<12-digit-account-id>-ap-south-1`.

#### K. Verification
```bash
aws s3 ls | grep foodhub-tfstate
```
```bash
aws s3api get-bucket-versioning --bucket <bucket-name>
```
must show `"Status": "Enabled"`.
Console > Billing > Budgets lists your budget. Console > IAM shows MFA enabled for root and for the admin user. Also enable **Billing > Billing preferences > receive alerts**.

#### L. Troubleshooting
| Error | Fix |
|---|---|
| `InvalidClientTokenId` / `SignatureDoesNotMatch` | Wrong or inactive key; re-run `aws configure --profile foodhub`; check no stray spaces. |
| `Unable to locate credentials` | `export AWS_PROFILE=foodhub` in this terminal (variables are per terminal). |
| `BucketAlreadyExists` | Names are global; change `bucket_name` in `main.tf` locals only if the name is taken (it includes your account id, so this is rare). |
| `Error: Unsupported Terraform Core version` | Upgrade Terraform to 1.10+. |
| Budget API access denied | Billing access for IAM users must be activated by the root user: Account > IAM user and role access to Billing information. |
| Terraform asks for `budget_email` | You did not create `terraform.tfvars` in this folder. |

#### M. Completion checklist
- [ ] Root has MFA and no access keys.
- [ ] `foodhub-admin` has MFA; CLI profile works (`sts get-caller-identity`).
- [ ] State bucket exists with versioning enabled.
- [ ] A monthly budget with email alerts exists.
- [ ] I know my public IP and that bootstrap state file (`terraform.tfstate` in `bootstrap/`) is local and ignored by Git. **Keep a copy**; it is how Terraform remembers the bucket.


---

## PHASE 8: Terraform Infrastructure

**Cost warning.** This is the first phase that spends real money. Rough INR estimates for the **dev** profile running 24x7 in ap-south-1 (US$ at about ₹88; verify with the AWS Pricing Calculator):

| Item | About per month |
|---|---|
| EKS control plane | ₹6,400 (US$0.10/h) |
| 2 x t3.medium nodes | ₹6,000 |
| NAT gateway (single) + data | ₹3,000+ |
| RDS db.t3.micro + 20 GB | ₹1,500 |
| Jenkins + SonarQube EC2, EBS, Elastic IPs | ₹4,000-6,000 |
| ALB (created in Phase 13) | ₹1,800 |
| KMS, Secrets Manager, CloudWatch logs, ECR | ₹500-1,000 |
| **Total, left running** | **roughly ₹23,000-28,000 (about ₹800-950 per day)** |

**Rule: `terraform destroy` when you stop for the day** (Phase 16 gives the safe order). Created and destroyed within a few hours, a practice run costs about ₹100-300.

---

#### A. What are we doing?
Describing the entire AWS infrastructure as code and creating it with Terraform: VPC, subnets, NAT, security groups, IAM, ECR, EKS, RDS, Secrets Manager, and the Jenkins and SonarQube servers.

#### B. Why are we doing it?
Clicking in the console is not repeatable, reviewable or destroyable. Code is: it goes through Git review, it can be recreated in minutes, and `destroy` removes everything so billing stops.

#### C. How does it work?
Terraform reads `.tf` files, compares them with the **state** in S3, prints a **plan** (what it will add, change or destroy), and on `apply` calls AWS APIs.

```
modules/vpc       -> VPC, 3 tiers of subnets (public / private app / private db), IGW, NAT, route tables
modules/security  -> security groups: ALB, nodes, RDS (3306 only from nodes), Jenkins, SonarQube
modules/iam       -> Jenkins role (least privilege), separate "terraform-deployer" role, EKS roles
modules/ecr       -> 2 repositories (backend, frontend), immutable tags, scan on push, lifecycle policy
modules/eks       -> cluster, managed node group, access entries, Pod Identity roles, add-ons, KMS
modules/rds       -> MySQL 8 in DB subnets, encrypted, AWS-managed master password in Secrets Manager
modules/secrets   -> JWT secret, DB connection secret, External Secrets role
modules/ci_servers-> Jenkins and SonarQube EC2 (IMDSv2, encrypted EBS, Elastic IPs)
```
Tier isolation: only the ALB is public; nodes are private; RDS accepts connections only from the node security group.

#### D. Where should I execute it?
**Windows local machine (WSL2)** with `AWS_PROFILE=foodhub` set.

#### E. Which directory should I be in?
```bash
cd foodhub-devsecops/terraform
```

#### F. Which file should I create?
1. Fix the bucket name in `environments/dev/backend.hcl` (replace `REPLACE_ACCOUNT_ID` or paste the exact name printed in Phase 7).
2. Create `terraform.tfvars` (your personal values; ignored by Git):
```bash
cp terraform.tfvars.example terraform.tfvars
```

#### G. Complete code
All Terraform files are in the zip. Your `terraform.tfvars`:
```hcl
state_bucket_name    = "foodhub-tfstate-<your-account-id>-ap-south-1"
admin_cidrs          = ["<YOUR_PUBLIC_IP>/32"]
admin_principal_arns = ["arn:aws:iam::<your-account-id>:user/foodhub-admin"]
# github_webhook_cidrs = []   # leave empty to rely on polling; see Phase 12
```
Environment sizes live in `environments/dev/dev.tfvars` (t3.medium x2, db.t3.micro, single NAT, deletion protection off).

#### H. Explain the code
* `backend.tf`: `backend "s3" {}` is intentionally empty; values come from `backend.hcl` so one code base serves dev and prod.
* `variables.tf`: validations such as "admin_cidrs must not contain 0.0.0.0/0" protect you from exposing Jenkins and SonarQube to the world.
* `modules/vpc`: three subnet tiers across `az_count` zones. `single_nat_gateway = true` saves about ₹3,000/month in dev; prod uses one NAT per AZ for resilience.
* `modules/eks`: **access entries** (modern replacement for the `aws-auth` ConfigMap) give your user and the Jenkins role cluster access; **Pod Identity** gives the Load Balancer Controller and External Secrets only the AWS permissions they need; **KMS** encrypts Kubernetes Secrets; the VPC CNI is configured with `enableNetworkPolicy` so the NetworkPolicies in `kubernetes/` are really enforced.
* `modules/rds`: `manage_master_user_password = true`: **you never see or write the DB password**. AWS stores it in Secrets Manager.
* `modules/iam`: Jenkins cannot create arbitrary resources. It can push to ECR, describe/get a token for EKS, and `sts:AssumeRole` into the separate `terraform-deployer` role used only by the infrastructure pipeline.
* `create_ci_servers = true`: set to `false` if you want to build only the cluster first.

#### I. Execute commands
**1. Format and initialise**
```bash
terraform fmt -recursive
```
```bash
terraform init -backend-config=environments/dev/backend.hcl
```
**2. Validate the syntax and references**
```bash
terraform validate
```
> Honest note: this code was written without being able to run `terraform validate` in the authoring environment. If it reports an error, read the message (it names the file and line), fix that one thing, and re-run. This is normal and is part of the learning. `docs/TROUBLESHOOTING.md` lists the likely ones.

**3. Preview. Read it.**
```bash
terraform plan -var-file=environments/dev/dev.tfvars -out=dev.plan
```
Look for the summary `Plan: N to add, 0 to change, 0 to destroy.` On a first run the destroy count must be 0.

**4. Create (takes about 15-25 minutes, EKS and RDS are the slow ones)**
```bash
terraform apply dev.plan
```
**5. Read the outputs**
```bash
terraform output
```
**6. Connect kubectl** (command also printed by `terraform output kubeconfig_command`)
```bash
aws eks update-kubeconfig --region ap-south-1 --name foodhub-dev-eks
```
```bash
kubectl get nodes
```
**7. Inspect what exists**
```bash
aws ecr describe-repositories --query 'repositories[].repositoryName'
```
```bash
aws rds describe-db-instances --query 'DBInstances[].[DBInstanceIdentifier,DBInstanceStatus]'
```
**8. Destroy (when you stop; do Phase 16 steps first if you installed the ALB/ingress)**
```bash
terraform destroy -var-file=environments/dev/dev.tfvars
```

#### J. Expected output
* `terraform init`: `Terraform has been successfully initialized!`
* `terraform validate`: `Success! The configuration is valid.`
* `terraform apply`: ends with `Apply complete! Resources: N added, 0 changed, 0 destroyed.` and lists outputs (cluster name, ECR URLs, RDS endpoint, Jenkins and SonarQube addresses). N and the addresses are yours.
* `kubectl get nodes`: two nodes with `STATUS Ready`.

#### K. Verification
1. Console > VPC: your VPC with public, private and database subnets.
2. Console > EKS > cluster is `Active`; Compute shows 2 nodes.
3. Console > RDS: instance `available`, **Publicly accessible: No**.
4. `aws secretsmanager list-secrets --query 'SecretList[].Name'` shows the JWT, DB-connection and RDS master secrets (names only; **never print secret values into screenshots**).
5. ECR: two repositories, tag immutability on.
6. `terraform plan` immediately after apply says `No changes.`: your code and AWS agree.

#### L. Troubleshooting
| Error | Fix |
|---|---|
| `Error acquiring the state lock` | Another run is active, or one crashed. Wait; if sure nothing runs: `terraform force-unlock <ID>`. |
| `Backend configuration changed` | Re-run `terraform init -backend-config=... -reconfigure`. |
| `AccessDenied` | Wrong `AWS_PROFILE` or the user lacks permission. Re-check `aws sts get-caller-identity`. |
| `InvalidParameterCombination ... kubernetes version` | The EKS version is not offered in the region yet: `aws eks describe-cluster-versions` and set `kubernetes_version`. |
| `VcpuLimitExceeded` / quota | New accounts have low limits; request an increase in Service Quotas, or use `t3.small` only if memory allows. |
| `InsufficientFreeAddressesInSubnet` | Do not shrink subnet CIDRs. |
| `Error: Invalid for_each argument ... known only after apply` | Apply in two steps: `terraform apply -target=module.vpc` first, then the full apply. |
| Destroy hangs on subnets/VPC | An ALB or ENI created by Kubernetes still exists: run `scripts/cleanup-aws.sh` (Phase 16), then retry. |
| RDS creation stuck in `creating` | Normal for 5-10 minutes. |

#### M. Completion checklist
- [ ] I read the cost table and understand the daily cost of leaving this running.
- [ ] `terraform validate` succeeds; `plan` was reviewed before `apply`.
- [ ] `kubectl get nodes` shows Ready nodes.
- [ ] RDS is private; secrets exist; ECR repos exist.
- [ ] `terraform plan` afterwards shows no changes.
- [ ] I know the destroy procedure and will use it.


---

## PHASE 9: Jenkins on EC2

Cost: Jenkins EC2 (instance size in `jenkins_instance_type`) is already included in the Phase 8 estimate (about ₹2,000-3,500/month if left on 24x7). **Stop the instance when not in use** (Phase 16).

---

#### A. What are we doing?
Installing Jenkins and every tool the pipeline calls (Java 21, Maven, Node, Docker, Trivy, Terraform, kubectl, Helm, AWS CLI, SonarScanner) on the Jenkins server that Terraform created, then configuring plugins, credentials and the SonarQube connection.

#### B. Why are we doing it?
Jenkins is the automation engine: on every push it builds, tests, scans, packages and deploys. A server (not your laptop) makes releases consistent and auditable.

#### C. How does it work?
* The EC2 instance has an **instance profile** (IAM role), so Jenkins gets AWS permissions **without access keys stored anywhere**. The AWS CLI finds them automatically.
* Jenkins listens on port 8080; the security group allows it only from `admin_cidrs` (your IP).
* The pipeline (`Jenkinsfile`) runs shell steps on the Jenkins machine, so the tools must be installed there. `scripts/install-jenkins-tools.sh` does it.

#### D. Where should I execute it?
Browser (Jenkins UI) and **the Jenkins EC2** over SSH or, preferably, **AWS Systems Manager Session Manager** (the instance profile includes SSM, so no SSH key or open port 22 is required).

#### E. Which directory should I be in?
On your laptop: `foodhub-devsecops/terraform` (to read outputs). On the server: your home directory.

#### F. Which file should I create?
None to author. Copy `scripts/install-jenkins-tools.sh` onto the server (or `git clone` your repository there).

#### G. Complete code
`scripts/install-jenkins-tools.sh` is in the zip. It runs 10 numbered steps and is safe to re-run.

#### H. Explain the code
Steps: base packages; Java 21; Jenkins LTS repo and install; Docker (adds `jenkins` to the `docker` group); Maven; Node.js 20+; AWS CLI v2; Terraform; kubectl (minor version should be within one of the cluster: `K8S_MINOR`); Helm; Trivy (apt repository); SonarScanner CLI; then restarts Jenkins and prints the initial admin password location.
Tool versions can be overridden with environment variables at the top of the script; **check the latest versions** you want to use.

#### I. Execute commands
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

#### J. Expected output
* Step 4 prints `OK` for all ten tools.
* Step 5 prints an `Arn` like `arn:aws:sts::<account>:assumed-role/foodhub-dev-jenkins-role/i-...`.
* Browser shows the Jenkins dashboard; the multibranch job scans and finds the `Jenkinsfile`.

#### K. Verification
1. `sudo systemctl status jenkins` shows `active (running)`.
2. Jenkins > Manage Jenkins > System Information lists `JAVA_HOME` of Java 21.
3. Run `aws ecr describe-repositories --region ap-south-1` on the server: it works (role allows ECR). Run `aws iam list-users`: it must be **denied** (least privilege).
4. Run `kubectl get nodes` after Phase 13 grants the Jenkins role access.

#### L. Troubleshooting
| Problem | Fix |
|---|---|
| Browser cannot reach `:8080` | Your public IP changed: update `admin_cidrs` and re-apply. Or instance stopped. |
| `Jenkins failed to start` | `sudo journalctl -u jenkins -n 100 --no-pager`; usually Java version or RAM. Use at least `t3.medium`. |
| `permission denied ... docker.sock` in a build | `sudo usermod -aG docker jenkins && sudo systemctl restart jenkins`. |
| `Unable to locate credentials` | The instance profile is missing: check the EC2's IAM role in the console. |
| Plugin install fails | Wait and retry; check disk with `df -h`. |
| Trivy first run very slow | It is downloading its vulnerability database; the cache is kept in `TRIVY_CACHE_DIR`. |

#### M. Completion checklist
- [ ] Jenkins reachable only from my IP; admin user created; sign-up disabled.
- [ ] All ten tools verified.
- [ ] `aws sts get-caller-identity` shows the instance role; there are no AWS keys in Jenkins.
- [ ] Required plugins installed.
- [ ] Multibranch job created and scans the repository.


---

## PHASE 10: SonarQube

Cost: SonarQube EC2 is part of the Phase 8 estimate. Stop it when idle.

---

#### A. What are we doing?
Running SonarQube Community Build (with PostgreSQL) on its own server, creating a project token, connecting Jenkins to it, and enforcing a **quality gate** that fails the pipeline if the code is not good enough.

#### B. Why are we doing it?
SonarQube performs static analysis (SAST): bugs, code smells, security hotspots, duplicated code, and test coverage. Catching a SQL-injection pattern in review is far cheaper than in production.

#### C. How does it work?
Jenkins runs `sonar-scanner`, which uploads results to the SonarQube server. The server computes a verdict against the **Quality Gate**. SonarQube then calls a **webhook** back to Jenkins so the stage `waitForQualityGate` knows the verdict and aborts the pipeline on failure.

#### D. Where should I execute it?
The **SonarQube EC2** (Session Manager) for installation; browser for configuration.

#### E. Which directory should I be in?
On the server: wherever you cloned the repository.

#### F. Which file should I create?
None to author. `sonar-project.properties` (repository root) is already in the zip: project key `foodhub`, sources `backend/src/main/java` and `frontend/src`, JaCoCo report path.

#### G. Complete code
`scripts/install-sonarqube.sh` (runs SonarQube and PostgreSQL in Docker Compose, creates the random DB password in `/opt/sonarqube/.env` with mode 600, sets the required kernel settings `vm.max_map_count` and file limits).

#### H. Explain the code
* Elasticsearch inside SonarQube refuses to start unless `vm.max_map_count >= 524288`; the script writes `/etc/sysctl.d/99-sonarqube.conf`.
* Two named volumes keep data and extensions across container restarts.
* Port 9000 is open **only to your IP** (security group).
* `sonarqube:community` is the free edition. It analyses the default branch only; for this project the pipeline analyses whichever branch runs and that is fine for learning.

#### I. Execute commands
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

#### J. Expected output
* `SonarQube is UP.` from the installer.
* After the first analysis the project page shows Quality Gate **Passed** or **Failed** with the metrics: bugs, vulnerabilities, hotspots, coverage, duplications, size.
* In Jenkins the stage `Quality gate` is green, or red with the message `Pipeline aborted due to quality gate failure: ERROR`.

#### K. Verification
1. SonarQube > Projects > FoodHub exists after the first run.
2. Open a finding, read "Why is this an issue?", fix one deliberately (for example add a short test), re-run: the count drops.
3. Prove the gate works: temporarily add `String password = "admin123";` in a Java class, push, and watch the gate (or the hotspot) catch it. Revert it.
4. Backend coverage is only reported if `mvn verify` produced `backend/target/site/jacoco/jacoco.xml` (JaCoCo is configured in `pom.xml`).

#### L. Troubleshooting
| Problem | Fix |
|---|---|
| Container exits: `max virtual memory areas vm.max_map_count [65530] is too low` | `sudo sysctl -w vm.max_map_count=524288` (the script does this; re-run it). |
| `Not enough memory` / SonarQube keeps restarting | Needs about 4 GB RAM: use `t3.medium` or larger (`sonarqube_instance_type`). |
| Stage hangs at `waitForQualityGate` | The webhook did not arrive: check URL ends with `/sonarqube-webhook/`, uses the Jenkins private IP, and port 8080 is allowed from the SonarQube security group. Check SonarQube > Administration > Webhooks > last delivery status. |
| `401 Unauthorized` in the scan | Wrong or expired token credential `sonar-token`. |
| `Not authorized. Analyzing this project requires authentication` | Same as above. |
| Coverage shows 0% | The Jacoco XML was not generated or the path in `sonar.coverage.jacoco.xmlReportPaths` is wrong. |
| Cannot open `:9000` from browser | `admin_cidrs` out of date, or still starting (first start 2-4 minutes). |

#### M. Completion checklist
- [ ] SonarQube reachable, admin password changed.
- [ ] Token created and stored **only** as a Jenkins credential.
- [ ] Jenkins "SonarQube servers" entry named `sonarqube` works (Test connection).
- [ ] Webhook to Jenkins created and delivering.
- [ ] I understand the quality gate and why I did not weaken security conditions.


---

## PHASE 11: Trivy Security Scanning

Cost: free (runs on the Jenkins server).

---

#### A. What are we doing?
Adding three automated security scans, all driven by one policy file (`trivy.yaml`):
1. **Filesystem scan** (`trivy fs`): known-vulnerable dependencies (Maven, npm), hard-coded secrets, misconfigurations in the source tree.
2. **IaC scan** (`trivy config`): risky settings in Terraform, Kubernetes manifests, Dockerfiles and `docker-compose.yml`.
3. **Image scan** (`trivy image`): vulnerabilities in the built Docker images (OS packages and libraries).

#### B. Why are we doing it?
Most real breaches use a known vulnerability or a leaked secret. Scanning every build in the pipeline ("shift left") stops them before they reach a cluster.

#### C. How does it work?
* Trivy keeps a vulnerability database (downloaded on first use, cached in `TRIVY_CACHE_DIR`).
* Each scan runs **twice**: pass 1 writes JSON/HTML reports and always succeeds (so you get a report even when the gate fails); pass 2 enforces the policy and exits non-zero on **HIGH or CRITICAL** findings, which fails the stage.
* `ignore-unfixed: true`: findings with no available fix do not fail the build (you cannot patch what is not patched); they still appear in the reports.
* **Exceptions** go only in `.trivyignore.yaml`, each with a statement and an **expiry date**, so an ignored finding must be reviewed again.

#### D. Where should I execute it?
On the **Jenkins EC2** (Trivy was installed in Phase 9). You can also run it on your laptop.

#### E. Which directory should I be in?
```bash
cd foodhub-devsecops
```

#### F. Which file should I create?
None. Policy files exist: `trivy.yaml`, `.trivyignore.yaml`, `jenkins/trivy/html.tpl` (HTML report template).

#### G. Complete code
All in the zip. Core of `trivy.yaml`: severities `HIGH,CRITICAL`, scanners `vuln,secret,misconfig`, `ignore-unfixed`, skip-dirs `node_modules`, `target`, `.terraform`, and `ignorefile: .trivyignore.yaml`.

#### H. Explain the code
`.trivyignore.yaml` currently carries **three justified exceptions** for the IaC scan, each with a reason and expiry:
* `AVD-AWS-0104` (egress to 0.0.0.0/0): Jenkins and SonarQube must reach GitHub, package mirrors and AWS APIs.
* `AVD-AWS-0040` (public EKS endpoint): a learning-friendly setting restricted by `admin_cidrs`; production should use a private endpoint plus VPN.
* `AVD-AWS-0057` (wildcard in IAM policy): the ELB controller's policy is AWS's official one.
Read each in the file. **Honest note:** these were predicted, not discovered by running Trivy (it could not be installed in the authoring environment), so your first run may show different findings. That is expected: see the triage procedure below.

#### I. Execute commands
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

#### J. Expected output
Trivy prints a table per target with columns Library / Vulnerability / Severity / Status / Installed Version / Fixed Version / Title, or `Total: 0 (HIGH: 0, CRITICAL: 0)` for clean targets. The exact findings depend on the day because the database updates daily; do not expect identical results.
Exit code `0` = clean under the policy, `1` = policy violated.

#### K. Verification
1. After a Jenkins run, open the build page > **Trivy security reports** (HTML) and **Build Artifacts** `reports/*.json`.
2. A deliberately planted fake secret turns the filesystem stage red.
3. Each `.trivyignore.yaml` entry has a statement and an `expired_at` date.
4. Registry side: ECR has **scan on push** enabled (Terraform), a second, independent check you can view in Console > ECR > image > Vulnerabilities.

#### L. Troubleshooting
| Problem | Fix |
|---|---|
| `failed to download vulnerability DB` / rate limit (TOOMANYREQUESTS) | Retry later; the cache avoids repeats. Mirrors can be set with `--db-repository`; check the Trivy docs for current values. |
| Scan takes very long first time | DB download; later runs are fast. |
| Many findings in `node_modules` | They are real dependency findings if reported by `package-lock.json`; fix with `npm audit fix` or upgrading the parent package. Do not skip directories to hide them. |
| Findings in base image OS packages | Rebuild with a newer base tag; pin the tag, not `latest`. |
| IaC scan reports something in a `.terraform` folder | That folder is skipped by config; make sure you run from the repo root. |
| `unknown field` in `.trivyignore.yaml` | The YAML ignore format needs `vulnerabilities:`, `misconfigurations:`, `secrets:` sections; compare with the file in the zip and the current Trivy docs. |

#### M. Completion checklist
- [ ] I ran fs, config and image scans.
- [ ] I triaged every HIGH/CRITICAL result: fixed, or ignored with reason and expiry.
- [ ] A planted fake secret failed the scan, then was removed.
- [ ] I can explain why scans run twice (report first, then enforce).
- [ ] I understand why `latest` and unpinned base images defeat scanning.


---

## PHASE 12: Jenkins CI/CD Pipeline

Cost: free beyond the Jenkins server. Pushing images costs a few rupees of ECR storage per month.

---

#### A. What are we doing?
Running the complete pipeline defined in `Jenkinsfile`, and a **separate** manual pipeline for infrastructure (`jenkins/Jenkinsfile.infra`).

#### B. Why are we doing it?
So that every change goes through the same gates (tests, quality, security) in the same order and only a passing `main` reaches production, with a way back.

#### C. How does it work? Stage by stage (the application pipeline)
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

#### D. Where should I execute it?
Jenkins UI (browser), plus GitHub for the webhook.

#### E. Which directory should I be in?
Nowhere on the server: Jenkins checks the repository out itself. On your laptop, `foodhub-devsecops` for edits and `git push`.

#### F. Which file should I create?
None; check these exist: `Jenkinsfile`, `jenkins/Jenkinsfile.infra`, `scripts/*.sh`. Before the first run, fix values at the top of `Jenkinsfile` if you changed names: `EKS_CLUSTER_NAME`, `K8S_NAMESPACE`, `AWS_REGION`.

#### G. Complete code
`Jenkinsfile` (application) and `jenkins/Jenkinsfile.infra` (infrastructure) in the zip.

#### H. Explain the infra pipeline
`Jenkinsfile.infra`: stages `Checkout`, `Init`, `Validate`, `Plan` (saved plan file archived), **`input` approval** (a human must press Proceed; a timeout aborts), `Apply` of **that exact saved plan**. There is no destroy stage by design: destruction is a deliberate human action from a laptop (Phase 16). It assumes the `terraform-deployer` role via `sts:AssumeRole`, which is the only extra AWS permission Jenkins has.

#### I. Execute commands / steps
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

#### J. Expected output
A green Stage View of all stages on `main` (stages 16-19 skipped on `develop`), ending with `SUCCESS: build-<N> (<sha>)`. The first run of each stage that downloads things (Maven, npm, Trivy DB) is slow (10+ minutes); later runs are faster.
ECR shows tags `build-<N>` and `sha-<8 chars>` on both repositories.

#### K. Verification
1. Break a unit test on a branch: stage 5 fails and nothing is pushed.
2. Add a fake secret: Trivy stage fails.
3. Only `main` shows stages 16-19 executed.
4. `kubectl -n foodhub get deploy -o wide` shows the `build-<N>` tag from the latest build, never `latest`.
5. ECR refuses re-pushing the same tag (immutability): a second `docker push` of an existing tag errors.

#### L. Troubleshooting
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

#### M. Completion checklist
- [ ] `develop` build passes all stages through ECR push.
- [ ] Failing test, failing quality gate, and failing scan each stop the pipeline.
- [ ] `main` build deploys and verifies (after Phase 13).
- [ ] Images in ECR carry immutable tags.
- [ ] I can narrate every stage and explain the rollback strategy.


---

## PHASE 13: Kubernetes Deployment on EKS

Cost: the ALB adds roughly ₹1,800 per month (about ₹60 per day) while it exists. Delete the Ingress when you stop (Phase 16).

---

#### A. What are we doing?
Preparing the EKS cluster once (controllers, secrets, policies), deploying the app, exposing it through an ALB, enabling autoscaling, and creating the first admin user.

#### B. Why are we doing it?
This is the production-style runtime: self-healing pods, rolling updates, autoscaling, network isolation, secrets from a vault.

#### C. How does it work?
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

#### D. Where should I execute it?
**Windows local machine (WSL2)**, with kubeconfig from Phase 8, `AWS_PROFILE=foodhub`. Cluster API access is limited by `admin_cidrs`.

#### E. Which directory should I be in?
```bash
cd foodhub-devsecops
```

#### F. Which file should I create?
None. Manifests are in `kubernetes/` and are templates: `${ECR_REGISTRY}` and `${IMAGE_TAG}` are filled in by `scripts/deploy.sh`.

#### G. Complete code
`kubernetes/` tree in the zip; scripts `bootstrap-cluster.sh`, `apply-external-secrets.sh`, `deploy.sh`, `create-admin.sh`, `rollback.sh`, `health-check.sh`.

#### H. Explain the code (key choices)
* `readOnlyRootFilesystem: true` plus `emptyDir` mounts at `/tmp` (and Nginx's cache/run dirs): the container cannot be modified at runtime. *Untested note:* the Nginx image writes rendered config at start; if the frontend pod crashes with a read-only filesystem error, see Troubleshooting.
* The backend `envFrom` takes the ConfigMap (non-secret settings), the secret `foodhub-secrets` (DB_URL, DB_USERNAME, DB_PASSWORD, JWT_SECRET) and an **optional** secret `foodhub-seed`.
* Probes: backend uses the actuator on port 8081 (`/actuator/health/liveness` and `/readiness`); the actuator port is **not** in the Service or Ingress, so it is not public.
* `ingress.yaml` is HTTP-only for a first working version; `ingress-https.yaml` adds an ACM certificate, port 443 and an HTTP to HTTPS redirect.
* HPA min 2 / max 4 (backend) and min 2 / max 4 (frontend) to protect a small dev cluster's capacity.

#### I. Execute commands
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

#### J. Expected output
* `ExternalSecret` shows `SecretSynced`.
* Pods: 2 backend and 2 frontend, all `1/1 Running` (backend can take about 60-90 seconds to become Ready).
* `get hpa` shows `cpu: <x>%/70%` once metrics are available (at first `<unknown>`).
* Ingress shows a hostname like `k8s-foodhub-...ap-south-1.elb.amazonaws.com`.
* Browser opens the site; admin login works with the password you chose.

#### K. Verification
1. `curl -s http://<alb-hostname>/api/restaurants | head -c 200` returns JSON.
2. `kubectl -n foodhub describe pod <backend-pod>` shows `Running as non-root`, resource limits, probes passing.
3. **Self-healing:** `kubectl -n foodhub delete pod <one backend pod>`; a new one appears and traffic continues.
4. **Rolling update:** deploy a new tag and watch `kubectl rollout status` (zero downtime because `maxUnavailable: 0`).
5. **Rollback:** `bash scripts/rollback.sh` (previous revision) and `kubectl -n foodhub rollout history deploy/foodhub-backend`.
6. **Network policy:** from a test pod in another namespace, connecting to the backend must time out.
7. **RDS privacy:** `aws rds describe-db-instances --query 'DBInstances[].PubliclyAccessible'` is `false`.
8. `kubectl auth can-i --as=system:serviceaccount:foodhub:default get secrets -n foodhub` is `no`.

#### L. Troubleshooting
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

#### M. Completion checklist
- [ ] Controllers and ESO running; ExternalSecret synced.
- [ ] 2+2 pods Running; Ingress has an ALB hostname.
- [ ] I created an admin with `create-admin.sh`; customer and admin flows work through the ALB.
- [ ] HPA reports metrics; self-healing and rollback demonstrated.
- [ ] NetworkPolicy and non-root checks done.
- [ ] I know which resources (ALB) are outside Terraform and must be deleted first.


---

## PHASE 14: Monitoring with Prometheus, Grafana and Alertmanager

Cost: no new AWS service, but Prometheus and Grafana use node CPU/memory and EBS storage (a few GB, about ₹100-300 per month). On a 2 x t3.medium dev cluster this is tight; if pods stay `Pending`, add a third node (`node_desired_size = 3`) or lower the Prometheus retention in `monitoring/kube-prometheus-stack-values.yaml`.

---

#### A. What are we doing?
Installing the **kube-prometheus-stack** Helm chart (Prometheus, Grafana, Alertmanager, node-exporter, kube-state-metrics), then adding FoodHub's own scrape config, alert rules and two Grafana dashboards.

#### B. Why are we doing it?
"If you cannot measure it, you cannot operate it." Monitoring tells you the application is slow or down before customers do.

#### C. How does it work?
* **node-exporter** (one pod per node): CPU, memory, disk, network of machines.
* **kube-state-metrics**: the state of Kubernetes objects (pod restarts, replicas wanted vs ready).
* **Spring Boot Actuator + Micrometer**: backend metrics at `/actuator/prometheus` on port **8081**: JVM memory, HTTP request counts, latencies, DB pool.
* **ServiceMonitor** (`kubernetes/monitoring/servicemonitor.yaml`): tells Prometheus "scrape the backend's port 8081 every 30 s". The NetworkPolicy already allows Prometheus to reach it.
* **PrometheusRule**: alert definitions. Prometheus evaluates them; firing alerts go to **Alertmanager**, which routes notifications (email/Slack).
* **Grafana**: dashboards; ConfigMaps with the label `grafana_dashboard=1` are auto-imported by a sidecar.

Alerts included: `FoodHubPodCrashLooping`, `FoodHubHighPodCPU`, `FoodHubHighPodMemory`, `FoodHubNodeNotReady`, `FoodHubBackendDown`, `FoodHubHigh5xxRate`, `FoodHubSlowApi`.

#### D. Where should I execute it?
Windows (WSL2) with `kubectl` and `helm` connected to the cluster.

#### E. Which directory should I be in?
```bash
cd foodhub-devsecops
```

#### F. Which file should I create?
None. Files: `monitoring/kube-prometheus-stack-values.yaml`, `monitoring/dashboards/*.json`, `monitoring/alertmanager-email-example.yaml`, `kubernetes/monitoring/*`.

#### G. Complete code
In the zip. Notable settings in the values file: the Grafana admin password comes from the Kubernetes Secret `grafana-admin` (random, created by the script), services are `ClusterIP` (not public), `serviceMonitorSelectorNilUsesHelmValues: false` so Prometheus picks up ServiceMonitors from any namespace, and Alertmanager starts with a `null` receiver.

#### H. Explain the code
Grafana and Prometheus are **not exposed to the internet**. You reach them with `kubectl port-forward`, which tunnels through your authenticated kubectl session. Exposing Grafana publicly needs TLS and SSO and is outside this learning scope.

#### I. Execute commands
**1. Install everything**
```bash
bash scripts/install-monitoring.sh
```
**2. Wait for pods** (3-5 minutes)
```bash
kubectl -n monitoring get pods
```
**3. Record the chart version it installed** (then set `KPS_CHART_VERSION`)
```bash
helm list -n monitoring
```
**4. Read the generated Grafana password**
```bash
kubectl -n monitoring get secret grafana-admin -o jsonpath='{.data.admin-password}' | base64 -d; echo
```
**5. Open Grafana** (keep this terminal running)
```bash
kubectl -n monitoring port-forward svc/kube-prometheus-stack-grafana 3000:80
```
Browse http://localhost:3000, user `admin`. Open Dashboards > **FoodHub Cluster** and **FoodHub Backend**.
**6. Open Prometheus** (another terminal)
```bash
kubectl -n monitoring port-forward svc/kube-prometheus-stack-prometheus 9090:9090
```
Browse http://localhost:9090/targets: the FoodHub backend target must be `UP`. Try the query `up{namespace="foodhub"}`.
**7. Test an alert deliberately**
```bash
kubectl -n foodhub scale deploy/foodhub-backend --replicas=0
```
Wait about 2-3 minutes: `FoodHubBackendDown` goes *Pending* then *Firing* (Prometheus > Alerts). Restore:
```bash
kubectl -n foodhub scale deploy/foodhub-backend --replicas=2
```
(If the HPA fights you, that is fine: it restores the minimum anyway.)
**8. See the alert in Alertmanager**
```bash
kubectl -n monitoring port-forward svc/kube-prometheus-stack-alertmanager 9093:9093
```
http://localhost:9093.
**9. Email notifications (optional):** copy `monitoring/alertmanager-email-example.yaml`, put in your SMTP host and an **app password** supplied through a Kubernetes Secret (never in Git), apply, and re-run step 7.

#### J. Expected output
* All pods in `monitoring` `Running` (Prometheus, Alertmanager, Grafana, operator, kube-state-metrics, node-exporter x nodes).
* Grafana dashboards show live panels (node CPU/memory, pod restarts, request rate, latency percentiles, JVM heap).
* Prometheus Targets page shows the backend `UP`.
* The test alert reaches `Firing` and appears in Alertmanager.

#### K. Verification
1. Generate traffic: run `bash scripts/smoke-test.sh http://<alb-host> admin@yourdomain.com '<password>'` and watch **Request rate** rise.
2. Kill a backend pod and see the **pod restarts / replicas** panels react.
3. `http://localhost:9090/rules` lists the seven FoodHub rules as `OK`.
4. Confirm Grafana is not reachable from the internet: `kubectl -n monitoring get svc` shows only `ClusterIP` (no `LoadBalancer`).

#### L. Troubleshooting
| Problem | Fix |
|---|---|
| Pods `Pending` | Not enough memory; add a node or reduce replicas/retention. |
| Backend target missing | ServiceMonitor label/port name mismatch: `kubectl -n foodhub get servicemonitor -o yaml` and compare with the Service port named `metrics`. |
| Target `DOWN` with timeout | NetworkPolicy blocking: confirm `kubernetes/network-policies` allows namespace `monitoring` to port 8081. |
| Dashboard panels say "No data" | Time range too short or metrics not yet scraped (wait 2 minutes); check the query in Prometheus. |
| Grafana login fails | Re-read the password from the Secret (step 4). |
| Helm `rendered manifests contain a resource that already exists` (CRDs) | A previous install remains: `helm -n monitoring uninstall kube-prometheus-stack`, delete leftover CRDs only if you are sure. |
| Alertmanager never sends mail | Normal until you configure a receiver (step 9). |

#### M. Completion checklist
- [ ] Prometheus, Grafana, Alertmanager running; backend target `UP`.
- [ ] Both dashboards show data.
- [ ] I triggered and observed an alert, then restored the deployment.
- [ ] Grafana is reachable only via port-forward.
- [ ] I can explain Prometheus (pull), exporters, ServiceMonitor and Alertmanager.


---

## PHASE 15: Final Validation

Cost: none beyond what is running. Do this while the environment is up, then go to Phase 16 to clean up.

---

#### A. What are we doing?
A full, systematic acceptance test of every tier, every pipeline stage and every security control, with evidence.

#### B. Why are we doing it?
"It seems to work" is not a result. Validation turns assumptions into checked facts, and it is exactly what an interviewer or reviewer will ask about.

#### C. How does it work?
Go top-down through the checklist. Tick a box only when you have seen the evidence yourself. Anything you cannot verify stays unticked and is written up honestly.

#### D. Where should I execute it?
WSL2 terminal and browser; Jenkins and Grafana UIs.

#### E. Which directory should I be in?
```bash
cd foodhub-devsecops
```

#### F. Which file should I create?
Optionally `VALIDATION-NOTES.md` (not committed if it contains addresses) for your evidence: screenshots and command output.

#### G. Complete code
`scripts/smoke-test.sh` automates the API journey: register, login, list restaurants, cart, order, payment, admin status changes, dashboard.

#### H. Explain the code
The smoke test checks **business rules**, not just HTTP 200: prices come from the server, an invalid status transition is rejected (400), a customer cannot use admin APIs (403), and an anonymous request to a protected API is 401.

#### I. Execute commands
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

#### J. Expected output
The smoke test prints `PASS` lines and `ALL SMOKE TESTS PASSED`. Output of the other commands matches the descriptions above: `No changes.`; tags `build-N`; RDS `false true`; ECR `IMMUTABLE true`; no keys found.

#### K. Verification (the master checklist)
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

#### L. Troubleshooting
Use the table for the failing tier in its phase guide, or `docs/TROUBLESHOOTING.md`. Method: read the exact error, find which component printed it (browser console, Nginx, backend log, RDS, Jenkins console), reproduce with the smallest command, fix one thing, re-test.

#### M. Completion checklist
- [ ] Every box in section K is ticked or has a written, honest exception.
- [ ] Screenshots saved: ALB site, Jenkins stage view, SonarQube result, Trivy report, Grafana, `kubectl get all`.
- [ ] I can demo the project in 10 minutes and answer "what would you change for real production?" (see `docs/INTERVIEW-QA.md`).


---

## PHASE 16: Production Hardening and Cleanup

---

#### A. What are we doing?
Two things: (1) the list of changes that turn this learning-grade setup into a production setup, and (2) **destroying everything safely** so AWS billing stops.

#### B. Why are we doing it?
Forgotten resources are the most common surprise bill (EKS control plane, NAT, ALB, RDS and EC2 bill every hour whether or not anyone uses them). Production hardening is the difference between a demo and a service.

#### C. How does it work? Dev shortcuts versus production
| Area | Dev (this project defaults) | Production |
|---|---|---|
| NAT | one shared | one per AZ |
| Nodes | 2 x t3.medium | bigger, mixed, Karpenter or Cluster Autoscaler, multiple AZs |
| RDS | single AZ, deletion protection off, no final snapshot | **Multi-AZ**, deletion protection on, final snapshot, 7-35 days backups, read replica if needed, RDS Proxy |
| Secrets | random generated | rotation enabled in Secrets Manager |
| Access | IP allow-list | VPN or SSO, private EKS endpoint, WAF on the ALB |
| TLS | HTTP for learning | ACM certificate, HTTPS only, HSTS |
| Images | pinned tags | plus image signing (cosign) and admission policy (Kyverno/OPA) |
| State | one S3 bucket | separate state per environment and account, restricted bucket access |
| Environments | dev | separate AWS accounts for dev / staging / prod |
| Logging | EKS control-plane logs | central logs (CloudWatch/OpenSearch), CloudTrail, GuardDuty, AWS Config |
| Monitoring | port-forward | SSO-protected Grafana, Alertmanager to Slack/PagerDuty, SLOs |
| Backups | RDS automated | tested restore drills |
| Deploy | Jenkins to cluster | GitOps (Argo CD) is the usual next step |
`environments/prod/prod.tfvars` already sets the safer values for NAT, nodes, Multi-AZ and deletion protection.

#### D. Where should I execute it?
Windows (WSL2) with `AWS_PROFILE=foodhub`.

#### E. Which directory should I be in?
```bash
cd foodhub-devsecops
```

#### F. Which file should I create?
None.

#### G. Complete code
`scripts/cleanup-aws.sh` removes Kubernetes-created AWS resources (ALB) first.

#### H. Explain the code
Terraform only knows about what it created. The ALB and its security groups are created by the Load Balancer Controller **outside Terraform**, and they sit inside your VPC, so `terraform destroy` fails (or hangs) when deleting the VPC unless they are removed first. The script deletes the Ingress, waits for the controller to delete the ALB, uninstalls monitoring (releases volumes and any load balancer) and lists what remains.

#### I. Execute commands (order matters)
**1. Stop and keep nothing you need.** Export anything you want (screenshots, data). To keep a database copy:
```bash
aws rds create-db-snapshot --db-instance-identifier <id> --db-snapshot-identifier foodhub-final-$(date +%Y%m%d)
```
(a snapshot costs a little per GB-month; delete it later if not needed).

**2. Remove Kubernetes-created AWS resources**
```bash
bash scripts/cleanup-aws.sh
```
The load-balancer list at the end must be empty.

**3. Delete the namespaces** (PVC-backed volumes are released)
```bash
kubectl delete namespace foodhub monitoring --wait=true
```
**4. Destroy the infrastructure**
```bash
terraform -chdir=terraform plan -destroy -var-file=environments/dev/dev.tfvars
```
Read it; then
```bash
terraform -chdir=terraform destroy -var-file=environments/dev/dev.tfvars
```
(type `yes`; takes 10-20 minutes). ECR repositories are deleted with their images because dev sets `ecr_force_delete = true`; the secrets use recovery window 0 in dev, so they disappear immediately.

**5. Prove nothing is left (each should list nothing relevant)**
```bash
aws eks list-clusters
aws rds describe-db-instances --query 'DBInstances[].DBInstanceIdentifier'
aws ec2 describe-instances --filters Name=instance-state-name,Values=running,stopped --query 'Reservations[].Instances[].InstanceId'
aws ec2 describe-nat-gateways --filter Name=state,Values=available --query 'NatGateways[].NatGatewayId'
aws ec2 describe-addresses --query 'Addresses[].PublicIp'
aws elbv2 describe-load-balancers --query 'LoadBalancers[].LoadBalancerName'
aws ec2 describe-volumes --filters Name=status,Values=available --query 'Volumes[].VolumeId'
aws secretsmanager list-secrets --query 'SecretList[].Name'
```
**6. Keep or delete the state bucket.** It costs almost nothing and has `prevent_destroy`. To remove it you must empty all object versions and remove the lifecycle guard deliberately; only do that when you are finished with the project for good.

**7. Check billing the next day:** Console > Billing > Cost Explorer; the budget alerts should stay quiet.

**Pausing instead of destroying (cheaper to resume, but not free):** stop the Jenkins and SonarQube EC2 instances (EBS and Elastic IPs still bill) and scale nodes to 0. The EKS control plane, NAT and RDS keep billing. Destroy is the only way to stop nearly all cost.

#### J. Expected output
`Destroy complete! Resources: N destroyed.` and the checks in step 5 returning empty lists (or only your intentionally kept items).

#### K. Verification
Next morning: Billing dashboard shows daily cost near zero (a few rupees for S3). No EKS, RDS, NAT or ELB entries in the Console for ap-south-1. Do not forget other regions if you experimented elsewhere.

#### L. Troubleshooting
| Problem | Fix |
|---|---|
| `DependencyViolation` deleting subnets / security group / VPC | An ENI or ALB remains: Console > EC2 > Network Interfaces, filter by VPC; delete the leftover load balancer, wait a few minutes, retry destroy. |
| Destroy stuck on EKS node group | Pods with finalizers or a PodDisruptionBudget: delete namespaces first (step 3). |
| `Error: deletion protection is enabled` (RDS) | Prod-style setting; set `db_deletion_protection=false`, apply, then destroy. Intentional safety. |
| Secret "scheduled for deletion" blocks a re-create with the same name | Use recovery window 0 in dev, or restore/force-delete: `aws secretsmanager delete-secret --force-delete-without-recovery --secret-id <name>`. |
| S3 bucket will not delete | It is versioned: all versions and delete markers must be removed first (and `prevent_destroy` lifted). |
| State lock stuck | `terraform force-unlock <ID>` after confirming nothing runs. |

#### M. Completion checklist
- [ ] Ingress deleted first; no load balancers remain.
- [ ] `terraform destroy` completed.
- [ ] Verification commands show no EKS, RDS, EC2, NAT, EIP, unattached volumes.
- [ ] Billing checked next day.
- [ ] I can list five changes required for production and why.
- [ ] Access keys of `foodhub-admin` are deactivated if I am done for good.
