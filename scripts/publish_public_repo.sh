#!/usr/bin/env bash
# Push the built site to the public repository stalisnguyen/CV-2026.
# Authentication is an SSH deploy key with write access on that repository.
# Set DEPLOY_KEY to the private key text, or DEPLOY_KEY_FILE to its path.
set -euo pipefail

DIST=${1:-dist}
OWNER=stalisnguyen
REPO=CV-2026
REMOTE="git@github.com:${OWNER}/${REPO}.git"
ROOT=$(cd "$(dirname "$0")/.." && pwd)

if [[ "$DIST" != /* ]]; then
  DIST="$ROOT/$DIST"
fi
if [[ ! -f "$DIST/index.html" ]]; then
  echo "No built site at $DIST. Run scripts/build_public_site.py first." >&2
  exit 1
fi
if [[ -z "${DEPLOY_KEY:-}" && -z "${DEPLOY_KEY_FILE:-}" ]]; then
  echo "Set DEPLOY_KEY or DEPLOY_KEY_FILE to the write-enabled deploy key for ${OWNER}/${REPO}." >&2
  exit 1
fi

workdir=$(mktemp -d)
cleanup() { rm -rf "$workdir"; }
trap cleanup EXIT
install -d -m 700 "$workdir/ssh"
if [[ -n "${DEPLOY_KEY:-}" ]]; then
  printf '%s\n' "$DEPLOY_KEY" > "$workdir/ssh/id"
else
  cp "$DEPLOY_KEY_FILE" "$workdir/ssh/id"
fi
# A secret pasted into GitHub sometimes loses the trailing newline OpenSSH expects.
[[ -s "$workdir/ssh/id" ]] || { echo "Deploy key is empty." >&2; exit 1; }
tail -c 1 "$workdir/ssh/id" | od -An -t u1 | grep -q 10 || printf '\n' >> "$workdir/ssh/id"
chmod 600 "$workdir/ssh/id"
printf '%s\n' 'github.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl' > "$workdir/ssh/known_hosts"
export GIT_SSH_COMMAND="ssh -i $workdir/ssh/id -o IdentitiesOnly=yes -o UserKnownHostsFile=$workdir/ssh/known_hosts -o StrictHostKeyChecking=yes"

if git ls-remote "$REMOTE" HEAD | grep -q .; then
  git clone --depth 1 "$REMOTE" "$workdir/site"
  find "$workdir/site" -mindepth 1 -maxdepth 1 ! -name .git -exec rm -rf {} +
else
  mkdir "$workdir/site"
  git -C "$workdir/site" init -b main
  git -C "$workdir/site" remote add origin "$REMOTE"
fi

cp -a "$DIST"/. "$workdir/site"/
if find "$workdir/site" \( -name '*.md' -o -name '*.py' -o -name '*.sh' -o -path '*/.github/*' \) -print | grep -q .; then
  echo "Refusing to publish source files." >&2
  exit 1
fi

git -C "$workdir/site" add -A
if git -C "$workdir/site" diff --cached --quiet; then
  echo "Public site already matches this build."
  exit 0
fi
git -C "$workdir/site" -c user.name="CV site publish" -c user.email="cv-site-publish@users.noreply.github.com" commit -m "Publish the CV site."
git -C "$workdir/site" push origin HEAD:main
echo "Published to https://github.com/${OWNER}/${REPO}"
