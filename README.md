# ArgoCD GitOps demo lab

A local lab for demoing GitOps: a [kind](https://kind.sigs.k8s.io) cluster on your laptop, [ArgoCD](https://argo-cd.readthedocs.io) v3.5.3, and a demo app ([argoproj/rollouts-demo](https://github.com/argoproj/rollouts-demo)) that shows colored boxes, so rolling updates are easy to see. No cloud, no cost.

The stage script is in **[DEMO.md](DEMO.md)**.

## Prerequisites

- Docker (Docker Desktop on macOS), running, with about 4 GB of memory
- [kind](https://kind.sigs.k8s.io/docs/user/quick-start/#installation) (`brew install kind`), `kubectl`, `git`
- Push access to this repo (the demo scenes are `git push`es)
- Internet during the demo (GitHub)

> Apple Silicon: the demo images exist only for amd64. `scripts/preload-images.sh` (run by setup) loads them into kind, and Docker runs them through emulation.

## Quick start

```bash
scripts/setup.sh      # cluster + ArgoCD + app; prints the URLs and the admin password
scripts/reset.sh      # back to the start: blue, 5 replicas (run before each demo)
scripts/teardown.sh   # delete the cluster
```

- App: http://localhost:30080
- ArgoCD: http://localhost:30081 (user `admin`)

## Files

| Path | What it is |
|---|---|
| `kind-config.yaml` | One-node cluster; publishes ports 30080 (app) and 30081 (ArgoCD) on localhost |
| `k8s/app.yaml` | The app: Deployment `color-app` + NodePort Service. **The file the demo edits.** |
| `argocd/application.yaml` | Tells ArgoCD to sync `k8s/` from this repo (auto-sync, prune, self-heal) |
| `scripts/setup.sh` | Creates the cluster, installs ArgoCD, deploys the app |
| `scripts/preload-images.sh` | Loads the demo images into kind (no downloads on stage) |
| `scripts/reset.sh` | Restores `k8s/app.yaml` from the `demo-start` Git tag (a normal commit, no force-push) and waits for blue x5 |
| `scripts/teardown.sh` | Deletes the cluster |

## Pinned versions

kind node `v1.37.0` (by digest), ArgoCD `v3.5.3`, images `argoproj/rollouts-demo:blue` and `:yellow`.
