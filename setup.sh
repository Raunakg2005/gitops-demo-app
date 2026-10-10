#!/usr/bin/env bash
# Stand up Minikube + ArgoCD from scratch and deploy the gitops-demo Application.
# Usage: ./setup.sh            (manual sync first)
#        ./setup.sh auto       (apply automated sync policy)
# Prereqs: docker (or another minikube driver), minikube, kubectl
set -euo pipefail

CLUSTER="${CLUSTER:-gitops-demo}"
ARGO_NS=argocd
APP_NS=gitops-demo
MANIFEST_URL="https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

for bin in minikube kubectl; do
  command -v "$bin" >/dev/null || { echo "Missing dependency: $bin"; exit 1; }
done

echo "==> 1/5 Starting Minikube cluster '$CLUSTER'"
minikube start -p "$CLUSTER" --driver=docker --cpus=2 --memory=4096
kubectl config use-context "$CLUSTER"

echo "==> 2/5 Installing ArgoCD"
kubectl create namespace "$ARGO_NS" --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -n "$ARGO_NS" --server-side --force-conflicts -f "$MANIFEST_URL"

echo "==> 3/5 Waiting for ArgoCD to be ready"
kubectl wait --for=condition=available deployment --all -n "$ARGO_NS" --timeout=300s
kubectl rollout status statefulset/argocd-application-controller -n "$ARGO_NS" --timeout=300s

echo "==> 4/5 Initial admin password"
until kubectl -n "$ARGO_NS" get secret argocd-initial-admin-secret >/dev/null 2>&1; do sleep 2; done
PASS="$(kubectl -n "$ARGO_NS" get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d)"
echo "    user: admin"
echo "    pass: $PASS"

echo "==> 5/5 Applying Application"
if [[ "${1:-}" == "auto" ]]; then
  kubectl apply -f "$HERE/argocd-app.yaml"
else
  kubectl apply -f "$HERE/argocd-app-manual.yaml"
fi

cat <<MSG

Done. Open the UI with:
  kubectl port-forward svc/argocd-server -n $ARGO_NS 8080:443
then visit https://localhost:8080 (accept the self-signed cert).

Manual sync:  argocd app sync gitops-demo   (or click SYNC in the UI)
Go automated: kubectl apply -f argocd-app.yaml
Teardown:     minikube delete -p $CLUSTER
MSG
