# PHASE 14: Monitoring with Prometheus, Grafana and Alertmanager

Cost: no new AWS service, but Prometheus and Grafana use node CPU/memory and EBS storage (a few GB, about ₹100-300 per month). On a 2 x t3.medium dev cluster this is tight; if pods stay `Pending`, add a third node (`node_desired_size = 3`) or lower the Prometheus retention in `monitoring/kube-prometheus-stack-values.yaml`.

---

### A. What are we doing?
Installing the **kube-prometheus-stack** Helm chart (Prometheus, Grafana, Alertmanager, node-exporter, kube-state-metrics), then adding FoodHub's own scrape config, alert rules and two Grafana dashboards.

### B. Why are we doing it?
"If you cannot measure it, you cannot operate it." Monitoring tells you the application is slow or down before customers do.

### C. How does it work?
* **node-exporter** (one pod per node): CPU, memory, disk, network of machines.
* **kube-state-metrics**: the state of Kubernetes objects (pod restarts, replicas wanted vs ready).
* **Spring Boot Actuator + Micrometer**: backend metrics at `/actuator/prometheus` on port **8081**: JVM memory, HTTP request counts, latencies, DB pool.
* **ServiceMonitor** (`kubernetes/monitoring/servicemonitor.yaml`): tells Prometheus "scrape the backend's port 8081 every 30 s". The NetworkPolicy already allows Prometheus to reach it.
* **PrometheusRule**: alert definitions. Prometheus evaluates them; firing alerts go to **Alertmanager**, which routes notifications (email/Slack).
* **Grafana**: dashboards; ConfigMaps with the label `grafana_dashboard=1` are auto-imported by a sidecar.

Alerts included: `FoodHubPodCrashLooping`, `FoodHubHighPodCPU`, `FoodHubHighPodMemory`, `FoodHubNodeNotReady`, `FoodHubBackendDown`, `FoodHubHigh5xxRate`, `FoodHubSlowApi`.

### D. Where should I execute it?
Windows (WSL2) with `kubectl` and `helm` connected to the cluster.

### E. Which directory should I be in?
```bash
cd foodhub-devsecops
```

### F. Which file should I create?
None. Files: `monitoring/kube-prometheus-stack-values.yaml`, `monitoring/dashboards/*.json`, `monitoring/alertmanager-email-example.yaml`, `kubernetes/monitoring/*`.

### G. Complete code
In the zip. Notable settings in the values file: the Grafana admin password comes from the Kubernetes Secret `grafana-admin` (random, created by the script), services are `ClusterIP` (not public), `serviceMonitorSelectorNilUsesHelmValues: false` so Prometheus picks up ServiceMonitors from any namespace, and Alertmanager starts with a `null` receiver.

### H. Explain the code
Grafana and Prometheus are **not exposed to the internet**. You reach them with `kubectl port-forward`, which tunnels through your authenticated kubectl session. Exposing Grafana publicly needs TLS and SSO and is outside this learning scope.

### I. Execute commands
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

### J. Expected output
* All pods in `monitoring` `Running` (Prometheus, Alertmanager, Grafana, operator, kube-state-metrics, node-exporter x nodes).
* Grafana dashboards show live panels (node CPU/memory, pod restarts, request rate, latency percentiles, JVM heap).
* Prometheus Targets page shows the backend `UP`.
* The test alert reaches `Firing` and appears in Alertmanager.

### K. Verification
1. Generate traffic: run `bash scripts/smoke-test.sh http://<alb-host> admin@yourdomain.com '<password>'` and watch **Request rate** rise.
2. Kill a backend pod and see the **pod restarts / replicas** panels react.
3. `http://localhost:9090/rules` lists the seven FoodHub rules as `OK`.
4. Confirm Grafana is not reachable from the internet: `kubectl -n monitoring get svc` shows only `ClusterIP` (no `LoadBalancer`).

### L. Troubleshooting
| Problem | Fix |
|---|---|
| Pods `Pending` | Not enough memory; add a node or reduce replicas/retention. |
| Backend target missing | ServiceMonitor label/port name mismatch: `kubectl -n foodhub get servicemonitor -o yaml` and compare with the Service port named `metrics`. |
| Target `DOWN` with timeout | NetworkPolicy blocking: confirm `kubernetes/network-policies` allows namespace `monitoring` to port 8081. |
| Dashboard panels say "No data" | Time range too short or metrics not yet scraped (wait 2 minutes); check the query in Prometheus. |
| Grafana login fails | Re-read the password from the Secret (step 4). |
| Helm `rendered manifests contain a resource that already exists` (CRDs) | A previous install remains: `helm -n monitoring uninstall kube-prometheus-stack`, delete leftover CRDs only if you are sure. |
| Alertmanager never sends mail | Normal until you configure a receiver (step 9). |

### M. Completion checklist
- [ ] Prometheus, Grafana, Alertmanager running; backend target `UP`.
- [ ] Both dashboards show data.
- [ ] I triggered and observed an alert, then restored the deployment.
- [ ] Grafana is reachable only via port-forward.
- [ ] I can explain Prometheus (pull), exporters, ServiceMonitor and Alertmanager.
