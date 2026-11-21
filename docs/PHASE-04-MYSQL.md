# PHASE 4: MySQL Integration

Cost: **free** (MySQL runs in Docker on your computer).

---

### A. What are we doing?
Starting a local MySQL 8, letting the backend create the schema with **Flyway migrations**, running the backend against it, and testing CRUD plus the complete order flow with real data.

### B. Why are we doing it?
Tier 3 is where data lives. We prove the whole stack (backend to database) works locally before spending a rupee on AWS. Everything that fails here would also fail on RDS, only more expensively.

### C. How does it work?
* `docker compose up -d mysql` starts a MySQL container. The database `foodhub` and user are created from the environment variables in `.env`. Data is kept in the Docker **volume** `mysql_data`.
* On startup the backend connects with `DB_URL`, `DB_USERNAME`, `DB_PASSWORD`. **Flyway** looks at the table `flyway_schema_history`, and runs every `V<number>__name.sql` that has not run yet, in order:
  * `V1__create_schema.sql` creates 11 tables with primary keys, foreign keys, indexes, CHECK constraints, DECIMAL money columns.
  * `V2__seed_roles.sql` inserts `ROLE_CUSTOMER` and `ROLE_ADMIN`.
  * `V3__seed_sample_data.sql` inserts 3 restaurants, 6 categories and 13 dishes.
* Flyway stores a **checksum** of each applied file. If you edit an applied migration, startup fails. That is intentional: history must not be rewritten. To change the schema, add `V4__...sql`.
* `DataInitializer` creates the demo admin and customer **only if** you provide `SEED_*_PASSWORD` values, and gives the sample restaurants to the admin (restaurants are owned by an admin; admins manage only their own).

Table overview: see `database/ER-DIAGRAM.md` (diagram and design reasons).

### D. Where should I execute it?
**Windows local machine** (WSL2 Ubuntu recommended). Docker Desktop must be running.

### E. Which directory should I be in?
```bash
cd foodhub-devsecops
```
(the repository root, where `docker-compose.yml` is). Maven commands later use `cd backend`.

### F. Which file should I create?
One file: **`.env`** in the repository root (never committed). Create it from the template:
```bash
cp .env.example .env
```

### G. Complete code
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

### H. Explain the code
* `MYSQL_DATABASE`, `MYSQL_USER`, `MYSQL_PASSWORD`: the official MySQL image creates them on the first start only. If you change them later you must delete the volume (`docker compose down -v`).
* `ports: "127.0.0.1:3307:3306"`: host port 3307 forwards to the container's 3306, **bound to localhost only** so nobody on your Wi-Fi can reach the database. (3307 avoids a clash with a MySQL you may already have on 3306.)
* `healthcheck` with `mysqladmin ping`: Compose marks the container healthy only when MySQL answers, and the backend service waits for that (`depends_on: condition: service_healthy`).
* `docker/mysql/my.cnf`: forces `utf8mb4` and UTC.
* JDBC URL options: `sslMode=DISABLED` (local only, no TLS inside Docker); the cluster URL uses `sslMode=REQUIRED` for RDS.

### I. Execute commands
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

### J. Expected output
* Backend log contains lines like `Migrating schema ... to version "1 - create schema"`, then `"2 - seed roles"`, `"3 - seed sample data"`, then `Started FoodHubApplication in N seconds` (numbers differ). On later starts Flyway says `Schema ... is up to date`.
* `SHOW TABLES;` lists 12 tables: the 11 application tables plus `flyway_schema_history`.
* `flyway_schema_history` shows three rows with `success = 1`.
* The smoke test prints a `PASS` line per check and ends with `ALL SMOKE TESTS PASSED`, followed by dashboard JSON with counts and `totalOrderValue`.

### K. Verification (manual, as a user would)
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

### L. Troubleshooting
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

### M. Completion checklist
- [ ] MySQL container is `healthy`.
- [ ] Flyway ran V1, V2, V3 successfully (`flyway_schema_history`).
- [ ] `scripts/smoke-test.sh` ends with `ALL SMOKE TESTS PASSED`.
- [ ] I placed an order through the UI and the admin moved it to DELIVERED.
- [ ] The order survived a backend restart.
- [ ] I can explain Flyway checksums and why prices are never accepted from the client.
