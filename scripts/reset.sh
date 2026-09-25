#!/usr/bin/env bash
# Puts the demo back to its starting point (blue, 5 replicas) so it can be run again.
# Git history is kept: the baseline file is restored with a normal commit, never a force-push.
set -euo pipefail
cd "$(dirname "$0")/.." # run from the repo root, wherever the script is called from

CLUSTER=gitops-demo
APP_FILE=k8s/app.yaml
BASELINE_TAG=demo-start # Git tag that marks the starting version of $APP_FILE
EXPECTED="argoproj/rollouts-demo:blue 5 5 5 5" # image, wanted, updated, ready, total pods

# 1. Git: restore the app file from the baseline tag and push it
git checkout -- "$APP_FILE" # drop unsaved edits from a half-finished scene
if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "Other files have uncommitted changes. Commit or discard them, then run again:"; git status --short; exit 1
fi
git pull --rebase --quiet # pick up commits made on GitHub
git checkout "$BASELINE_TAG" -- "$APP_FILE"
if git diff --cached --quiet; then
  echo "Git is already at the baseline."
else
  git commit --quiet -m "reset demo to baseline"
  git push --quiet
  echo "Pushed the baseline to GitHub."
fi

# 2. Cluster: make sure ArgoCD knows the app, and make it read Git right now
kind get clusters 2>/dev/null | grep -x "$CLUSTER" >/dev/null || { echo "Cluster '$CLUSTER' not found. Run scripts/setup.sh first."; exit 1; }
kubectl config use-context "kind-$CLUSTER" >/dev/null
kubectl apply -f argocd/application.yaml >/dev/null
kubectl -n argocd annotate application color-app argocd.argoproj.io/refresh=hard --overwrite >/dev/null

# 3. Wait (max 3 min) until exactly 5 blue pods are running and ready
echo "Waiting for 5 blue pods..."
state=""
for _ in $(seq 1 90); do
  state=$(kubectl get deployment color-app -o jsonpath='{.spec.template.spec.containers[0].image} {.spec.replicas} {.status.updatedReplicas} {.status.readyReplicas} {.status.replicas}' 2>/dev/null || true)
  [ "$state" = "$EXPECTED" ] && break
  sleep 2
done
[ "$state" = "$EXPECTED" ] || { echo "Timed out. Current state (image wanted updated ready total): $state"; exit 1; }

echo "Ready: blue x5. App: http://localhost:30080  ArgoCD: http://localhost:30081"
