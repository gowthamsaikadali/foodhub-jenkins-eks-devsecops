# syntax=docker/dockerfile:1

# ---------- Stage 1: build the jar with Maven ----------
FROM maven:3.9-eclipse-temurin-21 AS build
WORKDIR /workspace
# Copy pom first so Docker caches downloaded dependencies until pom.xml changes
COPY pom.xml .
RUN mvn -B -q dependency:go-offline
COPY src ./src
RUN mvn -B -q clean package -DskipTests

# ---------- Stage 2: small runtime image ----------
FROM eclipse-temurin:21-jre-alpine
# Run as a non-root user (security best practice)
RUN addgroup -S -g 10001 foodhub && adduser -S -u 10001 -G foodhub foodhub
WORKDIR /app
COPY --from=build /workspace/target/foodhub-backend.jar app.jar
USER 10001
# 8080 = API, 8081 = actuator (health + metrics, never exposed through the ingress)
EXPOSE 8080 8081
ENV JAVA_OPTS="-XX:MaxRAMPercentage=75 -XX:+ExitOnOutOfMemoryError"
ENTRYPOINT ["sh", "-c", "exec java $JAVA_OPTS -jar /app/app.jar"]
