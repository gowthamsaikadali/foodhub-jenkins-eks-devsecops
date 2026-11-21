# syntax=docker/dockerfile:1

# ---------- Stage 1: build the React app ----------
FROM node:20-alpine AS build
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --no-audit --no-fund
COPY . .
# The browser calls /api on the same host; Nginx / the Ingress forwards it to the backend.
ENV VITE_API_URL=/api
RUN npm run build

# ---------- Stage 2: serve static files with unprivileged Nginx ----------
FROM nginxinc/nginx-unprivileged:1.27-alpine
# Files in /etc/nginx/templates/*.template are processed with envsubst at container start
COPY nginx.conf.template /etc/nginx/templates/default.conf.template
COPY --from=build /app/dist /usr/share/nginx/html
ENV BACKEND_URL=http://backend:8080
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=3s CMD wget -qO- http://127.0.0.1:8080/healthz || exit 1
