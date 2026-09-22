import os
import time
import socket
import datetime
from flask import Flask, render_template, jsonify, request

app = Flask(__name__)

# Server start timestamp
START_TIME = time.time()

# Configuration from Environment Variables (injected via Kubernetes or Docker)
APP_VERSION = os.getenv("APP_VERSION", "v1.0")
PORT = int(os.getenv("PORT", "8080"))
POD_NAME = os.getenv("POD_NAME", socket.gethostname())
POD_NAMESPACE = os.getenv("POD_NAMESPACE", "gitops-demo")
POD_IP = os.getenv("POD_IP", "127.0.0.1")
NODE_NAME = os.getenv("NODE_NAME", "cluster-node")
ENVIRONMENT = os.getenv("ENVIRONMENT", "production")

def get_uptime():
    seconds = int(time.time() - START_TIME)
    minutes, sec = divmod(seconds, 60)
    hours, minutes = divmod(minutes, 60)
    return f"{hours:02d}h {minutes:02d}m {sec:02d}s"

@app.route("/")
def index():
    context = {
        "version": APP_VERSION,
        "is_v2": "v2" in APP_VERSION.lower(),
        "pod_name": POD_NAME,
        "pod_namespace": POD_NAMESPACE,
        "pod_ip": POD_IP,
        "node_name": NODE_NAME,
        "environment": ENVIRONMENT,
        "uptime": get_uptime(),
        "client_ip": request.remote_addr,
        "current_time": datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%d %H:%M:%S UTC"),
        "hostname": socket.gethostname(),
    }
    return render_template("index.html", **context)

@app.route("/health")
def health():
    """Liveness and Readiness probe endpoint for Kubernetes"""
    uptime_seconds = round(time.time() - START_TIME, 2)
    return jsonify({
        "status": "healthy",
        "version": APP_VERSION,
        "pod_name": POD_NAME,
        "namespace": POD_NAMESPACE,
        "uptime_seconds": uptime_seconds,
        "timestamp": datetime.datetime.now(datetime.timezone.utc).isoformat()
    }), 200

@app.route("/api/info")
def info():
    """Metadata API endpoint"""
    return jsonify({
        "app": "gitops-demo-app",
        "version": APP_VERSION,
        "pod_name": POD_NAME,
        "pod_namespace": POD_NAMESPACE,
        "pod_ip": POD_IP,
        "node_name": NODE_NAME,
        "uptime": get_uptime(),
        "environment": ENVIRONMENT,
        "gitops_tool": "ArgoCD",
        "orchestrator": "Kubernetes"
    }), 200

if __name__ == "__main__":
    print(f"Starting GitOps Demo App [{APP_VERSION}] on port {PORT}...")
    app.run(host="0.0.0.0", port=PORT)
