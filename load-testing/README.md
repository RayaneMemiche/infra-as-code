# Load Testing - Task Manager API

Locust-based load tests for the Task Manager API. Primarily used to demonstrate
Horizontal Pod Autoscaler (HPA) behaviour during the defense.

## Install

```bash
pip install -r requirements.txt
```

## Run locally (web UI)

```bash
locust -f locustfile.py --host=http://localhost:3000
```

Open http://localhost:8089 in your browser, set the number of users and spawn
rate, then start the test.

## Run in headless mode

```bash
./run-load-test.sh                           # defaults: 50 users, 5/s spawn, 2 min
./run-load-test.sh http://localhost:3000 100 10 5m   # custom params
```

## Run against GKE

1. Forward the API service port:

```bash
kubectl port-forward svc/task-manager-api 3000:3000
```

2. In another terminal, start the load test:

```bash
./run-load-test.sh http://localhost:3000 200 10 5m
```

## Demonstrate HPA autoscaling

1. Make sure the HPA is configured (`kubectl get hpa`).
2. Start a load test with a high user count (200+) and let it run for a few
   minutes.
3. Watch pods scale up:

```bash
kubectl get hpa -w
kubectl get pods -w
```

4. Stop the load test and observe the pods scaling back down (this takes a few
   minutes due to the cool-down period).

## Observe results in Grafana

While the load test is running:

1. Open Grafana (port-forward if needed: `kubectl port-forward svc/grafana 3001:80`).
2. Check the Node.js / Express dashboard for request rate, latency, and error
   rate.
3. Check the Kubernetes / HPA dashboard for replica count and CPU usage.
4. The Locust HTML report is saved to `report.html` when using headless mode.
