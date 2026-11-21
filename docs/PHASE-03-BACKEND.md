# PHASE 3: Spring Boot Backend

Cost: **free**. Needs JDK 21 and Maven 3.9+.

> **Read this first.** The backend was written without being able to compile it (the workspace had no access to Maven Central).
> Step I-1 below is therefore the real first test. If it prints a compile error, copy the whole error text to Claude: it is normally a one-line fix.

---

### A. What are we doing?
Building and testing the Java 21 / Spring Boot 3.5 REST API: authentication, restaurants, foods, cart, orders, payments, admin operations, dashboard.

### B. Why are we doing it?
This is Tier 2: all business rules live here (who may do what, order totals, order status rules). The frontend can be bypassed by anyone with `curl`, so **every rule must be enforced on the server**.

### C. How does it work?
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

### D. Where should I execute it?
**Windows local machine** (WSL2 or PowerShell). MySQL is needed for the *running* app (Phase 4); the unit tests do **not** need a database.

### E. Which directory should I be in?
```bash
cd foodhub-devsecops/backend
```

### F. Which file should I create?
None; the project exists. Files to read, in this order:

1. `pom.xml` (dependencies)
2. `src/main/resources/application.yml` (configuration, all secrets from env vars)
3. `entity/*.java`, `repository/*.java` (data)
4. `security/*.java`, `config/SecurityConfig.java` (login and permissions)
5. `service/*.java` (business logic)
6. `controller/*.java` (HTTP)
7. `src/test/java/...` (tests)

### G. Complete code
All 86 files are complete in the zip under `backend/`.

### H. Explain the code
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

### I. Execute commands
**1. Compile and run the unit tests (this is the first real compile of the backend):**
```bash
mvn -B test
```
**2. Build the jar:**
```bash
mvn -B clean package
```
(Running the application needs MySQL and environment variables; that is Phase 4.)

### J. Expected output
Maven prints many download lines the first time (a few minutes). A successful test run ends with lines of this shape (your counts and times will differ):
```
[INFO] Tests run: <n>, Failures: 0, Errors: 0, Skipped: 0
[INFO] BUILD SUCCESS
```
There are 6 test classes; all must pass. `target/foodhub-backend.jar` exists after `package`, and `target/site/jacoco/jacoco.xml` after `test`.

### K. Verification
```bash
ls target/foodhub-backend.jar
```
```bash
ls target/surefire-reports
```
No `*.txt` report may contain `FAILURE`.

### L. Troubleshooting
| Error | Cause and fix |
|---|---|
| `release version 21 not supported` | Maven uses an older JDK. `java -version` and `mvn -v` must both say 21. Set `JAVA_HOME`. |
| `Could not resolve dependencies ... springdoc/jjwt version` | A version in `pom.xml` is wrong or too new/old. Open https://central.sonatype.com, find the latest 3.5.x of `spring-boot-starter-parent` or the library, update the number in `pom.xml`, rerun. |
| `cannot find symbol ... getId()/builder()` | Lombok not processed. Use JDK 21 with Maven (not an IDE-only build); in IntelliJ enable Annotation Processing. |
| A compile error in a file | Copy the full error to Claude. The code could not be compiled when it was generated. |
| `Mockito ... UnnecessaryStubbingException` | A test stubs something the code no longer calls: remove that `when(...)` line. |
| SSL/proxy errors downloading dependencies | Corporate proxy: configure `~/.m2/settings.xml`. |

### M. Completion checklist
- [ ] `mvn -B test` passes with 0 failures.
- [ ] `mvn -B clean package` creates `target/foodhub-backend.jar`.
- [ ] I can explain the request flow (filter, security rules, controller, service, repository).
- [ ] I can explain why totals are computed on the server and why money uses `BigDecimal`.
- [ ] I know why customers get 404 (not 403) for other people's orders.
