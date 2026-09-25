#!/usr/bin/env bash
# One-time setup: creates the kind cluster, installs ArgoCD and lets ArgoCD deploy the demo app from Git.
# Safe to run again: every step reuses or updates what already exists.
set -euo pipefail
cd "$(dirname "$0")/.." # run from the repo root, wherever the script is called from

CLUSTER=gitops-demo
ARGOCD_VERSION=v3.5.3 # pinned ArgoCD release

# 1. Check the required tools
for tool in docker kind kubectl git; do
  command -v "$tool" >/dev/null || { echo "Missing '$tool'. Install it first (kind: 'brew install kind' or https://kind.sigs.k8s.io)."; exit 1; }
done
docker info >/dev/null 2>&1 || { echo "Docker is not running. Start Docker and try again."; exit 1; }

# 2. Create the cluster, unless it already exists
if kind get clusters 2>/dev/null | grep -x "$CLUSTER" >/dev/null; then
  echo "Cluster '$CLUSTER' already exists, reusing it."
else
  for port in 30080 30081; do # the ports the cluster will publish on localhost
    if { lsof -nP -iTCP:"$port" -sTCP:LISTEN || ss -ltnp "sport = :$port" | grep LISTEN; } 2>/dev/null; then
      echo "Port $port is already used by the process above. Stop it and try again."; exit 1
    fi
  done
  kind create cluster --config kind-config.yaml
fi
kubectl config use-context "kind-$CLUSTER" >/dev/null # make sure kubectl talks to the demo cluster

# 3. Copy the demo images into the cluster
scripts/preload-images.sh

# 4. Install ArgoCD (server-side apply: the ArgoCD CRDs are too big for a normal apply)
echo "Installing ArgoCD $ARGOCD_VERSION..."
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f - >/dev/null
kubectl apply -n argocd --server-side --force-conflicts \
  -f "https://raw.githubusercontent.com/argoproj/argo-cd/$ARGOCD_VERSION/manifests/install.yaml" >/dev/null

# 5. Tune ArgoCD for the stage
#    - check Git every 30s with no random extra delay (default: 2 min + up to 1 min)
kubectl -n argocd patch configmap argocd-cm --type merge \
  -p '{"data":{"timeout.reconciliation":"30s","timeout.reconciliation.jitter":"0s"}}'
#    - serve the UI over plain HTTP (local laptop only), so there is no certificate warning
kubectl -n argocd patch configmap argocd-cmd-params-cm --type merge -p '{"data":{"server.insecure":"true"}}'
#    - publish the UI on NodePort 30081 (default patch merges by port, so the https port is kept)
kubectl -n argocd patch service argocd-server -p '{"spec":{"type":"NodePort","ports":[{"port":80,"nodePort":30081}]}}'
#    - restart the components that read these settings, then wait until they are ready
kubectl -n argocd rollout restart deployment/argocd-server deployment/argocd-repo-server statefulset/argocd-application-controller
for workload in deployment/argocd-server deployment/argocd-repo-server statefulset/argocd-application-controller; do
  kubectl -n argocd rollout status "$workload" --timeout=5m
done

# 6. Register the app with ArgoCD; from now on Git drives the cluster
kubectl wait --for condition=established crd/applications.argoproj.io --timeout=60s >/dev/null
kubectl apply -f argocd/application.yaml

# 7. Wait until ArgoCD has created the app and all pods are ready
echo "Waiting for ArgoCD to deploy color-app..."
for _ in $(seq 1 60); do
  kubectl get deployment color-app >/dev/null 2>&1 && break
  sleep 2
done
kubectl rollout status deployment/color-app --timeout=3m

# 8. Show where to go
PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 --decode)
echo
echo "Demo app:  http://localhost:30080"
echo "ArgoCD UI: http://localhost:30081   (user: admin, password: $PASSWORD)"
