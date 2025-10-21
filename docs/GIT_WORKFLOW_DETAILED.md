# Git Workflow - MAWAQIT Android TV

This document describes the Git branching strategy for the MAWAQIT Android TV project, based on **GitFlow** methodology. This workflow solves merge conflict issues between releases and enables parallel development.

---

## The Three Core Branches

```
main (protected)     → Production code, ONLY release tags
develop (protected)  → Integration branch, default for all PRs
release-* (protected)→ QA/staging branches, temporary
```

### Branch Roles

**1. `main` branch:**
- **Purpose:** Production code ONLY
- **Contains:** Only fully tested, released code
- **Updates:** Only accepts merges from `release-*` branches
- **Protection:** No direct commits, no direct PRs
- **Tags:** v1.25.0, v1.25.1, v1.26.0, etc.

**2. `develop` branch:**
- **Purpose:** Active development, integration point
- **Contains:** All completed features, ready for next release
- **Updates:** Accepts PRs from `feat/*`, `fix/*`, merged `release-*`
- **Protection:** No direct commits, requires PR review
- **State:** Always "potentially releasable" but not QA-tested

**3. `release-X.XX` branches:**
- **Purpose:** QA testing, stabilization, bug fixes only
- **Contains:** Snapshot of `develop` + QA fixes
- **Updates:** Only bug fixes during QA period
- **Protection:** No features, only fixes
- **Lifecycle:** Created → QA → fixes → merge → delete
- **Duration:** 1-3 weeks (QA period)

---

## Complete Workflow Visualization

### Phase 1: Feature Development (Normal Day-to-Day)

**Week 1-4: Feature development**

```
develop: ●──────────────────────────────→
         │    │    │    │    │
         │    │    │    │    └─ feat/payment
         │    │    │    └─ feat/notifications
         │    └─ fix/bug-123
         │    └─ feat/new-ui
         └─ feat/user-profile

main:    (unchanged, still at v1.24.0)
```

**What happens:**
1. Developer creates feature branch from `develop`
2. Develops feature, commits changes
3. Creates PR to `develop` (NOT main)
4. After review → merge to `develop`
5. Feature branch deleted
6. `main` stays unchanged

**Commands:**
```bash
git checkout develop
git pull origin develop
git checkout -b feat/fajr-disposal-fix
# make changes
git commit -m "fix: fajr disposal error"
git push origin feat/fajr-disposal-fix
# Create PR to develop
# After merge, delete feat/fajr-disposal-fix
```

---

### Phase 2: Create Release (Start QA)

**Week 5: Ready to release 1.25**

```
develop: ●──●──●──●──●──────────→ (continues with 1.26 work)
                    │
                    └──> release-1.25 (snapshot for QA)
                              ↓
                          QA testing

main:    v1.24.0 (unchanged during QA)
```

**What happens:**
1. Team decides: "Let's release 1.25"
2. Create `release-1.25` from `develop` (snapshot)
3. `develop` continues with new 1.26 features
4. QA team tests `release-1.25`
5. `main` unchanged (still production v1.24.0)

**Commands:**
```bash
git checkout develop
git pull origin develop
git checkout -b release-1.25
git push origin release-1.25
# Protect the branch on GitHub
# QA team starts testing release-1.25
```

**Key point:** `develop` is NOT frozen! Team continues working on 1.26 features while 1.25 is in QA.

---

### Phase 3: QA Finds Bugs (Fix on Release Branch)

**Week 6: QA testing release-1.25**

```
develop: ●──●──●──●──●──●──●──●──→ (1.26 features)
                    │      │  │
                    │      new features for 1.26
                    │
                    └──> release-1.25
                              │
                              └─> fix/qa-bug-1 (PR to release-1.25)
                              └─> fix/qa-bug-2 (PR to release-1.25)

main:    v1.24.0 (still unchanged)
```

**What happens:**
1. QA finds bug in `release-1.25`
2. Developer creates `fix/qa-bug-1` from `release-1.25`
3. Fixes bug, commits
4. PR to `release-1.25` (NOT develop)
5. After merge, continue QA
6. Repeat for each bug found

**Commands:**
```bash
git checkout release-1.25
git checkout -b fix/qa-audio-crash
# fix bug
git commit -m "fix: audio crash during navigation"
git push origin fix/qa-audio-crash
# Create PR to release-1.25
# After review → merge to release-1.25
```

**Important:** These QA fixes are ONLY on `release-1.25` for now. They will be merged back to `develop` later.

---

### Phase 4: Release to Production (Merge to Main)

**Week 7: QA passed, ready to deploy**

```
develop: ●──●──●──●──●──●──●──●──●──→
                    │              ↑
                    │              │ merge back QA fixes
                    │              │
                    └──> release-1.25 ──┐
                         (QA fixes)     │
                                        ↓
main:    v1.24.0 ──────────────────●──→ v1.25.0 (tag)
                                   ↑
                              merge release
```

**What happens:**
1. QA approves `release-1.25`
2. Merge `release-1.25` → `develop` (get QA fixes back)
3. Merge `release-1.25` → `main` (deploy to production)
4. Tag `main` as `v1.25.0`
5. Delete `release-1.25` branch (optional)

**Commands:**
```bash
# Step 1: Merge QA fixes back to develop
git checkout develop
git pull origin develop
git merge --no-ff release-1.25
git push origin develop

# Step 2: Merge to main (production)
git checkout main
git pull origin main
git merge --no-ff release-1.25
git tag v1.25.0
git push origin main --tags

# Optional: Delete release branch
git branch -d release-1.25
git push origin --delete release-1.25
```

**Result:**
- Production (`main`) now has v1.25.0
- `develop` has QA fixes + new 1.26 features
- NO merge conflicts (clean merge!)

---

### Phase 5: Start Next Release (Parallel Development)

**Week 7: While 1.25 is in QA, start 1.26**

```
develop: ●──●──●──●──●──●──●──●──●──●──●──→
                    │              │
                    │              └──> release-1.26 (new!)
                    │                        ↓
                    │                    QA for 1.26
                    │
                    └──> release-1.25
                         (still in QA)

main:    v1.24.0 ──────────────────→
```

**Key Advantage:** You can start `release-1.26` WHILE `release-1.25` is still in QA!

**Commands:**
```bash
# 1.25 is in QA, but you want to start 1.26:
git checkout develop
git pull origin develop
git checkout -b release-1.26
git push origin release-1.26
# Now both releases exist simultaneously!
```

---

## How This Solves Your Conflict Problem

### Your Current Problem:

```
main: ●──●──●──●──●──●──●──●──→ (new features added)
      │                       ↑
      │                    CONFLICTS!
      │                       │
      └─> release-1.25 ───────┘ (try to merge back)
          (diverged for 2 months, many changes)
```

**Why conflicts happen:**
- `release-1.25` and `main` both modified for weeks/months
- Same files changed differently
- Hard to resolve after so much divergence

---

### With Develop Branch:

```
main: ●─────────────────────────────●──→ (ONLY releases)
                                   ↗ clean merge
                                  │
develop: ●──●──●──●──●──●──●──●──●──→ (active work)
                    │
                    └─> release-1.25 (short-lived, 2 days)
                              ↓ QA fixes
                              ↓ merge back clean
                              ●
```

**Why NO conflicts:**
1. ✅ `release-1.25` created from `develop` (same base)
2. ✅ Only QA fixes on release (small changes)
3. ✅ Merge back after 2 weeks (short divergence)
4. ✅ `main` only receives clean merges (no parallel work)
5. ✅ `develop` → `release-1.25` → `main` (one-way flow)

---

## Edge Cases & Special Scenarios

### Scenario 1: Hotfix on Production (Already Released)

**Production has bug in v1.25.0!**

```
main:    v1.24.0 ────●── v1.25.0 ──→ (BUG HERE!)
                     │              ↑
                     │          hotfix/critical
                     │              │
develop: ●──●──●──●──●──●──●──●──●──→
                    │
                    └─> release-1.26 (in QA)
```

**Workflow:**
```bash
# Critical bug in production v1.25.0
git checkout main
git checkout -b hotfix/critical-payment-bug
# fix bug
git commit -m "hotfix: payment processing error"
git push origin hotfix/critical-payment-bug

# PR to main → merge
git checkout main
git merge --no-ff hotfix/critical-payment-bug
git tag v1.25.1
git push origin main --tags

# ALSO merge to develop (so 1.26 has the fix)
git checkout develop
git merge --no-ff hotfix/critical-payment-bug
git push origin develop

# ALSO merge to release-1.26 if needed
git checkout release-1.26
git merge --no-ff hotfix/critical-payment-bug
git push origin release-1.26
```

**Key:** Hotfixes go to `main` FIRST, then propagate to `develop` and active releases.

---

### Scenario 2: Feature NOT Ready for Release

**Week 5: Want to release, but feat/big-feature not ready**

```
develop: ●──●──●──●──●──●──●──●──→
              │        │  │
          feat/ready   │  feat/big-feature (not ready!)
                       │
                   feat/also-ready
```

**Solution:** Just don't merge `feat/big-feature` to develop yet!

```bash
# Create release without feat/big-feature
git checkout develop  # has feat/ready, feat/also-ready
git checkout -b release-1.25
# Does NOT include feat/big-feature (not merged yet)

# After 1.25 released:
# Now merge feat/big-feature to develop for 1.26
git checkout develop
git merge feat/big-feature
```

**Key:** Only merge to `develop` when ready for next release.

---

### Scenario 3: Emergency Fix During QA

**Week 6: Critical bug found during QA, need to release ASAP**

```
develop: ●──●──●──●──●──●──●──●──→ (has new 1.26 stuff)
                    │
                    └──> release-1.25 ── BUG FOUND!
                                    ↓
                              fix FAST
                                    ↓
                              merge to main → v1.25.0
                              (skip normal process)
```

**Workflow:**
```bash
# Fix bug on release-1.25
git checkout release-1.25
git checkout -b fix/critical-qa-bug
# fix bug
git commit -m "fix: critical startup crash"
git push

# PR to release-1.25 → merge FAST

# Emergency release to production:
git checkout main
git merge --no-ff release-1.25
git tag v1.25.0
git push origin main --tags

# Then merge back to develop
git checkout develop
git merge --no-ff release-1.25
git push origin develop
```

---

### Scenario 4: Multiple Releases in Parallel

**Week 8: Both 1.25 and 1.26 in different stages**

```
develop: ●──●──●──●──●──●──●──●──●──●──→
                    │          │
              release-1.25     └──> release-1.27 (starting!)
              (fixing final
               QA bugs)          └──> release-1.26
                                      (in QA)

main:    v1.24.0 (waiting for 1.25)
```

**This is ALLOWED and NORMAL:**
- `release-1.25`: Final QA fixes before production
- `release-1.26`: Currently in QA testing
- `release-1.27`: Just started for next milestone
- `develop`: Continues with 1.28 features

**Key:** No dependency between releases!

---

## Protected Branch Rules Configuration

### GitHub Branch Protection Settings:

**`main` branch:**
```
☑ Require pull request reviews before merging
☑ Require status checks to pass
☑ Require branches to be up to date
☑ Include administrators
☐ Allow force pushes (NEVER!)
☑ Only allow merge from: release-*, hotfix/*
```

**`develop` branch:**
```
☑ Require pull request reviews before merging
☑ Require status checks to pass
☑ Require branches to be up to date
☐ Include administrators (devs need quick access)
☐ Allow force pushes (NEVER!)
☑ Only allow merge from: feat/*, fix/*, release-*
```

**`release-*` branches:**
```
☑ Require pull request reviews before merging
☑ Require status checks to pass
☐ Require branches to be up to date (flexible during QA)
☐ Include administrators (QA needs flexibility)
☐ Allow force pushes (NEVER!)
☑ Only allow merge from: fix/* (no features!)
```

---

## Real Example: Your Current Situation

### Problem Now:

**You have:**
- `main`: at v1.24.0
- `release-1.25`: diverged, has conflicts with main
- `merge/release-1.25-to-main`: temp branch to resolve conflicts
- Issue #1901: Fajr disposal fix

---

### With Develop Branch Strategy:

**Step 1: Initial setup (one-time)**

```
main:    v1.24.0
         │
         └──> develop (created from current main)
                 │
                 └─ copy all current release-1.25 work here
```

**Commands:**
```bash
# Create develop from main
git checkout main
git checkout -b develop
git push origin develop

# Merge release-1.25 work into develop
git merge --no-ff release-1.25
# Resolve conflicts ONCE
git push origin develop

# Set develop as default branch on GitHub
```

---

**Step 2: Fix Issue #1901**

```
develop: ●───────────────→
         │
         └──> fix/fajr-disposal-error-1901
                    ↓ PR to develop
                    ● (merged)
```

**Commands:**
```bash
git checkout develop
git checkout -b fix/fajr-disposal-error-1901
# Your changes already made
git commit -m "fix: fajr disposal error"
git push
# PR to develop → merge
```

---

**Step 3: Create release-1.25 (fresh)**

```
develop: ●──●─────────────────→
            │
            └──> release-1.25 (NEW, from develop)
                     ↓ QA
```

**Commands:**
```bash
git checkout develop
git checkout -b release-1.25-new
git push
# QA tests this version
# After QA: merge to main cleanly (no conflicts!)
```

---

**Step 4: Create release-1.26 (don't wait!)**

```
develop: ●──●──●──●──●──●─────→
            │          │
      release-1.25     └──> release-1.26 (can start now!)
      (in QA)                      ↓
                               QA for 1.26
```

**Commands:**
```bash
# While 1.25 is in QA, start 1.26:
git checkout develop
git checkout -b release-1.26
git push
# No conflicts, no waiting!
```

---

## Branch Naming Conventions

| Branch Type | Pattern | Example | Merges To |
|-------------|---------|---------|-----------|
| Feature | `feat/issue-description` | `feat/1901-fajr-disposal-fix` | `develop` |
| Bug Fix | `fix/issue-description` | `fix/audio-crash` | `develop` or `release-*` |
| Hotfix | `hotfix/description` | `hotfix/critical-payment-bug` | `main` + `develop` |
| Release | `release-X.XX` | `release-1.26` | `main` + `develop` |
| Chore | `chore/description` | `chore/update-dependencies` | `develop` |
| Docs | `docs/description` | `docs/update-readme` | `develop` |

**Important:** Never use temporary merge branches like `merge/release-1.25-to-main`. With this workflow, merges are clean and direct.

---

## Quick Reference Commands

### Start New Feature
```bash
git checkout develop && git pull && git checkout -b feat/my-feature
```

### Create PR to Develop
```bash
gh pr create --base develop --title "feat: My feature"
```

### Create Release
```bash
git checkout develop && git checkout -b release-1.26 && git push
```

### Merge Release to Main
```bash
git checkout main && git merge --no-ff release-1.26 && git tag v1.26.0 && git push --tags
```

### Create Hotfix
```bash
git checkout main && git checkout -b hotfix/urgent-fix
```

### Format Code Before Commit
```bash
fvm dart format --set-exit-if-changed . --line-length 120
```

---

## Where to Create PRs

| You're Working On | Create PR To |
|-------------------|--------------|
| New feature | `develop` |
| Bug fix (not in QA) | `develop` |
| QA bug (release in testing) | `release-X.XX` |
| Production hotfix | `main` (then also to `develop`) |
| Documentation | `develop` |
| Chore/refactor | `develop` |

---

## Summary: Why This Works

### The Magic: One-Way Flow

```
Features → develop → release-X.XX → main
                         ↓
                    (QA fixes merge back)
```

**No conflicts because:**
1. ✅ `develop` is the integration point (all PRs go here)
2. ✅ Releases are short-lived (2-4 weeks max)
3. ✅ Releases only have QA fixes (small changes)
4. ✅ `main` only receives tested releases
5. ✅ No parallel work on `main` and `release-*`
6. ✅ Clear flow: always `develop` → `release` → `main`

### Your Specific Benefits:

1. ✅ **No more merge/temp branches** - Clean merges every time
2. ✅ **Start 1.26 while 1.25 in QA** - Parallel releases
3. ✅ **Protected branches work** - PRs enforce review
4. ✅ **Clear roles** - Team knows where to PR
5. ✅ **Industry standard** - Used by Android, Linux, many teams
6. ✅ **Scales with team** - Works for 2-200 developers

---