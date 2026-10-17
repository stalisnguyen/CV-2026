#!/usr/bin/env bash
# One-time split: keep history in stalisnguyen/CV-2026-source and serve the
# site from a new public stalisnguyen/CV-2026 repository.
#
# Run this as the GitHub user stalisnguyen (repo admin and permission to
# create repositories). The Cursor cloud agent token cannot do these steps.
#
#   gh auth login
#   ./scripts/split_public_site.sh
#   # confirm https://stalisnguyen.github.io/CV-2026/ in EN, VI, and ZH
#   ./scripts/split_public_site.sh --make-private
set -euo pipefail

OWNER=stalisnguyen
SOURCE_NAME=CV-2026-source
PUBLIC_NAME=CV-2026
ROOT=$(cd "$(dirname "$0")/.." && pwd)
MAKE_PRIVATE=0
if [[ "${1:-}" == "--make-private" ]]; then
  MAKE_PRIVATE=1
elif [[ -n "${1:-}" ]]; then
  echo "Usage: $0 [--make-private]" >&2
  exit 2
fi

login=$(gh api user --jq .login)
if [[ "$login" != "$OWNER" ]]; then
  echo "GitHub CLI is authenticated as ${login}, not ${OWNER}." >&2
  echo "Run: gh auth login" >&2
  echo "The account needs administration on the CV repository and permission to create a repository." >&2
  exit 1
fi

repo_field() {
  # Prints one field, or nothing when the repository (not a rename redirect) is absent.
  local name=$1 field=$2
  gh repo view "$OWNER/$name" --json name,id,visibility --jq \
    "select(.name == \"$name\") | .$field" 2>/dev/null || true
}

if [[ "$MAKE_PRIVATE" -eq 1 ]]; then
  public_id=$(repo_field "$PUBLIC_NAME" id)
  source_id=$(repo_field "$SOURCE_NAME" id)
  echo "Public id: ${public_id:-missing}"
  echo "Source id: ${source_id:-missing}"
  if [[ -z "$public_id" || -z "$source_id" || "$public_id" == "$source_id" ]]; then
    echo "The public site repository is not a separate repository yet. Run without --make-private first." >&2
    exit 1
  fi
  echo "Setting ${OWNER}/${SOURCE_NAME} to private."
  gh repo edit "$OWNER/$SOURCE_NAME" --visibility private --accept-visibility-change-consequences
  echo "Source is private. Open pull requests on it are private with the repository."
  gh pr list --repo "$OWNER/$SOURCE_NAME" --state open
  exit 0
fi

source_id=$(repo_field "$SOURCE_NAME" id)
if [[ -z "$source_id" ]]; then
  echo "Renaming ${OWNER}/${PUBLIC_NAME} to ${SOURCE_NAME}."
  echo "The live URL will be blank until the new public repository has Pages enabled."
  gh repo rename "$SOURCE_NAME" --repo "$OWNER/$PUBLIC_NAME" --yes
  source_id=$(repo_field "$SOURCE_NAME" id)
else
  echo "Source repository is already ${OWNER}/${SOURCE_NAME}."
fi
if [[ -z "$source_id" ]]; then
  echo "Rename did not produce ${OWNER}/${SOURCE_NAME}." >&2
  exit 1
fi
echo "Source repository id: $source_id"

python3 "$ROOT/scripts/build_public_site.py" "$ROOT/dist"

# Creating a repository with the old name replaces GitHub's rename redirect.
public_id=$(repo_field "$PUBLIC_NAME" id)
if [[ -n "$public_id" && "$public_id" != "$source_id" ]]; then
  echo "Public repository already exists (id ${public_id})."
elif [[ -n "$public_id" && "$public_id" == "$source_id" ]]; then
  echo "The name ${PUBLIC_NAME} still redirects to the source repository." >&2
  echo "Create it on the website: https://github.com/new?name=${PUBLIC_NAME}&owner=${OWNER}" >&2
  echo "Choose Public, and do not add a README, .gitignore, or license. Then rerun this script." >&2
  exit 1
else
  if ! gh repo create "$OWNER/$PUBLIC_NAME" \
    --public \
    --description "Public CV site for Nguyen Nguyen" \
    --homepage "https://stalisnguyen.github.io/CV-2026/" \
    --disable-wiki
  then
    echo "Creating ${OWNER}/${PUBLIC_NAME} failed." >&2
    echo "A rename redirect can block the name. Create the repository at:" >&2
    echo "https://github.com/new?name=${PUBLIC_NAME}&owner=${OWNER}" >&2
    echo "Choose Public, and do not add a README, .gitignore, or license. Then rerun this script." >&2
    exit 1
  fi
  public_id=$(repo_field "$PUBLIC_NAME" id)
fi
if [[ -z "$public_id" || "$public_id" == "$source_id" ]]; then
  echo "The new name still resolves to the source repository. Stop." >&2
  exit 1
fi
echo "Public repository id: $public_id"

if git ls-remote "https://github.com/${OWNER}/${PUBLIC_NAME}.git" HEAD | grep -q .; then
  echo "Public repository already has a commit. Leaving that history in place."
else
  publish_dir=$(mktemp -d)
  cp -a "$ROOT/dist"/. "$publish_dir"/
  git -C "$publish_dir" init -b main
  git -C "$publish_dir" -c user.name="CV site publish" -c user.email="cv-site-publish@users.noreply.github.com" add -A
  git -C "$publish_dir" -c user.name="CV site publish" -c user.email="cv-site-publish@users.noreply.github.com" commit -m "Publish the CV site."
  git -C "$publish_dir" remote add origin "https://github.com/${OWNER}/${PUBLIC_NAME}.git"
  git -C "$publish_dir" push -u origin main
  rm -rf "$publish_dir"
  echo "Pushed one commit to https://github.com/${OWNER}/${PUBLIC_NAME}"
fi

# Pages on main, site root. A second run finds Pages already enabled.
if ! gh api "repos/${OWNER}/${PUBLIC_NAME}/pages" >/dev/null 2>&1; then
  gh api --method POST "repos/${OWNER}/${PUBLIC_NAME}/pages" --input - <<'EOF'
{"build_type":"legacy","source":{"branch":"main","path":"/"}}
EOF
fi
echo "Pages source: main branch, root. Site: https://stalisnguyen.github.io/CV-2026/"

key_file="${HOME}/.ssh/cv-2026-pages"
if [[ ! -f "$key_file" ]]; then
  mkdir -p "${HOME}/.ssh"
  ssh-keygen -t ed25519 -f "$key_file" -N "" -C "cv-2026-pages-publish"
fi
gh repo deploy-key add "${key_file}.pub" \
  --repo "$OWNER/$PUBLIC_NAME" \
  --title "Publish from CV-2026-source" \
  --allow-write
gh secret set CV_PAGES_DEPLOY_KEY --repo "$OWNER/$SOURCE_NAME" < "$key_file"
echo "Stored the deploy key as Actions secret CV_PAGES_DEPLOY_KEY on ${SOURCE_NAME}."
echo "A deploy key added by gh is removed if you revoke that gh login. You can instead add ${key_file}.pub in the public repository under Settings, Deploy keys, with write access."
echo
echo "Next: open https://stalisnguyen.github.io/CV-2026/ in English, Vietnamese, and Chinese, on a desktop width and at 375px."
echo "Print or Save as PDF should still be 2 A4 pages."
echo "After that looks right, run: ./scripts/split_public_site.sh --make-private"
echo "Future Cursor cloud agents must use the repository ${OWNER}/${SOURCE_NAME}."
