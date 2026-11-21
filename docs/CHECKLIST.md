# Master project checklist

Tick in order. Do not move to a cloud phase until the local phases pass.

## Local (free)
- [ ] 1 Architecture understood; I can draw the three tiers and the traffic flow
- [ ] 2 Frontend: `npm ci && npm test && npm run build` pass; runs against the backend
- [ ] 3 Backend: `mvn test` passes (first thing to run); Swagger works
- [ ] 4 MySQL: Flyway ran V1-V3; smoke test passes
- [ ] 5 Docker Compose: all services healthy; data persists
- [ ] 6 GitHub: repo with main and develop; no secrets committed; branch protection on

## AWS (paid; budget first)
- [ ] 7 Root MFA, admin user, CLI profile, budget alarm, state bucket
- [ ] 8 `terraform validate` ok, plan reviewed, apply done, nodes Ready
- [ ] 9 Jenkins installed; instance role verified; plugins; multibranch job
- [ ] 10 SonarQube up; token and webhook; quality gate enforced
- [ ] 11 Trivy fs / IaC / image scans triaged
- [ ] 12 Pipeline green on develop; main deploys
- [ ] 13 Cluster bootstrapped; secrets synced; ALB works; admin created; HPA works
- [ ] 14 Monitoring live; alert tested
- [ ] 15 Validation checklist complete, evidence saved
- [ ] 16 Everything destroyed and verified, billing checked

## Security rules to confirm at the end
- [ ] No passwords, keys or tokens in Git (history searched)
- [ ] No AWS access keys on Jenkins (instance profile only)
- [ ] RDS private and encrypted; secrets in Secrets Manager
- [ ] Containers non-root with read-only root filesystem
- [ ] Images immutable-tagged, scanned, never `latest`
- [ ] Jenkins, SonarQube and the EKS API limited to my IP
- [ ] Actuator and Grafana not public
