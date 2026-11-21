# PHASE 5: Local Docker Deployment

Cost: **free**.

---

### A. What are we doing?
Packaging the frontend and backend as Docker images and running the whole system (frontend + backend + MySQL) with one command, exactly the way it will later run on Kubernetes.

### B. Why are we doing it?
"It works on my machine" is the problem containers solve. The same image that passes tests locally is the image that Jenkins pushes to ECR and EKS runs.

### C. How does it work? (vocabulary first)
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

### D. Where should I execute it?
**Windows local machine**, WSL2 terminal, Docker Desktop running.

### E. Which directory should I be in?
```bash
cd foodhub-devsecops
```

### F. Which file should I create?
Only `.env` (done in Phase 4). Files used:

| File | Purpose |
|---|---|
| `backend/Dockerfile` | Maven build stage, then a small JRE runtime image |
| `frontend/Dockerfile` | Node build stage, then unprivileged Nginx |
| `frontend/nginx.conf.template` | Nginx config; `${BACKEND_URL}` is filled in at start |
| `docker-compose.yml` | Defines the three services, network and volume |
| `docker/mysql/my.cnf` | MySQL character set and timezone |

### G. Complete code
All files are complete in the zip at the paths above.

### H. Explain the code
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

### I. Execute commands
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

### J. Expected output
* `docker compose ps` lists `foodhub-mysql`, `foodhub-backend`, `foodhub-frontend`; the first two show `(healthy)` (the backend takes about a minute).
* The `curl` returns JSON starting with `[{"id":1,"name":"Hyderabad Spice House"...`.
* The smoke test ends with `ALL SMOKE TESTS PASSED`.
* Open http://localhost:3000 : restaurants appear; the customer and admin flows from Phase 4 work.

### K. Verification
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

### L. Troubleshooting
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

### M. Completion checklist
- [ ] `docker compose up -d` shows all three services running, database and backend healthy.
- [ ] http://localhost:3000 works for customer and admin flows.
- [ ] `smoke-test.sh` passes through port 3000.
- [ ] Data survives `docker compose down` / `up`.
- [ ] Containers do not run as root.
- [ ] I can explain image vs container, network, volume, port mapping, and multi-stage builds.
- [ ] **Local testing succeeded, so cloud work may begin** (the master plan forbids going to AWS before this).
