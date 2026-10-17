# CV source

Editable source for the public CV at https://stalisnguyen.github.io/CV-2026/.

GitHub Free cannot turn on Pages for a private repository. The source and its history live here. A second, public repository named `CV-2026` contains only the built page and is what Pages serves, so the URL stays the same.

| Repository | Visibility | Contents |
| --- | --- | --- |
| https://github.com/stalisnguyen/CV-2026-source | Private, after the split below | This source, history, and the publish workflow |
| https://github.com/stalisnguyen/CV-2026 | Public | Built `index.html` and `.nojekyll` only, starting from one commit |

`index.html` is the page. CSS and JavaScript are inside it. The photo on the page is embedded. `image.jpg` is not linked and is not published.

Future Cursor cloud agents must clone `stalisnguyen/CV-2026-source`. The public repository is only the site GitHub Pages serves.

## One-time split

A cloud agent token can push to this repository. It cannot rename it, create a repository, store an Actions secret, or change visibility. GitHub rejected those calls with `403 Resource not accessible by integration`. Creating a repository requires `administration=write` and `repository_creation=write` on the user account.

Run this while `gh` is logged in as **stalisnguyen**:

```bash
gh auth login
gh auth status
./scripts/split_public_site.sh
```

The script renames this repository to `CV-2026-source`, creates a new public `CV-2026` with one commit of the built site, turns on Pages for the `main` branch at the repository root, and stores a write deploy key as the Actions secret `CV_PAGES_DEPLOY_KEY`.

The live URL can 404 for a few minutes between the rename and the new Pages build. Check these before hiding the source:

- https://stalisnguyen.github.io/CV-2026/
- https://stalisnguyen.github.io/CV-2026/?lang=vi
- https://stalisnguyen.github.io/CV-2026/?lang=zh

On a desktop width the page stays two columns. At 375px it stacks into one column. Save as PDF, or print, still fits on 2 A4 pages in each language.

Then:

```bash
./scripts/split_public_site.sh --make-private
```

That sets `CV-2026-source` to private. Open pull requests on it become private with the repository. Pull request #2 (the old ATS print draft) is already closed.

## If GitHub says the name CV-2026 is taken

The rename leaves a redirect from `CV-2026` to `CV-2026-source`. Creating the new public repository with that name removes the redirect. If the script stops on that redirect:

1. Open https://github.com/new?name=CV-2026&owner=stalisnguyen
2. Create a **public** repository named `CV-2026` with no README, no `.gitignore`, and no license.
3. Run `./scripts/split_public_site.sh` again.

## Same steps by hand

1. Settings → General → Repository name → `CV-2026-source` → Rename.
2. Create a new public repository `stalisnguyen/CV-2026` with no README.
3. Build and publish one commit:

```bash
python3 scripts/build_public_site.py dist
# in a new folder, copy dist, then:
git init -b main
git add -A
git commit -m "Publish the CV site."
git remote add origin https://github.com/stalisnguyen/CV-2026.git
git push -u origin main
```

4. In the new repository: Settings → Pages → Deploy from a branch → `main` → `/` → Save.
5. Create an SSH key: `ssh-keygen -t ed25519 -f ~/.ssh/cv-2026-pages -N "" -C "cv-2026-pages-publish"`
6. Public repository → Settings → Deploy keys → Add `~/.ssh/cv-2026-pages.pub` with **Allow write access**.
7. Source repository → Settings → Secrets and variables → Actions → New secret `CV_PAGES_DEPLOY_KEY` → paste the private key `~/.ssh/cv-2026-pages`.
8. After the site checks out, source repository → Settings → General → Change repository visibility → Private.

A deploy key added with `gh repo deploy-key add` is deleted if that `gh` login is revoked. Adding the public key in the website settings avoids that.

## Later edits

Push to `main` on `CV-2026-source`. `.github/workflows/publish-site.yml` builds `dist/` and pushes it to the public repository with the deploy key. The workflow does nothing until this repository is named `stalisnguyen/CV-2026-source`, so it cannot overwrite this source tree.

To publish from a laptop instead:

```bash
python3 scripts/build_public_site.py dist
DEPLOY_KEY_FILE=~/.ssh/cv-2026-pages ./scripts/publish_public_repo.sh dist
```
