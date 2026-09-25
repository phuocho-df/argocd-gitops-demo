# GitOps with ArgoCD: stage script

A 30-minute talk. Each scene has **Do** (exact steps), **Say** (talking points), **Audience sees**, and **If it doesn't happen**.
All commands are run from the repo folder.

> Internet is needed on stage: `git push` goes to GitHub and ArgoCD reads from GitHub. The app images are already on the laptop.

---

## Pre-flight

**The day before / T-60 min**

1. Start Docker Desktop.
2. If the cluster doesn't exist yet: `scripts/setup.sh` (about 3–5 min). Note the admin password it prints.
3. Test your phone hotspot: connect, run `git fetch`, disconnect.

**T-10 min**

1. `scripts/reset.sh` must end with `Ready: blue x5`.
   `git push --dry-run` must succeed without asking for a password (proves you can push on stage).
2. `curl -s localhost:30080/color` must print `"blue"`.
3. Open and arrange the screen:
   - **Left:** browser tab `http://localhost:30080` (colored boxes).
   - **Right:** browser tab `http://localhost:30081/applications/argocd/color-app` (log in as `admin`; forgot the password? see "Fallbacks"). App shows **Synced** + **Healthy**.
   - **Bottom:** terminal in the repo folder, and `k8s/app.yaml` open in the editor.
4. Browser zoom 125%+, terminal font large, notifications off (Do Not Disturb).
5. Open the backup clips in `recordings/` in a video player, minimized.

If anything fails: `kubectl get nodes`. If that errors, run `scripts/teardown.sh` then `scripts/setup.sh` (about 5 min).

---

## Intro (about 3 min, before scene 1)

**Say:**
- "Normally someone runs commands against the server to deploy. With **GitOps**, Git is the single source of truth. We only change files in Git."
- "**ArgoCD** runs inside the cluster, watches the Git repo, and makes the cluster match it, all the time."
- Point at the ArgoCD tree: "This is what's running: a Deployment, 5 pods, and a Service." Point at the browser: "Each box is one request answered by one of those pods. Blue = version 1."

---

## Scene 1: Deploy with a git push (up to about 70s)

**Do**

1. In `k8s/app.yaml` change the image line:
   ```
   image: argoproj/rollouts-demo:blue      →      image: argoproj/rollouts-demo:yellow
   ```
2. Save, then:
   ```bash
   git commit -am "deploy yellow" && git push
   ```

**Say:** "I didn't touch the cluster. I only pushed a commit. ArgoCD checks Git about every 30 seconds."

**Audience sees**
- ArgoCD: **OutOfSync** → syncing → a new ReplicaSet appears with new pods (usually within 30s, at most about 1 min).
- Browser: yellow boxes appear **between the blue ones** and gradually take over (about 35s). New pods are added before old ones are removed, so there is no downtime.

**If nothing changes within 30s:** click **Refresh ▾ → Hard Refresh** in ArgoCD (the small arrow next to Refresh; plain Refresh may reuse a cached answer). Say: "In production a webhook from GitHub triggers this instantly."

---

## Scene 2: Scale via Git (up to about 50s)

**Do**

1. In `k8s/app.yaml` change:
   ```
   replicas: 5      →      replicas: 10
   ```
2. Save, then:
   ```bash
   git commit -am "scale to 10" && git push
   ```

**Say:** "Scaling is a code change too: reviewed, versioned, and anyone can see who did it and when."

**Audience sees:** 5 new pod boxes appear in the ArgoCD tree and turn green (healthy).

**If nothing changes within 30s:** **Hard Refresh** (as in scene 1).

---

## Scene 3: Self-heal (about 15s)

**Do**

```bash
kubectl scale deployment color-app --replicas=1
```

**Say:** "Someone logs in and changes the cluster by hand, maybe by mistake at 3 a.m. Git still says 10."

**Audience sees:** pods start terminating; ArgoCD immediately notices the drift and brings it back to **10 pods** within seconds. The browser keeps showing yellow.

**Say:** "Manual changes are undone automatically. Git always wins."

**If it doesn't happen:** **Hard Refresh**, then **Sync**. Check the app's **App Details → Sync Policy** shows *Self Heal* enabled.

---

## Scene 4: Bad deploy + rollback (up to about 2 min)

**Do (the bad deploy)**

1. In `k8s/app.yaml` make a typo on purpose:
   ```
   image: argoproj/rollouts-demo:yellow      →      image: argoproj/rollouts-demo:yelow
   ```
2. Save, then:
   ```bash
   git commit -am "deploy new version" && git push
   ```

**Say:** "Now a mistake: a typo in the version. This image doesn't exist."

**Audience sees**
- ArgoCD: 3 new pods with **ImagePullBackOff** (broken heart icons). About 1 minute later the app turns **Degraded**.
- Browser: **still all yellow**. The old pods keep serving because Kubernetes never removes an old pod until its replacement is ready. Users notice nothing.

**Do (the rollback)**

```bash
git revert --no-edit HEAD && git push
```

**Say:** "Rolling back is just undoing the commit in Git. The history shows exactly what broke and who fixed it."

**Audience sees:** within about 30s–1 min the broken pods disappear, and the app returns to **Healthy** + **Synced**. The browser stays yellow the whole time.

**If nothing changes within 30s:** **Hard Refresh** (as in scene 1).

---

## Closing (about 1 min)

**Say:** "Git is the single source of truth. Deploy, scale and roll back are all commits. ArgoCD keeps the cluster matching Git and repairs drift by itself."

---

## Fallbacks

| Problem | What to do |
|---|---|
| Sync seems slow | **Refresh ▾ → Hard Refresh** in ArgoCD. Keep talking; it normally takes under 1 min. |
| `git push` rejected (someone else pushed) | `git pull --rebase && git push` |
| Wifi down | Switch to the phone hotspot. If that fails too, play the scene's clip from `recordings/`. |
| Browser shows an error page | `kubectl get pods`, then reload the page. |
| Typo in `app.yaml` breaks YAML (ArgoCD shows an error) | Fix the line, then `git commit -am "fix" && git push`. (If this happens in scene 4, roll back by setting the image back to `yellow` and pushing, instead of `git revert HEAD`.) |
| Forgot the ArgoCD password | `kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' \| base64 --decode; echo` |
| Cluster gone (laptop slept, Docker restarted) | Play the clips; afterwards `scripts/teardown.sh && scripts/setup.sh`. |

## Optional: edit on GitHub instead of locally

For scenes 1–2 you can edit `k8s/app.yaml` in the GitHub web editor (pencil icon → **Commit changes**), which looks nice on screen.
Before scene 4, run `git pull` in the terminal so your local copy has those commits.

## After the talk

- Run again later: `scripts/reset.sh`
- Remove everything: `scripts/teardown.sh`
